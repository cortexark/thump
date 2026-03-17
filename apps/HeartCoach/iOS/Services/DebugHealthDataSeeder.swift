// DebugHealthDataSeeder.swift
// Thump iOS
//
// DEBUG-only utility that writes health samples into HealthKit on
// the simulator, so the production HealthKitService code path runs
// end-to-end with real data. Never ships in release builds.
//
// Platforms: iOS 17+ (simulator only)

#if DEBUG

import Foundation
import HealthKit

// MARK: - Debug Health Data Seeder

/// Injects `HeartSnapshot` data into the simulator's HealthKit store
/// as real `HKQuantitySample` and `HKCategorySample` objects.
///
/// This ensures `HealthKitService.fetchTodaySnapshot()` and
/// `fetchHistory()` run the same code path as the user's real device,
/// reproducing cache bugs, nil-field handling, and pillar exclusions.
///
/// Usage:
/// ```swift
/// #if targetEnvironment(simulator)
/// await DebugHealthDataSeeder.seedIfNeeded()
/// #endif
/// ```
public enum DebugHealthDataSeeder {

    /// UserDefaults key tracking whether we've already seeded.
    private static let seededKey = "debug.healthkit.seeded.v1"

    /// Metadata key used to tag seeded samples for cleanup.
    private static let sourceKey = "com.thump.debug.seeded"

    private static let store = HKHealthStore()

    // MARK: - Public API

    /// Seeds HealthKit once per simulator install.
    /// Skips if already seeded or if data file is missing.
    public static func seedIfNeeded() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("[DebugSeeder] HealthKit not available")
            return
        }

        let defaults = UserDefaults.standard
        if defaults.bool(forKey: seededKey) {
            print("[DebugSeeder] Already seeded — skipping")
            return
        }

        do {
            try await requestWriteAuthorization()
            let snapshots = RealUserDataLoader.loadAnchored(days: 74)
            guard !snapshots.isEmpty else {
                print("[DebugSeeder] No snapshots to seed")
                return
            }

            var sampleCount = 0
            for snapshot in snapshots {
                sampleCount += try await seedDay(snapshot: snapshot)
            }

            defaults.set(true, forKey: seededKey)
            print("[DebugSeeder] Seeded \(sampleCount) samples across \(snapshots.count) days")
        } catch {
            print("[DebugSeeder] Failed: \(error)")
        }
    }

    /// Force re-seed (clears the seeded flag first).
    public static func reseed() async {
        UserDefaults.standard.removeObject(forKey: seededKey)
        await seedIfNeeded()
    }

    // MARK: - Authorization

    private static func requestWriteAuthorization() async throws {
        // Only request write for types Apple allows third-party apps to write.
        // Read-only (Apple Watch-computed): restingHeartRate, vo2Max, appleExerciseTime
        let writeTypes: Set<HKSampleType> = [
            HKQuantityType(.heartRateVariabilitySDNN),
            HKQuantityType(.stepCount),
            HKQuantityType(.bodyMass),
            HKQuantityType(.heartRate),
            HKCategoryType(.sleepAnalysis)
        ]

        // Read everything the app needs, including Apple-computed types
        let readTypes: Set<HKObjectType> = [
            HKQuantityType(.restingHeartRate),
            HKQuantityType(.heartRateVariabilitySDNN),
            HKQuantityType(.stepCount),
            HKQuantityType(.appleExerciseTime),
            HKQuantityType(.bodyMass),
            HKQuantityType(.heartRate),
            HKQuantityType(.vo2Max),
            HKCategoryType(.sleepAnalysis)
        ]

        try await store.requestAuthorization(toShare: writeTypes, read: readTypes)
    }

    // MARK: - Seeding

    /// Writes all available metrics for a single day. Returns count of samples written.
    @discardableResult
    private static func seedDay(snapshot: HeartSnapshot) async throws -> Int {
        var samples: [HKSample] = []
        let date = snapshot.date
        let metadata: [String: Any] = [sourceKey: true]

        // RHR — can't write .restingHeartRate (Apple-computed), so write as
        // a resting heartRate sample at 4 AM (overnight). HealthKitService
        // queries .restingHeartRate which won't pick this up on simulator,
        // but the mock fallback in RealUserDataLoader handles it.
        if let rhr = snapshot.restingHeartRate {
            let start = Calendar.current.date(bySettingHour: 4, minute: 0, second: 0, of: date) ?? date
            let sample = HKQuantitySample(
                type: HKQuantityType(.heartRate),
                quantity: HKQuantity(unit: .count().unitDivided(by: .minute()), doubleValue: rhr),
                start: start,
                end: start,
                metadata: metadata
            )
            samples.append(sample)
        }

        // HRV SDNN — one sample at 5 AM (typical overnight reading)
        if let hrv = snapshot.hrvSDNN {
            let start = Calendar.current.date(bySettingHour: 5, minute: 0, second: 0, of: date) ?? date
            let end = Calendar.current.date(byAdding: .minute, value: 1, to: start) ?? start
            let sample = HKQuantitySample(
                type: HKQuantityType(.heartRateVariabilitySDNN),
                quantity: HKQuantity(unit: .secondUnit(with: .milli), doubleValue: hrv),
                start: start,
                end: end,
                metadata: metadata
            )
            samples.append(sample)
        }

        // Steps — cumulative over the day
        if let steps = snapshot.steps {
            let start = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: date) ?? date
            let end = Calendar.current.date(bySettingHour: 22, minute: 0, second: 0, of: date) ?? date
            let sample = HKQuantitySample(
                type: HKQuantityType(.stepCount),
                quantity: HKQuantity(unit: .count(), doubleValue: steps),
                start: start,
                end: end,
                metadata: metadata
            )
            samples.append(sample)
        }

        // Walk/Exercise minutes — can't write .appleExerciseTime (Apple-computed).
        // Skipped; the mock fallback provides this data.

        // VO2 Max — can't write .vo2Max (Apple-computed).
        // Skipped; the mock fallback provides this data.

        // Body mass
        if let mass = snapshot.bodyMassKg {
            let start = Calendar.current.date(bySettingHour: 7, minute: 30, second: 0, of: date) ?? date
            let sample = HKQuantitySample(
                type: HKQuantityType(.bodyMass),
                quantity: HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: mass),
                start: start,
                end: start,
                metadata: metadata
            )
            samples.append(sample)
        }

        // Recovery HR — write as a heart rate sample in the post-workout window
        if let rec1m = snapshot.recoveryHR1m {
            // Simulate: max HR ~160, drop of rec1m → recovery HR = 160 - rec1m
            let recoveryBPM = 160.0 - rec1m
            let start = Calendar.current.date(bySettingHour: 18, minute: 1, second: 0, of: date) ?? date
            let sample = HKQuantitySample(
                type: HKQuantityType(.heartRate),
                quantity: HKQuantity(unit: .count().unitDivided(by: .minute()), doubleValue: recoveryBPM),
                start: start,
                end: start,
                metadata: metadata
            )
            samples.append(sample)
        }

        // Sleep — write as a category sample with asleep stage
        if let sleepHours = snapshot.sleepHours, sleepHours > 0 {
            // Place sleep ending at 6 AM, starting sleepHours before that
            let end = Calendar.current.date(bySettingHour: 6, minute: 0, second: 0, of: date) ?? date
            let start = Calendar.current.date(byAdding: .second, value: -Int(sleepHours * 3600), to: end) ?? end

            let sample = HKCategorySample(
                type: HKCategoryType(.sleepAnalysis),
                value: HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                start: start,
                end: end,
                metadata: metadata
            )
            samples.append(sample)
        }

        guard !samples.isEmpty else { return 0 }

        try await store.save(samples)
        return samples.count
    }
}

#endif
