// HealthKitService.swift
// Thump iOS
//
// HealthKit integration service responsible for requesting authorization,
// querying daily health metrics, and assembling HeartSnapshot objects.
// Uses async/await with withCheckedThrowingContinuation for all HK queries.
// Platforms: iOS 17+

import Foundation
import HealthKit
import Combine

// MARK: - HealthKit Service

/// Service that manages all HealthKit interactions for Thump.
///
/// Provides authorization management and metric queries for resting heart rate,
/// HRV (SDNN), heart rate recovery, VO2 max, steps, walking minutes, workout
/// minutes, and sleep hours. Assembles raw metrics into `HeartSnapshot` objects.
final class HealthKitService: ObservableObject {

    // MARK: - Published State

    /// Whether the user has granted HealthKit authorization.
    @Published var isAuthorized: Bool = false

    // MARK: - Private Properties

    private let healthStore: HKHealthStore
    private let calendar = Calendar.current

    // MARK: - History Cache

    /// Cached history snapshots keyed by the number of days fetched.
    /// When a wider range has already been fetched, narrower views
    /// are derived from the cache instead of re-querying HealthKit.
    private var cachedHistory: [HeartSnapshot] = []
    private var cachedHistoryDays: Int = 0
    private var cachedHistoryDate: Date?

    // MARK: - Errors

    enum HealthKitError: LocalizedError {
        case notAvailable
        case authorizationDenied
        case queryFailed(String)

        var errorDescription: String? {
            switch self {
            case .notAvailable:
                return "HealthKit is not available on this device."
            case .authorizationDenied:
                return "HealthKit authorization was denied."
            case .queryFailed(let detail):
                return "HealthKit query failed: \(detail)"
            }
        }
    }

    // MARK: - Initialization

    init() {
        self.healthStore = HKHealthStore()
    }

    #if DEBUG
    /// Preview instance for SwiftUI previews.
    static var preview: HealthKitService { HealthKitService() }
    #endif

    // MARK: - Authorization

    /// Requests read authorization for all required HealthKit data types.
    ///
    /// After authorization completes, updates the `isAuthorized` published property.
    /// - Throws: `HealthKitError.notAvailable` if HealthKit is unavailable,
    ///           or any underlying HealthKit error.
    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }

        let quantityIdentifiers: [HKQuantityTypeIdentifier] = [
            .restingHeartRate,
            .heartRateVariabilitySDNN,
            .vo2Max,
            .heartRate,
            .stepCount,
            .appleExerciseTime,
            .bodyMass
        ]

        var readTypes = Set<HKObjectType>(
            quantityIdentifiers.compactMap { HKQuantityType.quantityType(forIdentifier: $0) }
        )

        if let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) {
            readTypes.insert(sleepType)
        }

        // Workout type — needed for recovery HR, workout minutes, and zone analysis
        readTypes.insert(HKWorkoutType.workoutType())

        // Characteristic types — biological sex and date of birth
        let characteristicIdentifiers: [HKCharacteristicTypeIdentifier] = [
            .biologicalSex,
            .dateOfBirth
        ]
        for id in characteristicIdentifiers {
            if let charType = HKCharacteristicType.characteristicType(forIdentifier: id) {
                readTypes.insert(charType)
            }
        }

        try await healthStore.requestAuthorization(toShare: [], read: readTypes)

        // NOTE: Apple intentionally hides read authorization status for
        // privacy. HKAuthorizationStatus only reflects *share* (write)
        // authorization -- there is no public API to determine whether the
        // user actually granted read access. Because we only request read
        // permissions (toShare is empty), the best we can do is mark
        // isAuthorized = true when requestAuthorization completes without
        // throwing, and handle missing data gracefully at the query level.
        // The real authorization gate belongs in the OnboardingView flow,
        // which should attempt a sample query to verify data access.
        await MainActor.run {
            self.isAuthorized = true
        }
    }

    // MARK: - Characteristics (Biological Sex & Date of Birth)

    /// Reads the user's biological sex from HealthKit.
    /// Returns `.notSet` if the user hasn't set it in Apple Health or
    /// if the read fails (e.g. not authorized).
    func readBiologicalSex() -> BiologicalSex {
        do {
            let hkSex = try healthStore.biologicalSex().biologicalSex
            switch hkSex {
            case .male: return .male
            case .female: return .female
            case .notSet, .other: return .notSet
            @unknown default: return .notSet
            }
        } catch {
            return .notSet
        }
    }

    /// Reads the user's date of birth from HealthKit.
    /// Returns nil if the user hasn't set it or if the read fails.
    func readDateOfBirth() -> Date? {
        do {
            let components = try healthStore.dateOfBirthComponents()
            return Calendar.current.date(from: components)
        } catch {
            return nil
        }
    }

    // MARK: - Snapshot Assembly

    /// Fetches all available health metrics for today and assembles a `HeartSnapshot`.
    ///
    /// Queries run concurrently using structured concurrency. Missing metrics
    /// are represented as `nil` in the returned snapshot.
    /// - Returns: A `HeartSnapshot` for the current calendar day.
    func fetchTodaySnapshot() async throws -> HeartSnapshot {
        let today = calendar.startOfDay(for: Date())
        return try await fetchSnapshot(for: today)
    }

    /// Fetches historical snapshots for the specified number of past days.
    ///
    /// Uses `HKStatisticsCollectionQuery` to batch metric queries across the
    /// entire date range, replacing the previous per-day fan-out approach
    /// (CR-005/PERF-3). For N days this fires ~6 collection queries instead
    /// of N × 9 individual queries.
    ///
    /// Returns snapshots ordered oldest-first. Days with no data are still
    /// included with nil metric values.
    /// - Parameter days: The number of past days to fetch (not including today).
    /// - Returns: Array of `HeartSnapshot` ordered oldest-first.
    func fetchHistory(days: Int) async throws -> [HeartSnapshot] {
        guard days > 0 else { return [] }

        let today = calendar.startOfDay(for: Date())

        // Cache hit: if we already fetched a superset for today, slice it
        if let cachedDate = cachedHistoryDate,
           calendar.isDate(cachedDate, inSameDayAs: today),
           cachedHistoryDays >= days {
            let surplus = cachedHistory.count - days
            if surplus >= 0 {
                return Array(cachedHistory.suffix(days))
            }
        }
        guard let rangeStart = calendar.date(byAdding: .day, value: -days, to: today) else {
            return []
        }

        // Batch-fetch metrics that support HKStatisticsCollectionQuery
        async let rhrByDay = batchAverageQuery(
            identifier: .restingHeartRate,
            unit: HKUnit.count().unitDivided(by: .minute()),
            start: rangeStart, end: today, option: .discreteAverage
        )
        async let hrvByDay = batchAverageQuery(
            identifier: .heartRateVariabilitySDNN,
            unit: HKUnit.secondUnit(with: .milli),
            start: rangeStart, end: today, option: .discreteAverage
        )
        async let stepsByDay = batchSumQuery(
            identifier: .stepCount,
            unit: HKUnit.count(),
            start: rangeStart, end: today
        )
        async let walkByDay = batchSumQuery(
            identifier: .appleExerciseTime,
            unit: HKUnit.minute(),
            start: rangeStart, end: today
        )

        let rhr = try await rhrByDay
        let hrv = try await hrvByDay
        let steps = try await stepsByDay
        let walk = try await walkByDay

        // Metrics that don't fit collection queries are fetched per-day concurrently:
        // VO2max (sparse), recovery HR (workout-dependent), sleep, weight, workout minutes
        var perDayExtras: [Date: (vo2: Double?, recov1: Double?, recov2: Double?,
                                  workout: Double?, sleep: Double?, weight: Double?)] = [:]

        try await withThrowingTaskGroup(
            of: (Date, Double?, Double?, Double?, Double?, Double?, Double?).self
        ) { group in
            for dayOffset in 1...days {
                guard let targetDate = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
                group.addTask { [self] in
                    async let vo2 = queryVO2Max(for: targetDate)
                    async let recovery = queryRecoveryHR(for: targetDate)
                    async let workout = queryWorkoutMinutes(for: targetDate)
                    async let sleep = querySleepHours(for: targetDate)
                    async let weight = queryBodyMass(for: targetDate)

                    let r = try await recovery
                    return (targetDate,
                            try await vo2, r.oneMin, r.twoMin,
                            try await workout, try await sleep, try await weight)
                }
            }
            for try await (date, vo2, r1, r2, wk, sl, wt) in group {
                perDayExtras[date] = (vo2, r1, r2, wk, sl, wt)
            }
        }

        // Assemble snapshots oldest-first
        var snapshots: [HeartSnapshot] = []
        for dayOffset in (1...days).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            let extras = perDayExtras[date]
            snapshots.append(HeartSnapshot(
                date: date,
                restingHeartRate: rhr[date],
                hrvSDNN: hrv[date],
                recoveryHR1m: extras?.recov1,
                recoveryHR2m: extras?.recov2,
                vo2Max: extras?.vo2,
                zoneMinutes: [],
                steps: steps[date],
                walkMinutes: walk[date],
                workoutMinutes: extras?.workout,
                sleepHours: extras?.sleep,
                bodyMassKg: extras?.weight
            ))
        }

        // Cache the result so narrower range switches don't re-query HealthKit
        if days >= cachedHistoryDays || cachedHistoryDate == nil
            || !calendar.isDate(cachedHistoryDate!, inSameDayAs: today) {
            cachedHistory = snapshots
            cachedHistoryDays = days
            cachedHistoryDate = today
        }

        return snapshots
    }

    // MARK: - Private: Full Day Snapshot

    /// Assembles a complete `HeartSnapshot` for a specific date by querying
    /// all metric types concurrently.
    private func fetchSnapshot(for date: Date) async throws -> HeartSnapshot {
        async let rhr = queryRestingHeartRate(for: date)
        async let hrv = queryHRV(for: date)
        async let recovery = queryRecoveryHR(for: date)
        async let vo2 = queryVO2Max(for: date)
        async let steps = querySteps(for: date)
        async let walking = queryWalkingMinutes(for: date)
        async let workout = queryWorkoutMinutes(for: date)
        async let sleep = querySleepHours(for: date)
        async let weight = queryBodyMass(for: date)
        async let zones = queryZoneMinutes(for: date)

        let rhrVal = try await rhr
        let hrvVal = try await hrv
        let recoveryVal = try await recovery
        let vo2Val = try await vo2
        let stepsVal = try await steps
        let walkVal = try await walking
        let workoutVal = try await workout
        let sleepVal = try await sleep
        let weightVal = try await weight
        let zonesVal = try await zones

        return HeartSnapshot(
            date: date,
            restingHeartRate: rhrVal,
            hrvSDNN: hrvVal,
            recoveryHR1m: recoveryVal.oneMin,
            recoveryHR2m: recoveryVal.twoMin,
            vo2Max: vo2Val,
            zoneMinutes: zonesVal,
            steps: stepsVal,
            walkMinutes: walkVal,
            workoutMinutes: workoutVal,
            sleepHours: sleepVal,
            bodyMassKg: weightVal
        )
    }

    // MARK: - Private: Batch Collection Queries (CR-005)

    /// Fetches a per-day average for a quantity type across the entire date range
    /// using a single `HKStatisticsCollectionQuery`.
    ///
    /// - Returns: Dictionary keyed by day start date with the average value.
    private func batchAverageQuery(
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        start: Date,
        end: Date,
        option: HKStatisticsOptions
    ) async throws -> [Date: Double] {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else {
            return [:]
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: start, end: end, options: .strictStartDate
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: option,
                anchorDate: start,
                intervalComponents: DateComponents(day: 1)
            )

            query.initialResultsHandler = { _, collection, error in
                if error != nil {
                    // No data for this metric range — return empty instead of failing
                    continuation.resume(returning: [:])
                    return
                }

                var results: [Date: Double] = [:]
                collection?.enumerateStatistics(from: start, to: end) { statistics, _ in
                    if let avg = statistics.averageQuantity() {
                        results[statistics.startDate] = avg.doubleValue(for: unit)
                    }
                }
                continuation.resume(returning: results)
            }
            healthStore.execute(query)
        }
    }

    /// Fetches a per-day cumulative sum for a quantity type across the date range
    /// using a single `HKStatisticsCollectionQuery`.
    ///
    /// - Returns: Dictionary keyed by day start date with the summed value.
    private func batchSumQuery(
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        start: Date,
        end: Date
    ) async throws -> [Date: Double] {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else {
            return [:]
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: start, end: end, options: .strictStartDate
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: start,
                intervalComponents: DateComponents(day: 1)
            )

            query.initialResultsHandler = { _, collection, error in
                if error != nil {
                    // No data for this metric range — return empty instead of failing
                    continuation.resume(returning: [:])
                    return
                }

                var results: [Date: Double] = [:]
                collection?.enumerateStatistics(from: start, to: end) { statistics, _ in
                    if let sum = statistics.sumQuantity() {
                        results[statistics.startDate] = sum.doubleValue(for: unit)
                    }
                }
                continuation.resume(returning: results)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Private: Individual Metric Queries

    /// Queries the average resting heart rate for the given date.
    private func queryRestingHeartRate(for date: Date) async throws -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else { return nil }
        let unit = HKUnit.count().unitDivided(by: .minute())
        return try await queryAverageQuantity(type: type, unit: unit, for: date)
    }

    /// Queries the average HRV (SDNN) for the given date.
    private func queryHRV(for date: Date) async throws -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return nil }
        let unit = HKUnit.secondUnit(with: .milli)
        return try await queryAverageQuantity(type: type, unit: unit, for: date)
    }

    /// Queries heart rate recovery at 1-minute and 2-minute post-exercise.
    ///
    /// Recovery HR is computed by finding the peak heart rate during workouts
    /// and measuring the drop at 1 and 2 minutes after workout end.
    /// If no workout data is available, returns nil for both values.
    private func queryRecoveryHR(for date: Date) async throws -> (oneMin: Double?, twoMin: Double?) {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return (nil, nil) }
        let bpmUnit = HKUnit.count().unitDivided(by: .minute())

        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return (nil, nil)
        }

        // Find workouts for the day
        let workoutPredicate = HKQuery.predicateForSamples(
            withStart: dayStart, end: dayEnd, options: .strictStartDate
        )

        let workouts: [HKWorkout] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKWorkoutType.workoutType(),
                predicate: workoutPredicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            ) { _, samples, error in
                if error != nil {
                    // No workout data — return empty instead of failing
                    continuation.resume(returning: [])
                    return
                }
                let results = (samples as? [HKWorkout]) ?? []
                continuation.resume(returning: results)
            }
            healthStore.execute(query)
        }

        guard let latestWorkout = workouts.first else {
            return (nil, nil)
        }

        // Get peak HR during the last 5 minutes of the workout
        let workoutEnd = latestWorkout.endDate
        let peakWindowStart = workoutEnd.addingTimeInterval(-300)

        let peakHR = try await queryMaxHeartRate(
            type: heartRateType,
            unit: bpmUnit,
            start: peakWindowStart,
            end: workoutEnd
        )

        guard let peak = peakHR else { return (nil, nil) }

        // Get average HR at 1 minute post-workout (45-75 second window)
        let oneMinStart = workoutEnd.addingTimeInterval(45)
        let oneMinEnd = workoutEnd.addingTimeInterval(75)
        let hrAt1Min = try await queryAverageHeartRate(
            type: heartRateType,
            unit: bpmUnit,
            start: oneMinStart,
            end: oneMinEnd
        )

        // Get average HR at 2 minutes post-workout (105-135 second window)
        let twoMinStart = workoutEnd.addingTimeInterval(105)
        let twoMinEnd = workoutEnd.addingTimeInterval(135)
        let hrAt2Min = try await queryAverageHeartRate(
            type: heartRateType,
            unit: bpmUnit,
            start: twoMinStart,
            end: twoMinEnd
        )

        let oneMinRecovery = hrAt1Min.map { peak - $0 }
        let twoMinRecovery = hrAt2Min.map { peak - $0 }

        return (oneMinRecovery, twoMinRecovery)
    }

    /// Queries the most recent VO2 max estimate for the given date.
    private func queryVO2Max(for date: Date) async throws -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .vo2Max) else { return nil }
        let unit = HKUnit.literUnit(with: .milli)
            .unitDivided(by: HKUnit.gramUnit(with: .kilo))
            .unitDivided(by: .minute())

        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return nil
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: dayStart, end: dayEnd, options: .strictStartDate
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            ) { _, samples, error in
                if error != nil {
                    // No VO2Max data — return nil instead of failing
                    continuation.resume(returning: nil)
                    return
                }
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                let value = sample.quantity.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }
    }

    /// Queries the most recent body mass (weight) sample on or before the given date.
    ///
    /// Weight doesn't change daily like heart rate — we want the latest reading
    /// within the past 30 days. Falls back to nil if no recent weight data exists.
    private func queryBodyMass(for date: Date) async throws -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return nil }
        let unit = HKUnit.gramUnit(with: .kilo)

        // Look back up to 30 days for the most recent weight entry.
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) ?? date
        guard let lookbackStart = calendar.date(byAdding: .day, value: -30, to: dayEnd) else { return nil }

        let predicate = HKQuery.predicateForSamples(
            withStart: lookbackStart, end: dayEnd, options: .strictStartDate
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            ) { _, samples, error in
                if error != nil {
                    // No body mass data — return nil instead of failing
                    continuation.resume(returning: nil)
                    return
                }
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                let value = sample.quantity.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }
    }

    /// Queries the total step count for the given date.
    private func querySteps(for date: Date) async throws -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return nil }
        let unit = HKUnit.count()
        return try await queryCumulativeSum(type: type, unit: unit, for: date)
    }

    /// Queries the total walking/running minutes for the given date.
    ///
    /// Uses Apple Exercise Time as a proxy for active walking minutes.
    private func queryWalkingMinutes(for date: Date) async throws -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) else { return nil }
        let unit = HKUnit.minute()
        return try await queryCumulativeSum(type: type, unit: unit, for: date)
    }

    /// Queries the total workout minutes for the given date from recorded workouts.
    private func queryWorkoutMinutes(for date: Date) async throws -> Double? {
        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return nil
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: dayStart, end: dayEnd, options: .strictStartDate
        )

        let workouts: [HKWorkout] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKWorkoutType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if error != nil {
                    // No workout data — return empty instead of failing
                    continuation.resume(returning: [])
                    return
                }
                let results = (samples as? [HKWorkout]) ?? []
                continuation.resume(returning: results)
            }
            healthStore.execute(query)
        }

        guard !workouts.isEmpty else { return nil }

        let totalMinutes = workouts.reduce(0.0) { sum, workout in
            sum + workout.duration / 60.0
        }

        return totalMinutes
    }

    /// Queries heart rate zone minutes from workout sessions for the given date (CR-013).
    ///
    /// Computes zones using 5 standard heart rate zones based on estimated max HR
    /// (220 - age, or 190 as fallback). Returns an array of 5 doubles representing
    /// minutes spent in each zone, or an empty array if no workout HR data exists.
    private func queryZoneMinutes(for date: Date) async throws -> [Double] {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return [] }
        let bpmUnit = HKUnit.count().unitDivided(by: .minute())

        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return [] }

        // Estimate max HR from user's age (220 - age), fallback 190
        let maxHR: Double
        if let dob = readDateOfBirth() {
            let age = Double(calendar.dateComponents([.year], from: dob, to: date).year ?? 30)
            maxHR = max(220.0 - age, 140.0)
        } else {
            maxHR = 190.0
        }

        // Zone thresholds as percentage of max HR
        let z1Ceil = maxHR * 0.50  // Zone 1: 50-60%
        let z2Ceil = maxHR * 0.60  // Zone 2: 60-70%
        let z3Ceil = maxHR * 0.70  // Zone 3: 70-80%
        let z4Ceil = maxHR * 0.80  // Zone 4: 80-90%
        // Zone 5: 90-100%

        // Fetch all HR samples for the day's workouts
        let workoutPredicate = HKQuery.predicateForSamples(
            withStart: dayStart, end: dayEnd, options: .strictStartDate
        )

        let workouts: [HKWorkout] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKWorkoutType.workoutType(),
                predicate: workoutPredicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if error != nil {
                    // No workout data for zone calc — return empty instead of failing
                    continuation.resume(returning: [])
                    return
                }
                continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
            }
            healthStore.execute(query)
        }

        guard !workouts.isEmpty else { return [] }

        // Query HR samples during workout intervals
        var zoneSeconds: [Double] = [0, 0, 0, 0, 0]

        for workout in workouts {
            let hrPredicate = HKQuery.predicateForSamples(
                withStart: workout.startDate, end: workout.endDate, options: .strictStartDate
            )

            let hrSamples: [HKQuantitySample] = try await withCheckedThrowingContinuation { continuation in
                let query = HKSampleQuery(
                    sampleType: heartRateType,
                    predicate: hrPredicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
                ) { _, samples, error in
                    if error != nil {
                        // No HR samples during workout — return empty instead of failing
                        continuation.resume(returning: [])
                        return
                    }
                    continuation.resume(returning: (samples as? [HKQuantitySample]) ?? [])
                }
                healthStore.execute(query)
            }

            // Bucket each HR sample into zones by duration between consecutive samples
            for i in 0..<hrSamples.count {
                let bpm = hrSamples[i].quantity.doubleValue(for: bpmUnit)
                let sampleDuration: TimeInterval
                if i + 1 < hrSamples.count {
                    sampleDuration = min(
                        hrSamples[i + 1].startDate.timeIntervalSince(hrSamples[i].startDate),
                        60.0 // cap at 60s to handle sparse samples
                    )
                } else {
                    sampleDuration = min(
                        workout.endDate.timeIntervalSince(hrSamples[i].startDate),
                        60.0
                    )
                }

                let zone: Int
                if bpm < z1Ceil { zone = 0 }
                else if bpm < z2Ceil { zone = 1 }
                else if bpm < z3Ceil { zone = 2 }
                else if bpm < z4Ceil { zone = 3 }
                else { zone = 4 }

                zoneSeconds[zone] += sampleDuration
            }
        }

        // Convert seconds to minutes
        return zoneSeconds.map { $0 / 60.0 }
    }

    /// Queries the total sleep hours for the given date.
    ///
    /// Considers sleep that ended on the target date. Filters for
    /// `asleepUnspecified`, `asleepCore`, `asleepDeep`, and `asleepREM` values,
    /// excluding `inBed` time.
    private func querySleepHours(for date: Date) async throws -> Double? {
        guard let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }

        // Sleep that counts for this date ended today (e.g., overnight sleep).
        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return nil
        }

        // Look back to the previous evening for overnight sleep
        let sleepWindowStart = dayStart.addingTimeInterval(-12 * 3600)

        let predicate = HKQuery.predicateForSamples(
            withStart: sleepWindowStart, end: dayEnd, options: .strictEndDate
        )

        let samples: [HKCategorySample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, results, error in
                if error != nil {
                    // No sleep data — return empty instead of failing
                    continuation.resume(returning: [])
                    return
                }
                let categorySamples = (results as? [HKCategorySample]) ?? []
                continuation.resume(returning: categorySamples)
            }
            healthStore.execute(query)
        }

        // Filter for actual sleep stages (not just "in bed")
        let asleepValues: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue
        ]

        let sleepSamples = samples.filter { asleepValues.contains($0.value) }
        guard !sleepSamples.isEmpty else { return nil }

        let totalSeconds = sleepSamples.reduce(0.0) { sum, sample in
            sum + sample.endDate.timeIntervalSince(sample.startDate)
        }

        return totalSeconds / 3600.0
    }

    // MARK: - Private: Query Helpers

    /// Queries the average value of a quantity type for a given date using HKStatisticsQuery.
    private func queryAverageQuantity(
        type: HKQuantityType,
        unit: HKUnit,
        for date: Date
    ) async throws -> Double? {
        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return nil
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: dayStart, end: dayEnd, options: .strictStartDate
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, statistics, error in
                if error != nil {
                    // No data for this metric — return nil instead of failing
                    continuation.resume(returning: nil)
                    return
                }
                guard let average = statistics?.averageQuantity() else {
                    continuation.resume(returning: nil)
                    return
                }
                let value = average.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }
    }

    /// Queries the cumulative sum of a quantity type for a given date.
    private func queryCumulativeSum(
        type: HKQuantityType,
        unit: HKUnit,
        for date: Date
    ) async throws -> Double? {
        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return nil
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: dayStart, end: dayEnd, options: .strictStartDate
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if error != nil {
                    // No data for this metric — return nil instead of failing
                    continuation.resume(returning: nil)
                    return
                }
                guard let sum = statistics?.sumQuantity() else {
                    continuation.resume(returning: nil)
                    return
                }
                let value = sum.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }
    }

    /// Queries the maximum heart rate within a specific time interval.
    private func queryMaxHeartRate(
        type: HKQuantityType,
        unit: HKUnit,
        start: Date,
        end: Date
    ) async throws -> Double? {
        let predicate = HKQuery.predicateForSamples(
            withStart: start, end: end, options: .strictStartDate
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .discreteMax
            ) { _, statistics, error in
                if error != nil {
                    // No max HR data — return nil instead of failing
                    continuation.resume(returning: nil)
                    return
                }
                guard let max = statistics?.maximumQuantity() else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: max.doubleValue(for: unit))
            }
            healthStore.execute(query)
        }
    }

    /// Queries the average heart rate within a specific time interval.
    private func queryAverageHeartRate(
        type: HKQuantityType,
        unit: HKUnit,
        start: Date,
        end: Date
    ) async throws -> Double? {
        let predicate = HKQuery.predicateForSamples(
            withStart: start, end: end, options: .strictStartDate
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, statistics, error in
                if error != nil {
                    // No avg HR data — return nil instead of failing
                    continuation.resume(returning: nil)
                    return
                }
                guard let avg = statistics?.averageQuantity() else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: avg.doubleValue(for: unit))
            }
            healthStore.execute(query)
        }
    }
}
