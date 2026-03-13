// MockUserProfiles.swift
// HeartCoach Tests
//
// 100 realistic mock user profiles across 10 archetypes
// with 30 days of deterministic HeartSnapshot data each.

import Foundation
@testable import Thump

// MARK: - Mock User Profile

struct MockUserProfile {
    let name: String
    let archetype: String
    let description: String
    let snapshots: [HeartSnapshot]
}

// SeededRNG is defined in EngineTimeSeries/TimeSeriesTestInfra.swift
// and shared across the test target — no duplicate needed here.

// MARK: - Generator Helpers

private let calendar = Calendar(identifier: .gregorian)

private func dateFor(dayOffset: Int) -> Date {
    var components = DateComponents()
    components.year = 2026
    components.month = 2
    components.day = 1
    // swiftlint:disable:next force_unwrapping
    let baseDate = calendar.date(from: components)!
    // swiftlint:disable:next force_unwrapping
    return calendar.date(byAdding: .day, value: dayOffset, to: baseDate)!
}

private func clamp(_ val: Double, _ lo: Double, _ hi: Double) -> Double {
    min(hi, max(lo, val))
}

private func round1(_ val: Double) -> Double {
    (val * 10).rounded() / 10
}

private func zoneMinutes(
    rng: inout SeededRNG,
    totalActive: Double,
    profile: ZoneProfile
) -> [Double] {
    let z0 = totalActive * profile.z0Frac
    let z1 = totalActive * profile.z1Frac
    let z2 = totalActive * profile.z2Frac
    let z3 = totalActive * profile.z3Frac
    let z4 = totalActive * profile.z4Frac
    return [
        round1(max(0, z0 + rng.uniform(-5, 5))),
        round1(max(0, z1 + rng.uniform(-3, 3))),
        round1(max(0, z2 + rng.uniform(-2, 2))),
        round1(max(0, z3 + rng.uniform(-1, 1))),
        round1(max(0, z4 + rng.uniform(-0.5, 0.5)))
    ]
}

private struct ZoneProfile {
    let z0Frac: Double
    let z1Frac: Double
    let z2Frac: Double
    let z3Frac: Double
    let z4Frac: Double
}

private let athleteZones = ZoneProfile(
    z0Frac: 0.15, z1Frac: 0.25, z2Frac: 0.30,
    z3Frac: 0.20, z4Frac: 0.10
)
private let recreationalZones = ZoneProfile(
    z0Frac: 0.25, z1Frac: 0.35, z2Frac: 0.25,
    z3Frac: 0.10, z4Frac: 0.05
)
private let sedentaryZones = ZoneProfile(
    z0Frac: 0.60, z1Frac: 0.25, z2Frac: 0.10,
    z3Frac: 0.04, z4Frac: 0.01
)
private let seniorZones = ZoneProfile(
    z0Frac: 0.45, z1Frac: 0.30, z2Frac: 0.15,
    z3Frac: 0.08, z4Frac: 0.02
)

// MARK: - MockProfileGenerator

struct MockProfileGenerator {

    // swiftlint:disable function_body_length

    static let allProfiles: [MockUserProfile] = {
        var profiles: [MockUserProfile] = []
        profiles.append(contentsOf: generateEliteAthletes())
        profiles.append(contentsOf: generateRecreationalAthletes())
        profiles.append(contentsOf: generateSedentaryWorkers())
        profiles.append(contentsOf: generateSleepDeprived())
        profiles.append(contentsOf: generateOvertrainers())
        profiles.append(contentsOf: generateRecoveringFromIllness())
        profiles.append(contentsOf: generateStressPattern())
        profiles.append(contentsOf: generateElderly())
        profiles.append(contentsOf: generateImprovingBeginner())
        profiles.append(contentsOf: generateInconsistentWarrior())
        return profiles
    }()

    static func profiles(for archetype: String) -> [MockUserProfile] {
        allProfiles.filter { $0.archetype == archetype }
    }

    // MARK: - 1. Elite Athletes

    private static func generateEliteAthletes() -> [MockUserProfile] {
        let configs: [(String, String, Double, Double, Double, Double,
                        Double, Double, Double, Double, UInt64)] = [
            ("Marcus Chen", "Marathon runner, peak training block",
             42, 2.0, 85, 8.0, 55, 18000, 8.0, 0.12, 1001),
            ("Sofia Rivera", "Triathlete, base building phase",
             45, 2.5, 78, 6.0, 52, 16000, 7.5, 0.10, 1002),
            ("Kai Nakamura", "Olympic swimmer, taper week pattern",
             40, 1.5, 95, 10.0, 58, 14000, 8.5, 0.08, 1003),
            ("Lena Okafor", "CrossFit competitor, high intensity",
             48, 3.0, 68, 5.0, 48, 20000, 7.0, 0.15, 1004),
            ("Dmitri Volkov", "Weightlifter, strength phase",
             50, 2.0, 62, 4.0, 46, 12000, 7.5, 0.18, 1005),
            ("Aisha Patel", "Road cyclist, endurance block",
             43, 1.8, 90, 7.0, 56, 15000, 8.0, 0.09, 1006),
            ("James Eriksson", "Trail runner, variable terrain",
             44, 2.5, 82, 7.5, 53, 22000, 7.8, 0.14, 1007),
            ("Maya Torres", "Pro soccer player, in-season",
             46, 2.2, 75, 6.5, 50, 17000, 7.2, 0.11, 1008),
            ("Noah Kim", "Rower, double sessions",
             39, 1.5, 100, 9.0, 59, 13000, 8.2, 0.07, 1009),
            ("Priya Sharma", "Track sprinter, speed block",
             47, 3.0, 70, 5.5, 47, 15000, 7.0, 0.16, 1010)
        ]

        return configs.map { cfg in
            let (name, desc, rhr, rhrSD, hrv, hrvSD,
                 vo2, steps, sleep, nilRate, seed) = cfg
            var rng = SeededRNG(seed: seed)
            var snaps: [HeartSnapshot] = []

            for day in 0..<30 {
                let dayRHR = rng.chance(nilRate) ? nil :
                    round1(clamp(
                        rng.gaussian(mean: rhr, sd: rhrSD),
                        36, 60
                    ))
                let dayHRV = rng.chance(nilRate) ? nil :
                    round1(clamp(
                        rng.gaussian(mean: hrv, sd: hrvSD),
                        40, 130
                    ))
                let dayVO2 = rng.chance(0.3) ? nil :
                    round1(clamp(
                        rng.gaussian(mean: vo2, sd: 1.5),
                        40, 65
                    ))
                let rec1 = rng.chance(0.2) ? nil :
                    round1(clamp(
                        rng.gaussian(mean: 35, sd: 5),
                        20, 55
                    ))
                let rec2 = rec1 == nil ? nil :
                    round1(clamp(
                        rng.gaussian(mean: 50, sd: 6),
                        30, 70
                    ))
                let daySteps = rng.chance(nilRate) ? nil :
                    round1(clamp(
                        rng.gaussian(mean: steps, sd: 3000),
                        5000, 35000
                    ))
                let totalActive = rng.uniform(60, 150)
                let zones = zoneMinutes(
                    rng: &rng, totalActive: totalActive,
                    profile: athleteZones
                )
                let daySleep = rng.chance(nilRate) ? nil :
                    round1(clamp(
                        rng.gaussian(mean: sleep, sd: 0.6),
                        5.5, 10.0
                    ))
                let dayWalk = round1(rng.uniform(30, 90))
                let dayWorkout = round1(rng.uniform(45, 120))

                snaps.append(HeartSnapshot(
                    date: dateFor(dayOffset: day),
                    restingHeartRate: dayRHR,
                    hrvSDNN: dayHRV,
                    recoveryHR1m: rec1,
                    recoveryHR2m: rec2,
                    vo2Max: dayVO2,
                    zoneMinutes: zones,
                    steps: daySteps,
                    walkMinutes: dayWalk,
                    workoutMinutes: dayWorkout,
                    sleepHours: daySleep
                ))
            }

            return MockUserProfile(
                name: name,
                archetype: "Elite Athlete",
                description: desc,
                snapshots: snaps
            )
        }
    }

    // MARK: - 2. Recreational Athletes

    private static func generateRecreationalAthletes() -> [MockUserProfile] {
        let configs: [(String, String, Double, Double, Double, Double,
                        Double, Double, Double, Double, UInt64)] = [
            ("Ben Mitchell", "Weekend jogger, 3x per week",
             58, 3.0, 48, 6.0, 42, 10000, 7.0, 0.10, 2001),
            ("Clara Johansson", "Gym-goer, lifting + cardio mix",
             55, 2.5, 52, 5.5, 40, 9000, 7.2, 0.12, 2002),
            ("Ryan O'Brien", "Recreational cyclist, weekends",
             60, 3.5, 42, 7.0, 38, 8500, 6.8, 0.08, 2003),
            ("Mei-Ling Wu", "Yoga + light running combo",
             53, 2.0, 58, 5.0, 44, 11000, 7.5, 0.10, 2004),
            ("Carlos Mendez", "Soccer league, twice weekly",
             62, 3.0, 40, 6.5, 37, 9500, 6.5, 0.15, 2005),
            ("Hannah Fischer", "Swimming 3 mornings a week",
             56, 2.5, 50, 5.5, 43, 8000, 7.3, 0.09, 2006),
            ("Tom Adeyemi", "Consistent 5K runner",
             54, 2.0, 55, 4.5, 45, 12000, 7.0, 0.11, 2007),
            ("Isabelle Moreau", "Dance fitness enthusiast",
             57, 3.0, 46, 6.0, 39, 10500, 7.1, 0.10, 2008),
            ("Amir Hassan", "Tennis player, 2-3 matches/week",
             59, 2.5, 44, 5.0, 41, 11500, 6.9, 0.13, 2009),
            ("Yuki Tanaka", "Hiking enthusiast, weekend warrior",
             61, 3.5, 38, 7.0, 36, 13000, 7.4, 0.07, 2010)
        ]

        return configs.map { cfg in
            let (name, desc, rhr, rhrSD, hrv, hrvSD,
                 vo2, steps, sleep, nilRate, seed) = cfg
            var rng = SeededRNG(seed: seed)
            var snaps: [HeartSnapshot] = []

            for day in 0..<30 {
                let isWorkoutDay = rng.chance(0.5)

                let dayRHR = rng.chance(nilRate) ? nil :
                    round1(clamp(
                        rng.gaussian(mean: rhr, sd: rhrSD),
                        48, 72
                    ))
                let dayHRV = rng.chance(nilRate) ? nil :
                    round1(clamp(
                        rng.gaussian(mean: hrv, sd: hrvSD),
                        20, 80
                    ))
                let dayVO2 = rng.chance(0.4) ? nil :
                    round1(clamp(
                        rng.gaussian(mean: vo2, sd: 2.0),
                        30, 52
                    ))
                let rec1 = isWorkoutDay ? round1(clamp(
                    rng.gaussian(mean: 25, sd: 5), 12, 42
                )) : nil
                let rec2 = rec1 != nil ? round1(clamp(
                    rng.gaussian(mean: 38, sd: 5), 20, 55
                )) : nil
                let daySteps = rng.chance(nilRate) ? nil :
                    round1(clamp(
                        rng.gaussian(
                            mean: isWorkoutDay ? steps * 1.2 : steps * 0.7,
                            sd: 2000
                        ),
                        3000, 22000
                    ))
                let totalActive = isWorkoutDay ?
                    rng.uniform(40, 90) : rng.uniform(10, 30)
                let zones = zoneMinutes(
                    rng: &rng, totalActive: totalActive,
                    profile: recreationalZones
                )
                let daySleep = rng.chance(nilRate) ? nil :
                    round1(clamp(
                        rng.gaussian(mean: sleep, sd: 0.7),
                        5.0, 9.5
                    ))
                let dayWalk = round1(rng.uniform(15, 60))
                let dayWorkout = isWorkoutDay ?
                    round1(rng.uniform(30, 75)) : 0

                snaps.append(HeartSnapshot(
                    date: dateFor(dayOffset: day),
                    restingHeartRate: dayRHR,
                    hrvSDNN: dayHRV,
                    recoveryHR1m: rec1,
                    recoveryHR2m: rec2,
                    vo2Max: dayVO2,
                    zoneMinutes: zones,
                    steps: daySteps,
                    walkMinutes: dayWalk,
                    workoutMinutes: dayWorkout,
                    sleepHours: daySleep
                ))
            }

            return MockUserProfile(
                name: name,
                archetype: "Recreational Athlete",
                description: desc,
                snapshots: snaps
            )
        }
    }

    // MARK: - 3. Sedentary Office Workers

    private static func generateSedentaryWorkers() -> [MockUserProfile] {
        let configs: [(String, String, Double, Double, Double, Double,
                        Double, Double, UInt64)] = [
            ("Derek Phillips", "Stressed tech worker, 28yo",
             72, 22, 30, 3200, 5.8, 0.10, 3001),
            ("Olivia Grant", "Relaxed admin, minimal exercise, 32yo",
             68, 30, 34, 4500, 6.5, 0.08, 3002),
            ("Raj Gupta", "High-stress finance, 40yo",
             80, 18, 27, 2500, 5.2, 0.12, 3003),
            ("Sarah Cooper", "Remote worker, occasional walks, 35yo",
             70, 28, 32, 4800, 6.8, 0.09, 3004),
            ("Mike Daniels", "Commuter desk job, 45yo",
             78, 20, 28, 3000, 6.0, 0.11, 3005),
            ("Jenna Park", "Graduate student, 26yo, sitting a lot",
             69, 32, 33, 4200, 6.3, 0.10, 3006),
            ("Brian Walsh", "Middle mgr, moderate stress, 50yo",
             82, 16, 26, 2800, 5.5, 0.14, 3007),
            ("Amanda Torres", "Creative professional, 30yo",
             71, 26, 31, 3800, 7.0, 0.07, 3008),
            ("Kevin Zhao", "IT support, night snacker, 38yo",
             76, 21, 29, 3500, 5.9, 0.12, 3009),
            ("Lisa Nguyen", "Call center worker, 42yo",
             84, 15, 25, 2200, 5.4, 0.15, 3010)
        ]

        return configs.map { cfg in
            let (name, desc, rhr, hrv, vo2, steps,
                 sleep, nilRate, seed) = cfg
            var rng = SeededRNG(seed: seed)
            var snaps: [HeartSnapshot] = []

            for day in 0..<30 {
                let isWeekend = (day % 7) >= 5
                let stepsAdj = isWeekend ? steps * 1.3 : steps

                let dayRHR = rng.chance(nilRate) ? nil :
                    round1(clamp(
                        rng.gaussian(mean: rhr, sd: 3.0),
                        60, 95
                    ))
                let dayHRV = rng.chance(nilRate) ? nil :
                    round1(clamp(
                        rng.gaussian(mean: hrv, sd: 4.0),
                        8, 50
                    ))
                let dayVO2 = rng.chance(0.5) ? nil :
                    round1(clamp(
                        rng.gaussian(mean: vo2, sd: 1.5),
                        20, 40
                    ))
                let daySteps = rng.chance(nilRate) ? nil :
                    round1(clamp(
                        rng.gaussian(mean: stepsAdj, sd: 800),
                        1000, 8000
                    ))
                let totalActive = rng.uniform(5, 25)
                let zones = zoneMinutes(
                    rng: &rng, totalActive: totalActive,
                    profile: sedentaryZones
                )
                let daySleep = rng.chance(nilRate) ? nil :
                    round1(clamp(
                        rng.gaussian(mean: sleep, sd: 0.8),
                        4.0, 8.5
                    ))
                let dayWalk = round1(rng.uniform(5, 30))

                snaps.append(HeartSnapshot(
                    date: dateFor(dayOffset: day),
                    restingHeartRate: dayRHR,
                    hrvSDNN: dayHRV,
                    recoveryHR1m: nil,
                    recoveryHR2m: nil,
                    vo2Max: dayVO2,
                    zoneMinutes: zones,
                    steps: daySteps,
                    walkMinutes: dayWalk,
                    workoutMinutes: 0,
                    sleepHours: daySleep
                ))
            }

            return MockUserProfile(
                name: name,
                archetype: "Sedentary Office Worker",
                description: desc,
                snapshots: snaps
            )
        }
    }

    // MARK: - 4. Sleep-Deprived

    private static func generateSleepDeprived() -> [MockUserProfile] {
        let configs: [(String, String, Double, Double, Double,
                        Double, Double, Bool, UInt64)] = [
            ("Jake Morrison", "New parent, first baby, 30yo",
             70, 28, 38, 8000, 4.2, false, 4001),
            ("Diana Reyes", "ER nurse, rotating shifts",
             68, 32, 40, 10000, 4.5, true, 4002),
            ("Mark Sinclair", "Startup founder, chronic 4h sleeper",
             74, 22, 34, 6000, 3.8, false, 4003),
            ("Anya Petrova", "Insomnia, active lifestyle",
             66, 35, 42, 12000, 4.0, true, 4004),
            ("Chris Hayward", "Truck driver, irregular schedule",
             78, 18, 30, 4000, 4.8, false, 4005),
            ("Fatima Al-Rashid", "Medical resident, 28h shifts",
             72, 25, 36, 9000, 3.5, true, 4006),
            ("Tyler Brooks", "Gamer, 2am bedtimes, 22yo",
             75, 20, 32, 3500, 5.0, false, 4007),
            ("Keiko Yamada", "New parent twins, 34yo",
             71, 26, 37, 7500, 3.2, false, 4008),
            ("Patrick Dunn", "Shift worker, factory, 45yo",
             80, 16, 28, 5500, 5.2, false, 4009),
            ("Sasha Kuznetsova", "Anxiety-driven insomnia, 38yo",
             73, 24, 35, 7000, 4.3, false, 4010)
        ]

        return configs.map { cfg in
            let (name, desc, rhr, hrv, vo2, steps,
                 sleepMean, isActive, seed) = cfg
            var rng = SeededRNG(seed: seed)
            var snaps: [HeartSnapshot] = []

            for day in 0..<30 {
                let sleepPenalty = rng.uniform(0, 1)
                // Worse sleep -> higher RHR, lower HRV
                let rhrAdj = rhr + sleepPenalty * 5
                let hrvAdj = hrv - sleepPenalty * 6

                let dayRHR = rng.chance(0.08) ? nil :
                    round1(clamp(
                        rng.gaussian(mean: rhrAdj, sd: 3.5),
                        55, 95
                    ))
                let dayHRV = rng.chance(0.10) ? nil :
                    round1(clamp(
                        rng.gaussian(mean: hrvAdj, sd: 5.0),
                        8, 55
                    ))
                let dayVO2 = rng.chance(0.45) ? nil :
                    round1(clamp(
                        rng.gaussian(mean: vo2, sd: 2.0),
                        22, 50
                    ))
                let rec1: Double?
                let rec2: Double?
                if isActive && rng.chance(0.4) {
                    rec1 = round1(clamp(
                        rng.gaussian(mean: 18, sd: 5), 8, 35
                    ))
                    rec2 = round1(clamp(
                        rng.gaussian(mean: 28, sd: 5), 15, 45
                    ))
                } else {
                    rec1 = nil
                    rec2 = nil
                }
                let daySteps = rng.chance(0.08) ? nil :
                    round1(clamp(
                        rng.gaussian(mean: steps, sd: 2000),
                        1500, 18000
                    ))
                let totalActive = isActive ?
                    rng.uniform(30, 80) : rng.uniform(5, 20)
                let zp = isActive ? recreationalZones : sedentaryZones
                let zones = zoneMinutes(
                    rng: &rng, totalActive: totalActive, profile: zp
                )
                // Key trait: consistently poor sleep
                let daySleep = rng.chance(0.05) ? nil :
                    round1(clamp(
                        rng.gaussian(mean: sleepMean, sd: 0.7),
                        2.0, 5.8
                    ))
                let dayWalk = round1(rng.uniform(10, 45))
                let dayWorkout = isActive ?
                    round1(rng.uniform(20, 60)) : 0

                snaps.append(HeartSnapshot(
                    date: dateFor(dayOffset: day),
                    restingHeartRate: dayRHR,
                    hrvSDNN: dayHRV,
                    recoveryHR1m: rec1,
                    recoveryHR2m: rec2,
                    vo2Max: dayVO2,
                    zoneMinutes: zones,
                    steps: daySteps,
                    walkMinutes: dayWalk,
                    workoutMinutes: dayWorkout,
                    sleepHours: daySleep
                ))
            }

            return MockUserProfile(
                name: name,
                archetype: "Sleep-Deprived",
                description: desc,
                snapshots: snaps
            )
        }
    }

    // MARK: - 5. Overtrainers

    private static func generateOvertrainers() -> [MockUserProfile] {
        // Each config: name, desc, startRHR, startHRV, vo2, steps,
        //   declineRate (how fast metrics degrade), seed
        let configs: [(String, String, Double, Double, Double,
                        Double, Double, UInt64)] = [
            ("Alex Brennan", "Marathon training, gradual overreach",
             44, 80, 52, 26000, 0.5, 5001),
            ("Nadia Kowalski", "CrossFit addict, sudden crash day 15",
             48, 70, 48, 28000, 0.0, 5002),
            ("Jordan Lee", "Ultra runner, ignoring fatigue signs",
             42, 88, 55, 30000, 0.7, 5003),
            ("Emma Blackwell", "Triathlete, double sessions daily",
             45, 75, 50, 25000, 0.4, 5004),
            ("Tobias Richter", "Cyclist, 500mi weeks, no rest days",
             43, 82, 53, 22000, 0.6, 5005),
            ("Lucia Ferrer", "Swimmer, overreaching volume ramp",
             46, 72, 49, 18000, 0.3, 5006),
            ("Will Chang", "Gym bro, 7 days/wk heavy lifting",
             50, 60, 45, 27000, 0.8, 5007),
            ("Rachel Foster", "Runner, pace obsessed, gradual",
             44, 78, 51, 24000, 0.5, 5008),
            ("Igor Petrov", "Rowing, 2x daily, sleep declining",
             41, 90, 56, 20000, 0.4, 5009),
            ("Simone Baptiste", "Soccer + gym + runs, no off days",
             47, 68, 47, 29000, 0.6, 5010)
        ]

        return configs.map { cfg in
            let (name, desc, startRHR, startHRV, vo2, steps,
                 declineRate, seed) = cfg
            var rng = SeededRNG(seed: seed)
            var snaps: [HeartSnapshot] = []

            // For sudden crash (declineRate == 0), crash at day 15
            let isSudden = declineRate == 0.0

            for day in 0..<30 {
                let progress = Double(day) / 29.0
                let declineFactor: Double
                if isSudden {
                    declineFactor = day >= 15 ?
                        Double(day - 15) / 14.0 * 1.5 : 0
                } else {
                    // Gradual: accelerating decline
                    declineFactor = pow(progress, 1.5) * declineRate * 2
                }

                let rhr = startRHR + declineFactor * 12
                let hrv = startHRV - declineFactor * 25
                let recovery = 35.0 - declineFactor * 15
                let sleepBase = 7.5 - declineFactor * 1.5

                let dayRHR = rng.chance(0.08) ? nil :
                    round1(clamp(
                        rng.gaussian(mean: rhr, sd: 2.0),
                        36, 85
                    ))
                let dayHRV = rng.chance(0.08) ? nil :
                    round1(clamp(
                        rng.gaussian(mean: hrv, sd: 5.0),
                        15, 120
                    ))
                let dayVO2 = rng.chance(0.35) ? nil :
                    round1(clamp(
                        rng.gaussian(
                            mean: vo2 - declineFactor * 4, sd: 1.5
                        ),
                        35, 62
                    ))
                let rec1 = rng.chance(0.2) ? nil :
                    round1(clamp(
                        rng.gaussian(mean: recovery, sd: 4),
                        8, 50
                    ))
                let rec2 = rec1 == nil ? nil :
                    round1(clamp(
                        rng.gaussian(mean: recovery + 12, sd: 5),
                        15, 65
                    ))
                // Steps stay high (they keep pushing)
                let daySteps = rng.chance(0.05) ? nil :
                    round1(clamp(
                        rng.gaussian(mean: steps, sd: 3000),
                        15000, 40000
                    ))
                let totalActive = rng.uniform(80, 180)
                let zones = zoneMinutes(
                    rng: &rng, totalActive: totalActive,
                    profile: athleteZones
                )
                let daySleep = rng.chance(0.08) ? nil :
                    round1(clamp(
                        rng.gaussian(mean: sleepBase, sd: 0.5),
                        4.5, 9.0
                    ))
                let dayWalk = round1(rng.uniform(20, 60))
                let dayWorkout = round1(rng.uniform(60, 150))

                snaps.append(HeartSnapshot(
                    date: dateFor(dayOffset: day),
                    restingHeartRate: dayRHR,
                    hrvSDNN: dayHRV,
                    recoveryHR1m: rec1,
                    recoveryHR2m: rec2,
                    vo2Max: dayVO2,
                    zoneMinutes: zones,
                    steps: daySteps,
                    walkMinutes: dayWalk,
                    workoutMinutes: dayWorkout,
                    sleepHours: daySleep
                ))
            }

            return MockUserProfile(
                name: name,
                archetype: "Overtrainer",
                description: desc,
                snapshots: snaps
            )
        }
    }

    // MARK: - 6. Recovering from Illness

    private static func generateRecoveringFromIllness()
        -> [MockUserProfile] {
        // sickRHR/sickHRV: metrics during illness (first 10 days)
        // wellRHR/wellHRV: recovered baseline
        // recoverySpeed: 0.5=slow, 1.0=fast transition
        let configs: [(String, String, Double, Double, Double, Double,
                        Double, Double, UInt64)] = [
            ("Greg Lawson", "Flu recovery, fast bounce back",
             85, 12, 62, 45, 1.0, 38, 6001),
            ("Maria Santos", "COVID long haul, slow recovery",
             90, 10, 68, 42, 0.3, 32, 6002),
            ("Helen O'Neil", "Pneumonia, moderate recovery",
             88, 14, 65, 48, 0.6, 35, 6003),
            ("David Kim", "Stomach virus, quick turnaround",
             82, 18, 60, 50, 0.9, 40, 6004),
            ("Natalie Brown", "Mono, extended recovery",
             92, 8, 70, 40, 0.2, 30, 6005),
            ("Sam Okonkwo", "Surgery recovery, gradual improvement",
             86, 15, 64, 46, 0.5, 36, 6006),
            ("Ingrid Larsson", "Severe cold, moderate",
             80, 20, 58, 52, 0.7, 42, 6007),
            ("Tyrone Jackson", "Bronchitis, slow then plateau",
             87, 13, 66, 44, 0.4, 34, 6008),
            ("Chloe Martinez", "Post-infection fatigue",
             84, 16, 62, 48, 0.5, 37, 6009),
            ("Victor Andersen", "Minor surgery, steady recovery",
             83, 19, 61, 50, 0.8, 39, 6010)
        ]

        return configs.map { cfg in
            let (name, desc, sickRHR, sickHRV, wellRHR, wellHRV,
                 speed, vo2Well, seed) = cfg
            var rng = SeededRNG(seed: seed)
            var snaps: [HeartSnapshot] = []

            for day in 0..<30 {
                // Phase: 0-9 sick, 10-29 recovery
                let recoveryProgress: Double
                if day < 10 {
                    recoveryProgress = 0
                } else {
                    let raw = Double(day - 10) / 19.0
                    // Apply speed curve
                    recoveryProgress = min(1.0, pow(raw, 1.0 / speed))
                }

                let rhr = sickRHR + (wellRHR - sickRHR) * recoveryProgress
                let hrv = sickHRV + (wellHRV - sickHRV) * recoveryProgress
                let vo2Base = (vo2Well - 10) + 10 * recoveryProgress
                let stepsBase = 2000 + 6000 * recoveryProgress
                let sleepBase = day < 10 ?
                    rng.uniform(8, 10) : rng.uniform(6.5, 8.5)

                let dayRHR = rng.chance(0.08) ? nil :
                    round1(clamp(
                        rng.gaussian(mean: rhr, sd: 2.5),
                        55, 100
                    ))
                let dayHRV = rng.chance(0.10) ? nil :
                    round1(clamp(
                        rng.gaussian(mean: hrv, sd: 4.0),
                        5, 65
                    ))
                let dayVO2 = rng.chance(0.5) ? nil :
                    round1(clamp(
                        rng.gaussian(mean: vo2Base, sd: 1.5),
                        18, 55
                    ))
                // No recovery HR during illness
                let rec1: Double?
                let rec2: Double?
                if day >= 14 && rng.chance(0.4) {
                    rec1 = round1(clamp(
                        rng.gaussian(mean: 15 + 10 * recoveryProgress, sd: 4),
                        5, 40
                    ))
                    rec2 = round1(clamp(
                        rng.gaussian(mean: 22 + 15 * recoveryProgress, sd: 5),
                        10, 55
                    ))
                } else {
                    rec1 = nil
                    rec2 = nil
                }
                let daySteps = rng.chance(0.10) ? nil :
                    round1(clamp(
                        rng.gaussian(mean: stepsBase, sd: 1000),
                        500, 14000
                    ))
                let totalActive = max(5, 10 + 40 * recoveryProgress)
                let zones = zoneMinutes(
                    rng: &rng, totalActive: totalActive,
                    profile: sedentaryZones
                )
                let daySleep = rng.chance(0.08) ? nil :
                    round1(clamp(sleepBase, 4.0, 11.0))
                let dayWalk = round1(
                    rng.uniform(5, 15 + 30 * recoveryProgress)
                )
                let dayWorkout = day < 14 ? 0 :
                    round1(rng.uniform(0, 30 * recoveryProgress))

                snaps.append(HeartSnapshot(
                    date: dateFor(dayOffset: day),
                    restingHeartRate: dayRHR,
                    hrvSDNN: dayHRV,
                    recoveryHR1m: rec1,
                    recoveryHR2m: rec2,
                    vo2Max: dayVO2,
                    zoneMinutes: zones,
                    steps: daySteps,
                    walkMinutes: dayWalk,
                    workoutMinutes: dayWorkout,
                    sleepHours: daySleep
                ))
            }

            return MockUserProfile(
                name: name,
                archetype: "Recovering from Illness",
                description: desc,
                snapshots: snaps
            )
        }
    }

    // MARK: - 7. Stress Pattern

    private static func generateStressPattern() -> [MockUserProfile] {
        // stressCycleDays: how often stress dips occur
        // stressIntensity: how much HRV drops during stress
        let configs: [(String, String, Double, Double, Double,
                        Int, Double, Double, UInt64)] = [
            ("Paula Schneider", "Work deadline stress, weekly dips",
             64, 42, 36, 7, 18, 7.0, 7001),
            ("Martin Clarke", "Chronic low-grade anxiety",
             68, 35, 32, 3, 10, 6.5, 7002),
            ("Diana Vasquez", "Acute panic episodes every 10 days",
             62, 48, 38, 10, 25, 7.2, 7003),
            ("Oliver Hunt", "Sunday night dread pattern",
             66, 40, 34, 7, 15, 6.8, 7004),
            ("Camille Dubois", "Caregiver stress, unpredictable",
             70, 30, 30, 5, 12, 6.0, 7005),
            ("Steven Park", "Financial stress, biweekly",
             67, 38, 35, 14, 20, 6.9, 7006),
            ("Rachel Green", "Social anxiety, weekend events",
             63, 44, 37, 7, 14, 7.1, 7007),
            ("Ahmed Khalil", "Work-travel stress cycles",
             72, 28, 31, 5, 16, 5.8, 7008),
            ("Nina Johansson", "Exam stress student, building",
             60, 50, 40, 4, 22, 7.5, 7009),
            ("Leo Fitzgerald", "Relationship stress + work combo",
             69, 33, 33, 6, 13, 6.3, 7010)
        ]

        return configs.map { cfg in
            let (name, desc, rhr, hrv, vo2,
                 cycleDays, intensity, sleep, seed) = cfg
            var rng = SeededRNG(seed: seed)
            var snaps: [HeartSnapshot] = []

            for day in 0..<30 {
                // Determine if this is a stress day
                let dayInCycle = day % cycleDays
                let isStressDay = dayInCycle == 0 ||
                    dayInCycle == 1 ||
                    (cycleDays <= 4 && rng.chance(0.4))

                let rhrAdj = isStressDay ? rhr + 8 : rhr
                let hrvAdj = isStressDay ? hrv - intensity : hrv
                let sleepAdj = isStressDay ? sleep - 1.2 : sleep

                let dayRHR = rng.chance(0.08) ? nil :
                    round1(clamp(
                        rng.gaussian(mean: rhrAdj, sd: 2.5),
                        52, 90
                    ))
                let dayHRV = rng.chance(0.08) ? nil :
                    round1(clamp(
                        rng.gaussian(mean: hrvAdj, sd: 4.0),
                        8, 65
                    ))
                let dayVO2 = rng.chance(0.45) ? nil :
                    round1(clamp(
                        rng.gaussian(mean: vo2, sd: 1.5),
                        22, 48
                    ))
                let daySteps = rng.chance(0.10) ? nil :
                    round1(clamp(
                        rng.gaussian(
                            mean: isStressDay ? 5000 : 7500,
                            sd: 1500
                        ),
                        2000, 14000
                    ))
                let totalActive = isStressDay ?
                    rng.uniform(5, 15) : rng.uniform(15, 45)
                let zones = zoneMinutes(
                    rng: &rng, totalActive: totalActive,
                    profile: sedentaryZones
                )
                let daySleep = rng.chance(0.08) ? nil :
                    round1(clamp(
                        rng.gaussian(mean: sleepAdj, sd: 0.6),
                        3.5, 9.0
                    ))
                let dayWalk = round1(rng.uniform(10, 40))

                snaps.append(HeartSnapshot(
                    date: dateFor(dayOffset: day),
                    restingHeartRate: dayRHR,
                    hrvSDNN: dayHRV,
                    recoveryHR1m: nil,
                    recoveryHR2m: nil,
                    vo2Max: dayVO2,
                    zoneMinutes: zones,
                    steps: daySteps,
                    walkMinutes: dayWalk,
                    workoutMinutes: 0,
                    sleepHours: daySleep
                ))
            }

            return MockUserProfile(
                name: name,
                archetype: "Stress Pattern",
                description: desc,
                snapshots: snaps
            )
        }
    }

    // MARK: - 8. Elderly/Senior

    private static func generateElderly() -> [MockUserProfile] {
        let configs: [(String, String, Double, Double, Double,
                        Double, Double, Bool, UInt64)] = [
            ("Dorothy Henderson", "Active senior, walks daily, 72yo",
             68, 25, 24, 7000, 8.0, true, 8001),
            ("Walter Schmidt", "Sedentary, mild COPD, 78yo",
             76, 14, 18, 3200, 8.5, false, 8002),
            ("Betty Nakamura", "Tai chi practitioner, 70yo",
             66, 28, 26, 6500, 7.5, true, 8003),
            ("Harold Brooks", "Former athlete, arthritis, 75yo",
             72, 20, 22, 4500, 8.2, false, 8004),
            ("Margaret O'Leary", "Active gardener, 68yo",
             65, 30, 27, 7500, 7.8, true, 8005),
            ("Eugene Foster", "Chair-bound most of day, 82yo",
             78, 12, 16, 2000, 9.0, false, 8006),
            ("Ruth Williams", "Water aerobics 3x/week, 73yo",
             69, 24, 25, 5800, 7.6, true, 8007),
            ("Frank Ivanov", "Light walks, on beta blockers, 80yo",
             60, 18, 20, 3800, 8.8, false, 8008),
            ("Gladys Moreau", "Active bridge + walking club, 71yo",
             67, 26, 25, 6800, 7.7, true, 8009),
            ("Albert Chen", "Sedentary, diabetes managed, 77yo",
             74, 15, 19, 3000, 8.3, false, 8010)
        ]

        return configs.map { cfg in
            let (name, desc, rhr, hrv, vo2, steps,
                 sleep, isActive, seed) = cfg
            var rng = SeededRNG(seed: seed)
            var snaps: [HeartSnapshot] = []

            for day in 0..<30 {
                let dayRHR = rng.chance(0.06) ? nil :
                    round1(clamp(
                        rng.gaussian(mean: rhr, sd: 2.5),
                        55, 90
                    ))
                let dayHRV = rng.chance(0.08) ? nil :
                    round1(clamp(
                        rng.gaussian(mean: hrv, sd: 3.0),
                        5, 40
                    ))
                let dayVO2 = rng.chance(0.5) ? nil :
                    round1(clamp(
                        rng.gaussian(mean: vo2, sd: 1.5),
                        12, 32
                    ))
                // Seniors rarely have recovery HR data
                let rec1 = isActive && rng.chance(0.15) ?
                    round1(clamp(
                        rng.gaussian(mean: 12, sd: 4), 4, 25
                    )) : nil
                let rec2 = rec1 != nil ?
                    round1(clamp(
                        rng.gaussian(mean: 18, sd: 4), 8, 35
                    )) : nil
                let daySteps = rng.chance(0.08) ? nil :
                    round1(clamp(
                        rng.gaussian(mean: steps, sd: 1200),
                        800, 12000
                    ))
                let totalActive = isActive ?
                    rng.uniform(15, 50) : rng.uniform(5, 15)
                let zones = zoneMinutes(
                    rng: &rng, totalActive: totalActive,
                    profile: seniorZones
                )
                let daySleep = rng.chance(0.06) ? nil :
                    round1(clamp(
                        rng.gaussian(mean: sleep, sd: 0.5),
                        6.0, 10.5
                    ))
                let dayWalk = isActive ?
                    round1(rng.uniform(20, 55)) :
                    round1(rng.uniform(5, 20))

                snaps.append(HeartSnapshot(
                    date: dateFor(dayOffset: day),
                    restingHeartRate: dayRHR,
                    hrvSDNN: dayHRV,
                    recoveryHR1m: rec1,
                    recoveryHR2m: rec2,
                    vo2Max: dayVO2,
                    zoneMinutes: zones,
                    steps: daySteps,
                    walkMinutes: dayWalk,
                    workoutMinutes: isActive ?
                        round1(rng.uniform(10, 40)) : 0,
                    sleepHours: daySleep
                ))
            }

            return MockUserProfile(
                name: name,
                archetype: "Elderly/Senior",
                description: desc,
                snapshots: snaps
            )
        }
    }

    // MARK: - 9. Improving Beginner

    private static func generateImprovingBeginner() -> [MockUserProfile] {
        // improvementRate: how fast metrics improve (0.5=slow, 1.5=fast)
        // plateauDay: day where improvement stalls temporarily (-1=none)
        let configs: [(String, String, Double, Double, Double,
                        Double, Double, Int, UInt64)] = [
            ("Jamie Watson", "Couch to 5K, fast improver",
             78, 18, 28, 3000, 5.8, -1, 9001),
            ("Priscilla Huang", "New gym habit, slow steady gains",
             74, 22, 30, 4000, 6.2, -1, 9002),
            ("Derek Stone", "Walking program, plateau at day 15",
             80, 15, 26, 2500, 5.5, 15, 9003),
            ("Serena Obi", "Yoga beginner, HRV focus",
             72, 24, 32, 5000, 6.5, -1, 9004),
            ("Marcus Reid", "Weight loss journey, moderate pace",
             82, 14, 25, 2200, 5.2, 10, 9005),
            ("Kim Nguyen", "Swimming lessons, fast adaptation",
             76, 20, 29, 3500, 6.0, -1, 9006),
            ("Andre Williams", "Basketball pickup games, variable",
             75, 21, 31, 4500, 6.3, 20, 9007),
            ("Lara Svensson", "Cycling commuter, steady progress",
             77, 19, 28, 3800, 5.9, -1, 9008),
            ("Rashid Khan", "Group fitness classes, slow start",
             84, 12, 24, 2000, 5.0, -1, 9009),
            ("Gabrielle Petit", "Dance classes 2x/week, quick gains",
             73, 23, 30, 4200, 6.4, -1, 9010)
        ]

        return configs.map { cfg in
            let (name, desc, startRHR, startHRV, startVO2,
                 startSteps, startSleep, plateauDay, seed) = cfg
            var rng = SeededRNG(seed: seed)
            var snaps: [HeartSnapshot] = []

            // Target improvements over 30 days
            let rhrDrop = 8.0  // RHR decreases
            let hrvGain = 12.0  // HRV increases
            let vo2Gain = 5.0
            let stepsGain = 4000.0
            let sleepGain = 0.8

            for day in 0..<30 {
                var progress = Double(day) / 29.0

                // Apply plateau if configured
                if plateauDay > 0 && day >= plateauDay
                    && day < plateauDay + 7 {
                    progress = Double(plateauDay) / 29.0
                } else if plateauDay > 0 && day >= plateauDay + 7 {
                    let pre = Double(plateauDay) / 29.0
                    let remaining = Double(day - plateauDay - 7) / 29.0
                    progress = pre + remaining
                }
                progress = min(1.0, progress)

                let rhr = startRHR - rhrDrop * progress
                let hrv = startHRV + hrvGain * progress
                let vo2 = startVO2 + vo2Gain * progress
                let stepsTarget = startSteps + stepsGain * progress
                let sleepTarget = startSleep + sleepGain * progress

                let dayRHR = rng.chance(0.10) ? nil :
                    round1(clamp(
                        rng.gaussian(mean: rhr, sd: 2.5),
                        58, 92
                    ))
                let dayHRV = rng.chance(0.10) ? nil :
                    round1(clamp(
                        rng.gaussian(mean: hrv, sd: 4.0),
                        8, 50
                    ))
                let dayVO2 = rng.chance(0.45) ? nil :
                    round1(clamp(
                        rng.gaussian(mean: vo2, sd: 1.5),
                        20, 42
                    ))
                // Recovery HR appears as fitness improves
                let rec1: Double?
                let rec2: Double?
                if progress > 0.3 && rng.chance(0.3) {
                    rec1 = round1(clamp(
                        rng.gaussian(mean: 12 + 8 * progress, sd: 3),
                        5, 30
                    ))
                    rec2 = round1(clamp(
                        rng.gaussian(mean: 18 + 12 * progress, sd: 4),
                        10, 42
                    ))
                } else {
                    rec1 = nil
                    rec2 = nil
                }
                let daySteps = rng.chance(0.08) ? nil :
                    round1(clamp(
                        rng.gaussian(mean: stepsTarget, sd: 1500),
                        1000, 14000
                    ))
                let totalActive = 10 + 35 * progress
                let zones = zoneMinutes(
                    rng: &rng,
                    totalActive: rng.uniform(
                        totalActive * 0.8, totalActive * 1.2
                    ),
                    profile: recreationalZones
                )
                let daySleep = rng.chance(0.10) ? nil :
                    round1(clamp(
                        rng.gaussian(mean: sleepTarget, sd: 0.5),
                        4.5, 8.5
                    ))
                let dayWalk = round1(
                    rng.uniform(10, 20 + 30 * progress)
                )
                let dayWorkout = progress > 0.2 ?
                    round1(rng.uniform(0, 15 + 35 * progress)) : 0

                snaps.append(HeartSnapshot(
                    date: dateFor(dayOffset: day),
                    restingHeartRate: dayRHR,
                    hrvSDNN: dayHRV,
                    recoveryHR1m: rec1,
                    recoveryHR2m: rec2,
                    vo2Max: dayVO2,
                    zoneMinutes: zones,
                    steps: daySteps,
                    walkMinutes: dayWalk,
                    workoutMinutes: dayWorkout,
                    sleepHours: daySleep
                ))
            }

            return MockUserProfile(
                name: name,
                archetype: "Improving Beginner",
                description: desc,
                snapshots: snaps
            )
        }
    }

    // MARK: - 10. Inconsistent/Weekend Warrior

    private static func generateInconsistentWarrior()
        -> [MockUserProfile] {
        // weekdayRHR/weekendRHR: the swing between weekday and weekend
        // swingMagnitude: 0.5=mild, 1.5=extreme contrast
        let configs: [(String, String, Double, Double, Double, Double,
                        Double, UInt64)] = [
            ("Blake Harrison", "Long runs Sat+Sun, desk job M-F",
             74, 58, 22, 48, 1.0, 10001),
            ("Monica Reeves", "Party weekends, exhausted weekdays",
             76, 62, 20, 42, 1.3, 10002),
            ("Troy Nakamura", "Weekend basketball + hiking",
             72, 56, 25, 50, 0.8, 10003),
            ("Stacy Johansson", "Gym only Sat, lazy weekdays",
             78, 64, 18, 38, 1.1, 10004),
            ("Luis Calderon", "Soccer Sun league, office rest of week",
             70, 55, 28, 52, 0.9, 10005),
            ("Tiffany Zhao", "Weekend warrior cyclist",
             75, 60, 21, 44, 1.2, 10006),
            ("Brandon Moore", "Extreme contrast: marathons vs couch",
             80, 52, 16, 55, 1.5, 10007),
            ("Courtney Ellis", "Yoga weekends, no movement weekdays",
             71, 60, 26, 46, 0.7, 10008),
            ("Darnell Washington", "Weekend hiker, desk jockey",
             73, 57, 24, 48, 0.9, 10009),
            ("Ashley Martin", "Social sports weekends only",
             77, 61, 19, 40, 1.0, 10010)
        ]

        return configs.map { cfg in
            let (name, desc, wdRHR, weRHR, wdHRV, weHRV,
                 swing, seed) = cfg
            var rng = SeededRNG(seed: seed)
            var snaps: [HeartSnapshot] = []

            for day in 0..<30 {
                let dayOfWeek = day % 7
                // 5,6 = weekend (Sat, Sun)
                let isWeekend = dayOfWeek >= 5
                // Friday night effect: slightly better
                let isFriday = dayOfWeek == 4

                let baseRHR: Double
                let baseHRV: Double
                if isWeekend {
                    baseRHR = weRHR
                    baseHRV = weHRV
                } else if isFriday {
                    baseRHR = (wdRHR + weRHR) / 2
                    baseHRV = (wdHRV + weHRV) / 2
                } else {
                    baseRHR = wdRHR
                    baseHRV = wdHRV
                }

                let weekendSteps = 12000.0 + swing * 5000
                let weekdaySteps = 3500.0 - swing * 500
                let stepsTarget = isWeekend ?
                    weekendSteps : weekdaySteps

                let dayRHR = rng.chance(0.08) ? nil :
                    round1(clamp(
                        rng.gaussian(mean: baseRHR, sd: 2.5),
                        48, 90
                    ))
                let dayHRV = rng.chance(0.08) ? nil :
                    round1(clamp(
                        rng.gaussian(mean: baseHRV, sd: 4.0),
                        8, 65
                    ))
                let dayVO2 = rng.chance(0.5) ? nil :
                    round1(clamp(
                        rng.gaussian(mean: isWeekend ? 38 : 30, sd: 2),
                        22, 48
                    ))
                let rec1: Double?
                let rec2: Double?
                if isWeekend && rng.chance(0.6) {
                    rec1 = round1(clamp(
                        rng.gaussian(mean: 22, sd: 5), 8, 40
                    ))
                    rec2 = round1(clamp(
                        rng.gaussian(mean: 32, sd: 5), 15, 50
                    ))
                } else {
                    rec1 = nil
                    rec2 = nil
                }
                let daySteps = rng.chance(0.08) ? nil :
                    round1(clamp(
                        rng.gaussian(mean: stepsTarget, sd: 2000),
                        1500, 25000
                    ))
                let totalActive = isWeekend ?
                    rng.uniform(50, 120) : rng.uniform(5, 20)
                let zp = isWeekend ?
                    recreationalZones : sedentaryZones
                let zones = zoneMinutes(
                    rng: &rng, totalActive: totalActive, profile: zp
                )
                let sleepTarget = isWeekend ? 8.5 : 5.8
                let daySleep = rng.chance(0.08) ? nil :
                    round1(clamp(
                        rng.gaussian(mean: sleepTarget, sd: 0.6),
                        4.0, 10.0
                    ))
                let dayWalk = isWeekend ?
                    round1(rng.uniform(30, 90)) :
                    round1(rng.uniform(5, 20))
                let dayWorkout = isWeekend ?
                    round1(rng.uniform(40, 100)) : 0

                snaps.append(HeartSnapshot(
                    date: dateFor(dayOffset: day),
                    restingHeartRate: dayRHR,
                    hrvSDNN: dayHRV,
                    recoveryHR1m: rec1,
                    recoveryHR2m: rec2,
                    vo2Max: dayVO2,
                    zoneMinutes: zones,
                    steps: daySteps,
                    walkMinutes: dayWalk,
                    workoutMinutes: dayWorkout,
                    sleepHours: daySleep
                ))
            }

            return MockUserProfile(
                name: name,
                archetype: "Inconsistent/Weekend Warrior",
                description: desc,
                snapshots: snaps
            )
        }
    }

    // swiftlint:enable function_body_length
}
