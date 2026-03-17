// LifeStoryPersonas.swift
// ThumpCoreTests
//
// 25 life-story personas with 30-day time series data.
// Each persona has a realistic "life story" with events that affect metrics.
// Used for engine quality validation and LLM judge evaluation.
//
// ⚠️ NEVER DELETE THIS FILE OR THE PERSONA DATA. See CLAUDE.md.

import Foundation
@testable import Thump

// MARK: - Day Override

/// Override for a specific day's metrics. nil = use persona baseline.
public struct DayOverride {
    let sleepHours: Double?
    let rhr: Double?
    let hrv: Double?
    let steps: Double?
    let workoutMinutes: Double?
    let zoneMinutes: [Double]?
    let recoveryHR1m: Double?
    let walkMinutes: Double?
    let vo2Max: Double?

    init(
        sleep: Double? = nil,
        rhr: Double? = nil,
        hrv: Double? = nil,
        steps: Double? = nil,
        workout: Double? = nil,
        zones: [Double]? = nil,
        rec1: Double? = nil,
        walk: Double? = nil,
        vo2: Double? = nil
    ) {
        self.sleepHours = sleep
        self.rhr = rhr
        self.hrv = hrv
        self.steps = steps
        self.workoutMinutes = workout
        self.zoneMinutes = zones
        self.recoveryHR1m = rec1
        self.walkMinutes = walk
        self.vo2Max = vo2
    }
}

// MARK: - Life Story Persona

public struct LifeStoryPersona {
    public let id: String
    public let name: String
    public let age: Int
    public let sex: BiologicalSex
    public let bodyMassKg: Double
    public let heightM: Double
    public let story: String
    public let criticalDays: [Int: String]  // day index -> what to validate

    // Baseline ranges (normal day)
    let baselineRHR: (Double, Double)
    let baselineHRV: (Double, Double)
    let baselineRec1: (Double, Double)
    let baselineVO2: (Double, Double)
    let baselineSteps: (Double, Double)
    let baselineWalk: (Double, Double)
    let baselineWorkout: (Double, Double)
    let baselineSleep: (Double, Double)
    let baselineZones: [Double]

    // Day overrides — the "life events"
    let dayOverrides: [Int: DayOverride]
}

// MARK: - Snapshot Generation

extension LifeStoryPersona {

    /// Generate 30-day history. Day 29 = today.
    public func generateHistory(days: Int = 30) -> [HeartSnapshot] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let personaSeed = id.hashValue & 0xFFFF

        return (0..<days).map { offset in
            let dayDate = calendar.date(byAdding: .day, value: -(days - 1 - offset), to: today)!
            let seed = personaSeed &+ offset &* 13 &+ 7
            let override = dayOverrides[offset]

            // Previous day's sleep affects today's RHR/HRV
            let prevOverride = offset > 0 ? dayOverrides[offset - 1] : nil
            let prevSleep = prevOverride?.sleepHours
            let sleepDebtMod: Double = {
                guard let ps = prevSleep else { return 1.0 }
                if ps < 4.0 { return 1.15 }  // 15% RHR elevation after terrible sleep
                if ps < 5.0 { return 1.08 }
                if ps < 6.0 { return 1.04 }
                return 1.0
            }()
            let sleepHRVMod: Double = {
                guard let ps = prevSleep else { return 1.0 }
                if ps < 4.0 { return 0.70 }  // 30% HRV depression
                if ps < 5.0 { return 0.82 }
                if ps < 6.0 { return 0.90 }
                return 1.0
            }()

            let noise = { (s: Int, range: Double) -> Double in
                Self.seededRandom(min: -range, max: range, seed: s)
            }

            // Resolve each metric: override > baseline + noise + carry-over effects
            let rhr = override?.rhr
                ?? (Self.seededRandom(min: baselineRHR.0, max: baselineRHR.1, seed: seed &+ 10)
                    * sleepDebtMod + noise(seed &+ 100, 2.0))
            let hrv = override?.hrv
                ?? (Self.seededRandom(min: baselineHRV.0, max: baselineHRV.1, seed: seed &+ 11)
                    * sleepHRVMod + noise(seed &+ 101, 3.0))
            let sleep = override?.sleepHours
                ?? (Self.seededRandom(min: baselineSleep.0, max: baselineSleep.1, seed: seed &+ 12)
                    + noise(seed &+ 102, 0.3))
            let steps = override?.steps
                ?? (Self.seededRandom(min: baselineSteps.0, max: baselineSteps.1, seed: seed &+ 13)
                    + noise(seed &+ 103, 500))
            let workout = override?.workoutMinutes
                ?? (Self.seededRandom(min: baselineWorkout.0, max: baselineWorkout.1, seed: seed &+ 14)
                    + noise(seed &+ 104, 3))
            let walk = override?.walkMinutes
                ?? (Self.seededRandom(min: baselineWalk.0, max: baselineWalk.1, seed: seed &+ 15)
                    + noise(seed &+ 105, 3))
            let rec1 = override?.recoveryHR1m
                ?? (Self.seededRandom(min: baselineRec1.0, max: baselineRec1.1, seed: seed &+ 16)
                    + noise(seed &+ 106, 3))
            let vo2 = override?.vo2Max
                ?? (Self.seededRandom(min: baselineVO2.0, max: baselineVO2.1, seed: seed &+ 17)
                    + noise(seed &+ 107, 1.0))

            let zones: [Double]
            if let z = override?.zoneMinutes {
                zones = z
            } else {
                zones = baselineZones.map { $0 * Self.seededRandom(min: 0.7, max: 1.3, seed: seed &+ 20 &+ Int($0.truncatingRemainder(dividingBy: 100))) }
            }

            return HeartSnapshot(
                date: dayDate,
                restingHeartRate: max(40, rhr),
                hrvSDNN: max(5, hrv),
                recoveryHR1m: workout > 5 ? max(5, rec1) : nil,  // No recovery if no workout
                recoveryHR2m: workout > 5 ? max(10, rec1 + Self.seededRandom(min: 8, max: 14, seed: seed &+ 18)) : nil,
                vo2Max: max(15, vo2),
                zoneMinutes: zones.map { max(0, $0) },
                steps: max(0, steps),
                walkMinutes: max(0, walk),
                workoutMinutes: max(0, workout),
                sleepHours: max(0, min(14, sleep)),
                bodyMassKg: bodyMassKg + Self.seededRandom(min: -0.3, max: 0.3, seed: seed &+ 30),
                heightM: heightM
            )
        }
    }

    public var todaySnapshot: HeartSnapshot {
        generateHistory(days: 30).last!
    }

    // MARK: - Seeded Random

    private static func seededRandom(min: Double, max: Double, seed: Int) -> Double {
        var state = UInt64(abs(seed) &+ 1)
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        let fraction = Double(state >> 33) / Double(UInt32.max)
        return min + fraction * (max - min)
    }
}

// MARK: - All 25 Personas

public enum LifeStoryPersonas {

    // MARK: 1. Sarah, New Mom (6 good + every 3rd night baby wakes)
    public static let sarahNewMom = LifeStoryPersona(
        id: "sarah_new_mom",
        name: "Sarah (New Mom, 34F)",
        age: 34, sex: .female, bodyMassKg: 68, heightM: 1.65,
        story: "6 days decent sleep (~6.5h), every 3rd night baby wakes → 3h sleep. Good activity on ok days.",
        criticalDays: [
            2: "3h sleep night → should NOT push next day",
            5: "3h sleep night → should recognize pattern",
            8: "3h sleep night → cumulative debt should show",
            29: "After 3h night: engine must say REST"
        ],
        baselineRHR: (64, 72), baselineHRV: (30, 48), baselineRec1: (18, 28),
        baselineVO2: (32, 38), baselineSteps: (5000, 9000), baselineWalk: (15, 40),
        baselineWorkout: (0, 25), baselineSleep: (6.0, 7.0), baselineZones: [180, 35, 15, 4, 0],
        dayOverrides: [
            2: DayOverride(sleep: 3.0, rhr: 78, hrv: 22),
            5: DayOverride(sleep: 3.2, rhr: 77, hrv: 24),
            8: DayOverride(sleep: 2.8, rhr: 80, hrv: 20),
            11: DayOverride(sleep: 3.1, rhr: 79, hrv: 21),
            14: DayOverride(sleep: 3.0, rhr: 78, hrv: 23),
            17: DayOverride(sleep: 2.5, rhr: 82, hrv: 18),
            20: DayOverride(sleep: 3.3, rhr: 77, hrv: 24),
            23: DayOverride(sleep: 3.0, rhr: 79, hrv: 22),
            26: DayOverride(sleep: 2.8, rhr: 80, hrv: 20),
            29: DayOverride(sleep: 3.0, rhr: 78, hrv: 22)
        ]
    )

    // MARK: 2. Mike, Weekend Warrior (sedentary weekdays, hammers weekends)
    public static let mikeWeekendWarrior = LifeStoryPersona(
        id: "mike_weekend_warrior",
        name: "Mike (Weekend Warrior, 38M)",
        age: 38, sex: .male, bodyMassKg: 88, heightM: 1.80,
        story: "Desk job M-F (800 steps), then 90min intense zone 4-5 on Sat-Sun. RHR creeps up weekdays.",
        criticalDays: [
            5: "Saturday hammer session after 5 sedentary days — overexertion risk",
            6: "Sunday second hammer — should flag recovery need",
            12: "Another Saturday blast — should warn about pattern",
            29: "Monday after weekend — should NOT push, recovery needed"
        ],
        baselineRHR: (68, 76), baselineHRV: (28, 42), baselineRec1: (14, 24),
        baselineVO2: (30, 36), baselineSteps: (800, 2000), baselineWalk: (5, 12),
        baselineWorkout: (0, 5), baselineSleep: (6.5, 7.5), baselineZones: [260, 15, 3, 0, 0],
        dayOverrides: {
            var d: [Int: DayOverride] = [:]
            // Weekends: days 5,6, 12,13, 19,20, 26,27
            for sat in [5, 12, 19, 26] {
                d[sat] = DayOverride(steps: 12000, workout: 90, zones: [60, 15, 20, 35, 25], rec1: 18, walk: 30)
                d[sat + 1] = DayOverride(steps: 10000, workout: 75, zones: [70, 15, 18, 28, 20], rec1: 16, walk: 25)
            }
            // Monday after: sore, RHR elevated
            for mon in [0, 7, 14, 21, 28, 29] {
                if d[mon] == nil {
                    d[mon] = DayOverride(rhr: 78, hrv: 24, steps: 900, workout: 0)
                }
            }
            return d
        }()
    )

    // MARK: 3. Priya, Grad Student (exam stress + poor sleep)
    public static let priyaGradStudent = LifeStoryPersona(
        id: "priya_grad_student",
        name: "Priya (Grad Student, 26F)",
        age: 26, sex: .female, bodyMassKg: 55, heightM: 1.60,
        story: "Week 1-2 normal. Week 3: exams — stress spikes, sleep crashes to 4-5h for 5 days. Week 4: recovery weekend then normal.",
        criticalDays: [
            14: "Exam week starts — first bad night",
            18: "5th day of exam stress — cumulative debt",
            21: "First recovery day — should not be 'primed' yet",
            29: "Should be mostly recovered by now"
        ],
        baselineRHR: (62, 70), baselineHRV: (35, 55), baselineRec1: (20, 30),
        baselineVO2: (34, 40), baselineSteps: (5000, 10000), baselineWalk: (20, 45),
        baselineWorkout: (0, 30), baselineSleep: (7.0, 8.0), baselineZones: [170, 40, 20, 6, 1],
        dayOverrides: {
            var d: [Int: DayOverride] = [:]
            // Exam week: days 14-18 — stress + poor sleep
            for day in 14...18 {
                d[day] = DayOverride(sleep: Double.random(in: 3.8...5.2),
                                     rhr: Double.random(in: 74...82),
                                     hrv: Double.random(in: 18...28),
                                     steps: Double.random(in: 1500...3000),
                                     workout: 0)
            }
            // Recovery days 19-20
            d[19] = DayOverride(sleep: 9.5, rhr: 70, hrv: 32, steps: 4000, workout: 0)
            d[20] = DayOverride(sleep: 9.0, rhr: 68, hrv: 36, steps: 5000, workout: 0)
            return d
        }()
    )

    // MARK: 4. Jake, Party Phase (2 consecutive nights out)
    public static let jakePartyPhase = LifeStoryPersona(
        id: "jake_party",
        name: "Jake (Party Phase, 28M)",
        age: 28, sex: .male, bodyMassKg: 78, heightM: 1.78,
        story: "Good baseline. Days 20-21: two nights out (2-3h sleep, high RHR from alcohol). Days 22-24: recovery.",
        criticalDays: [
            20: "First party night — 2.5h sleep",
            21: "Second party night — 2h sleep, RHR 90+",
            22: "Day after 2 nights: MUST be hard recovering",
            23: "Still recovering — should not be 'ready'",
            29: "Should be fully recovered by now"
        ],
        baselineRHR: (60, 68), baselineHRV: (40, 60), baselineRec1: (22, 34),
        baselineVO2: (38, 44), baselineSteps: (7000, 12000), baselineWalk: (20, 50),
        baselineWorkout: (15, 45), baselineSleep: (7.0, 8.5), baselineZones: [150, 40, 25, 10, 3],
        dayOverrides: [
            20: DayOverride(sleep: 2.5, rhr: 88, hrv: 18, steps: 15000, workout: 0, zones: [120, 10, 0, 0, 0]),
            21: DayOverride(sleep: 2.0, rhr: 92, hrv: 14, steps: 13000, workout: 0, zones: [110, 8, 0, 0, 0]),
            22: DayOverride(sleep: 5.0, rhr: 82, hrv: 22, steps: 2000, workout: 0),
            23: DayOverride(sleep: 8.5, rhr: 74, hrv: 30, steps: 4000, workout: 0),
            24: DayOverride(sleep: 8.0, rhr: 68, hrv: 38, steps: 6000, workout: 10)
        ]
    )

    // MARK: 5. Linda, Retiree (sedentary but great sleep)
    public static let lindaRetiree = LifeStoryPersona(
        id: "linda_retiree",
        name: "Linda (Retiree, 65F)",
        age: 65, sex: .female, bodyMassKg: 72, heightM: 1.62,
        story: "Very low activity (2000 steps), excellent 8h sleep, minimal stress. Engine should nudge activity, not just celebrate sleep.",
        criticalDays: [
            15: "2 weeks in — should be strongly nudging activity",
            29: "30 days sedentary — activity nudge should be prominent"
        ],
        baselineRHR: (68, 76), baselineHRV: (18, 30), baselineRec1: (10, 18),
        baselineVO2: (22, 28), baselineSteps: (1500, 2500), baselineWalk: (8, 15),
        baselineWorkout: (0, 0), baselineSleep: (7.5, 8.5), baselineZones: [280, 10, 2, 0, 0],
        dayOverrides: [:]
    )

    // MARK: 6. Carlos, Overtrainer (60+ min daily zone 4-5, RHR creeping)
    public static let carlosOvertrainer = LifeStoryPersona(
        id: "carlos_overtrainer",
        name: "Carlos (Overtrainer, 32M)",
        age: 32, sex: .male, bodyMassKg: 75, heightM: 1.76,
        story: "Runs 60+ min daily in zone 4-5. RHR creeps up 1 bpm/week. HRV declining. Should flag overtraining.",
        criticalDays: [
            7: "Week 1 end — early warning signs",
            14: "Week 2 — RHR 5 bpm above start, clear overtraining",
            21: "Week 3 — should be urgent flag",
            29: "Engine must say STOP training, not encourage"
        ],
        baselineRHR: (52, 58), baselineHRV: (50, 70), baselineRec1: (30, 42),
        baselineVO2: (48, 54), baselineSteps: (10000, 16000), baselineWalk: (30, 60),
        baselineWorkout: (60, 90), baselineSleep: (6.5, 7.5), baselineZones: [80, 20, 20, 30, 20],
        dayOverrides: {
            var d: [Int: DayOverride] = [:]
            // RHR creeps up 0.5 bpm every 2 days, HRV drops
            for day in 0..<30 {
                let rhrCreep = 52.0 + Double(day) * 0.5
                let hrvDrop = 65.0 - Double(day) * 0.8
                d[day] = DayOverride(
                    rhr: rhrCreep + Double.random(in: -1...1),
                    hrv: max(20, hrvDrop + Double.random(in: -3...3)),
                    workout: Double.random(in: 60...90),
                    zones: [60, 15, 15, 30 + Double(day) * 0.3, 20],
                    rec1: max(15, 38.0 - Double(day) * 0.4)
                )
            }
            return d
        }()
    )

    // MARK: 7. Emma, Shift Worker (alternating day/night shifts)
    public static let emmaShiftWorker = LifeStoryPersona(
        id: "emma_shift_worker",
        name: "Emma (Shift Worker, 40F)",
        age: 40, sex: .female, bodyMassKg: 65, heightM: 1.68,
        story: "Alternates 3 day shifts / 3 night shifts. Sleep 4-6h fragmented on night shifts, 7h on day shifts.",
        criticalDays: [
            3: "First night shift block — sleep crashes",
            6: "Transition back to day — worst day",
            15: "Mid-month — cumulative circadian disruption",
            29: "Pattern should be recognized, not treated as isolated"
        ],
        baselineRHR: (66, 74), baselineHRV: (25, 40), baselineRec1: (16, 26),
        baselineVO2: (30, 36), baselineSteps: (6000, 10000), baselineWalk: (20, 40),
        baselineWorkout: (0, 20), baselineSleep: (6.5, 7.5), baselineZones: [180, 35, 15, 4, 0],
        dayOverrides: {
            var d: [Int: DayOverride] = [:]
            // Night shift blocks: days 3-5, 9-11, 15-17, 21-23, 27-29
            for block in [3, 9, 15, 21, 27] {
                for i in 0...2 {
                    let day = block + i
                    if day < 30 {
                        d[day] = DayOverride(
                            sleep: Double.random(in: 3.5...5.5),
                            rhr: Double.random(in: 72...80),
                            hrv: Double.random(in: 18...28)
                        )
                    }
                }
            }
            return d
        }()
    )

    // MARK: 8. Tom, Desk Jockey (12h sitting, good sleep)
    public static let tomDeskJockey = LifeStoryPersona(
        id: "tom_desk_jockey",
        name: "Tom (Desk Jockey, 42M)",
        age: 42, sex: .male, bodyMassKg: 90, heightM: 1.82,
        story: "500 steps, 12h desk, but sleeps 8h and low stress. Engine should strongly nudge movement.",
        criticalDays: [
            15: "2 weeks: should warn about inactivity",
            29: "Should NOT say 'primed' despite good sleep/HRV — needs movement"
        ],
        baselineRHR: (70, 78), baselineHRV: (30, 45), baselineRec1: (10, 18),
        baselineVO2: (28, 34), baselineSteps: (400, 800), baselineWalk: (3, 8),
        baselineWorkout: (0, 0), baselineSleep: (7.5, 8.5), baselineZones: [290, 5, 1, 0, 0],
        dayOverrides: [:]
    )

    // MARK: 9. Aisha, Consistent Athlete (control — perfect baseline)
    public static let aishaConsistentAthlete = LifeStoryPersona(
        id: "aisha_consistent",
        name: "Aisha (Consistent Athlete, 30F)",
        age: 30, sex: .female, bodyMassKg: 60, heightM: 1.70,
        story: "45min moderate daily, 7.5h sleep, low stress, good HRV. Control persona — should show 'primed' consistently.",
        criticalDays: [
            15: "Should be consistently primed",
            29: "Should be primed with celebrating nudge"
        ],
        baselineRHR: (54, 60), baselineHRV: (50, 72), baselineRec1: (28, 38),
        baselineVO2: (42, 48), baselineSteps: (8000, 12000), baselineWalk: (30, 50),
        baselineWorkout: (40, 55), baselineSleep: (7.0, 8.0), baselineZones: [120, 45, 30, 12, 3],
        dayOverrides: [:]
    )

    // MARK: 10. Dave, Stress Spiral (progressive deterioration)
    public static let daveStressSpiral = LifeStoryPersona(
        id: "dave_stress_spiral",
        name: "Dave (Stress Spiral, 45M)",
        age: 45, sex: .male, bodyMassKg: 85, heightM: 1.78,
        story: "Week 1 fine. Week 2 stress creeps (HRV drops 15%). Week 3 HRV crashes. Should detect trend BEFORE crash.",
        criticalDays: [
            10: "Stress starting to show — should give early warning",
            17: "HRV visibly declining — should flag",
            22: "HRV crash — hard recovery recommendation",
            29: "If not improving, should escalate"
        ],
        baselineRHR: (64, 72), baselineHRV: (35, 50), baselineRec1: (18, 28),
        baselineVO2: (34, 40), baselineSteps: (5000, 9000), baselineWalk: (15, 35),
        baselineWorkout: (0, 25), baselineSleep: (6.5, 7.5), baselineZones: [180, 35, 15, 4, 0],
        dayOverrides: {
            var d: [Int: DayOverride] = [:]
            // Week 2 (days 7-13): gradual stress
            for day in 7...13 {
                let pct = Double(day - 7) / 6.0
                d[day] = DayOverride(
                    rhr: 68 + pct * 6,
                    hrv: 45 - pct * 10,
                    steps: 6000 - pct * 2000
                )
            }
            // Week 3 (days 14-20): crash
            for day in 14...20 {
                d[day] = DayOverride(
                    sleep: Double.random(in: 4.5...5.5),
                    rhr: Double.random(in: 78...86),
                    hrv: Double.random(in: 15...22),
                    steps: Double.random(in: 2000...4000),
                    workout: 0
                )
            }
            // Week 4 (days 21-29): slow recovery
            for day in 21...29 {
                let recoveryPct = Double(day - 21) / 8.0
                d[day] = DayOverride(
                    sleep: 6.0 + recoveryPct * 1.5,
                    rhr: 80 - recoveryPct * 10,
                    hrv: 20 + recoveryPct * 15,
                    steps: 3000 + recoveryPct * 4000
                )
            }
            return d
        }()
    )

    // MARK: 11. Nina, Coming Back from Injury (gradual ramp)
    public static let ninaInjuryRecovery = LifeStoryPersona(
        id: "nina_injury",
        name: "Nina (Injury Recovery, 35F)",
        age: 35, sex: .female, bodyMassKg: 62, heightM: 1.67,
        story: "Week 1-2: zero activity (injured). Week 3-4: gradually 10→30 min walks. Should ENCOURAGE progress.",
        criticalDays: [
            7: "Week 1 — injured, no activity. Don't scold.",
            21: "Starting walks — should celebrate small wins",
            29: "30 min walks — should praise improvement"
        ],
        baselineRHR: (66, 74), baselineHRV: (30, 45), baselineRec1: (15, 24),
        baselineVO2: (32, 38), baselineSteps: (500, 1500), baselineWalk: (0, 5),
        baselineWorkout: (0, 0), baselineSleep: (7.0, 8.5), baselineZones: [285, 5, 0, 0, 0],
        dayOverrides: {
            var d: [Int: DayOverride] = [:]
            // Week 3: gradual ramp (days 14-20)
            for day in 14...20 {
                let ramp = Double(day - 14) / 6.0
                d[day] = DayOverride(
                    steps: 2000 + ramp * 4000,
                    workout: 0,
                    walk: 10 + ramp * 15
                )
            }
            // Week 4: improving (days 21-29)
            for day in 21...29 {
                let ramp = Double(day - 21) / 8.0
                d[day] = DayOverride(
                    steps: 5000 + ramp * 3000,
                    workout: ramp * 15,
                    rec1: 14 + ramp * 8,
                    walk: 25 + ramp * 15
                )
            }
            return d
        }()
    )

    // MARK: 12. Raj, Sleep Procrastinator (weekday debt + weekend catch-up)
    public static let rajSleepProcrastinator = LifeStoryPersona(
        id: "raj_sleep_procrastinator",
        name: "Raj (Sleep Procrastinator, 30M)",
        age: 30, sex: .male, bodyMassKg: 76, heightM: 1.75,
        story: "Stays up late 5 nights (5.5h), catches up Sat 10h, Sun 9h. Repeating pattern. Weekday readiness should suffer.",
        criticalDays: [
            4: "Friday: 5th bad night — cumulative debt",
            5: "Saturday: 10h sleep — should NOT fully reset",
            11: "2nd Friday: pattern should be recognized",
            29: "Chronic pattern — should warn about consistency"
        ],
        baselineRHR: (62, 70), baselineHRV: (38, 55), baselineRec1: (20, 32),
        baselineVO2: (36, 42), baselineSteps: (6000, 10000), baselineWalk: (20, 40),
        baselineWorkout: (15, 35), baselineSleep: (5.0, 6.0), baselineZones: [160, 40, 22, 8, 2],
        dayOverrides: {
            var d: [Int: DayOverride] = [:]
            for week in 0..<5 {
                let base = week * 7
                // Mon-Fri: poor sleep
                for wd in 0...4 {
                    let day = base + wd
                    if day < 30 {
                        d[day] = DayOverride(sleep: Double.random(in: 4.8...5.8), rhr: 68 + Double(wd), hrv: 40 - Double(wd) * 2)
                    }
                }
                // Sat: catch-up
                let sat = base + 5
                if sat < 30 { d[sat] = DayOverride(sleep: 10.0, rhr: 64, hrv: 48) }
                // Sun: catch-up
                let sun = base + 6
                if sun < 30 { d[sun] = DayOverride(sleep: 9.0, rhr: 62, hrv: 50) }
            }
            return d
        }()
    )

    // MARK: 13. Maria, Anxious Checker (normal metrics, anxiety-sensitive)
    public static let mariaAnxiousChecker = LifeStoryPersona(
        id: "maria_anxious",
        name: "Maria (Anxious Checker, 29F)",
        age: 29, sex: .female, bodyMassKg: 58, heightM: 1.63,
        story: "Normal metrics, slightly variable HRV (anxiety). Text should NOT amplify worry. Minor day-to-day HRV swings.",
        criticalDays: [
            15: "Normal day with slightly low HRV — should NOT catastrophize",
            29: "Normal metrics — language should be reassuring not clinical"
        ],
        baselineRHR: (64, 72), baselineHRV: (28, 52), baselineRec1: (18, 28),
        baselineVO2: (32, 38), baselineSteps: (5000, 9000), baselineWalk: (15, 35),
        baselineWorkout: (0, 25), baselineSleep: (6.5, 7.5), baselineZones: [180, 35, 15, 4, 0],
        dayOverrides: {
            var d: [Int: DayOverride] = [:]
            // Wide HRV swings (anxiety pattern)
            for day in stride(from: 1, to: 30, by: 3) {
                d[day] = DayOverride(hrv: Double.random(in: 20...28))  // Low HRV days
            }
            return d
        }()
    )

    // MARK: 14. Ben, 6-Good-1-Bad (THE BUG: 6 good + 1 terrible)
    public static let benSixGoodOneBad = LifeStoryPersona(
        id: "ben_6good_1bad",
        name: "Ben (6-Good-1-Bad, 35M)",
        age: 35, sex: .male, bodyMassKg: 80, heightM: 1.80,
        story: "6 days: 7.5h sleep, 8000 steps, good HRV. Day 7: 3.5h sleep, 0 activity. Repeating. Engine MUST NOT say 'push' on day 7.",
        criticalDays: [
            6: "First bad day — engine must catch it despite 6 good days",
            13: "Second bad day — pattern recognition",
            20: "Third bad day — should flag the weekly pattern",
            27: "Fourth bad day — clear pattern, strong recovery message",
            29: "Day after bad day — still recovering?"
        ],
        baselineRHR: (60, 66), baselineHRV: (42, 58), baselineRec1: (24, 34),
        baselineVO2: (38, 44), baselineSteps: (7500, 9000), baselineWalk: (25, 45),
        baselineWorkout: (20, 40), baselineSleep: (7.0, 8.0), baselineZones: [140, 40, 25, 10, 3],
        dayOverrides: {
            var d: [Int: DayOverride] = [:]
            // Every 7th day: crash
            for bad in [6, 13, 20, 27] {
                d[bad] = DayOverride(
                    sleep: 3.5, rhr: 78, hrv: 22,
                    steps: 500, workout: 0,
                    zones: [280, 3, 0, 0, 0], rec1: nil, walk: 3
                )
            }
            return d
        }()
    )

    // MARK: 15. Sophie, Gradual Decline (slow degradation)
    public static let sophieGradualDecline = LifeStoryPersona(
        id: "sophie_decline",
        name: "Sophie (Gradual Decline, 44F)",
        age: 44, sex: .female, bodyMassKg: 70, heightM: 1.68,
        story: "Week 1: great. Each week sleep drops 30min, steps drop 1000. Engine should notice TREND.",
        criticalDays: [
            14: "2 weeks in — should notice declining pattern",
            21: "3 weeks — should flag concern",
            29: "Significantly worse than day 1 — should be prominent warning"
        ],
        baselineRHR: (62, 68), baselineHRV: (35, 50), baselineRec1: (20, 30),
        baselineVO2: (34, 40), baselineSteps: (8000, 11000), baselineWalk: (25, 45),
        baselineWorkout: (15, 35), baselineSleep: (7.5, 8.0), baselineZones: [150, 40, 25, 8, 2],
        dayOverrides: {
            var d: [Int: DayOverride] = [:]
            for day in 0..<30 {
                let decline = Double(day) / 29.0
                d[day] = DayOverride(
                    sleep: 8.0 - decline * 2.5,       // 8.0 → 5.5
                    rhr: 64 + decline * 10,             // 64 → 74
                    hrv: 48 - decline * 18,             // 48 → 30
                    steps: 10000 - decline * 6000,      // 10k → 4k
                    workout: 30 - decline * 25          // 30 → 5
                )
            }
            return d
        }()
    )

    // MARK: 16. Alex, All-Nighter (one night 0h sleep)
    public static let alexAllNighter = LifeStoryPersona(
        id: "alex_allnighter",
        name: "Alex (All-Nighter, 27M)",
        age: 27, sex: .male, bodyMassKg: 74, heightM: 1.77,
        story: "Normal baseline. Day 25: 0h sleep (work deadline). Day 26-29: recovery. Day 25 must be hard 'recovering'.",
        criticalDays: [
            25: "0h sleep — absolute minimum readiness, no exercise",
            26: "Day after all-nighter — still recovering",
            27: "2 days after — should be improving but cautious",
            29: "Should be back to normal"
        ],
        baselineRHR: (60, 68), baselineHRV: (40, 58), baselineRec1: (22, 32),
        baselineVO2: (38, 44), baselineSteps: (7000, 11000), baselineWalk: (20, 45),
        baselineWorkout: (15, 40), baselineSleep: (7.0, 8.0), baselineZones: [150, 40, 22, 8, 2],
        dayOverrides: [
            25: DayOverride(sleep: 0.0, rhr: 88, hrv: 12, steps: 1000, workout: 0),
            26: DayOverride(sleep: 6.0, rhr: 78, hrv: 24, steps: 3000, workout: 0),
            27: DayOverride(sleep: 8.5, rhr: 70, hrv: 35, steps: 5000, workout: 0),
            28: DayOverride(sleep: 8.0, rhr: 64, hrv: 45, steps: 7000, workout: 15)
        ]
    )

    // MARK: 17. Fatima, Ramadan (fasting period, disrupted schedule)
    public static let fatimaRamadan = LifeStoryPersona(
        id: "fatima_ramadan",
        name: "Fatima (Ramadan, 33F)",
        age: 33, sex: .female, bodyMassKg: 60, heightM: 1.64,
        story: "Fasting period: disrupted sleep (4-5h), shifted schedule, lower energy. Messaging must be sensitive, no judgment.",
        criticalDays: [
            10: "Fasting established — should be supportive not critical",
            20: "3 weeks fasting — should acknowledge cultural context",
            29: "End of period — should NOT use blame language about sleep"
        ],
        baselineRHR: (64, 72), baselineHRV: (30, 48), baselineRec1: (18, 28),
        baselineVO2: (32, 38), baselineSteps: (4000, 7000), baselineWalk: (15, 30),
        baselineWorkout: (0, 15), baselineSleep: (4.0, 5.5), baselineZones: [200, 25, 8, 2, 0],
        dayOverrides: {
            var d: [Int: DayOverride] = [:]
            // All 30 days: fasting pattern
            for day in 0..<30 {
                d[day] = DayOverride(
                    sleep: Double.random(in: 3.5...5.5),
                    rhr: Double.random(in: 68...78),
                    hrv: Double.random(in: 22...35),
                    steps: Double.random(in: 3000...6000),
                    workout: Double.random(in: 0...10)
                )
            }
            return d
        }()
    )

    // MARK: 18. Chris, Zone Junkie (all zone 5, no base)
    public static let chrisZoneJunkie = LifeStoryPersona(
        id: "chris_zone_junkie",
        name: "Chris (Zone Junkie, 31M)",
        age: 31, sex: .male, bodyMassKg: 77, heightM: 1.79,
        story: "80% of workout in zone 5, ignores zone 2 base. Should flag missing aerobic foundation.",
        criticalDays: [
            15: "Pattern established — should flag zone imbalance",
            29: "Should strongly recommend zone 2 base building"
        ],
        baselineRHR: (58, 66), baselineHRV: (38, 52), baselineRec1: (22, 34),
        baselineVO2: (40, 46), baselineSteps: (8000, 13000), baselineWalk: (20, 40),
        baselineWorkout: (40, 60), baselineSleep: (6.5, 7.5), baselineZones: [100, 10, 8, 15, 45],
        dayOverrides: [:]
    )

    // MARK: 19. Pat, Inconsistent (random chaos)
    public static let patInconsistent = LifeStoryPersona(
        id: "pat_inconsistent",
        name: "Pat (Inconsistent, 37M)",
        age: 37, sex: .male, bodyMassKg: 82, heightM: 1.76,
        story: "Random: some days 12000 steps + gym, some days 0. No pattern. Should reflect day-to-day variance.",
        criticalDays: [
            15: "Check that engine handles chaos without averaging out",
            29: "Ensure today's actual data matters, not just averages"
        ],
        baselineRHR: (64, 76), baselineHRV: (25, 50), baselineRec1: (12, 32),
        baselineVO2: (32, 40), baselineSteps: (500, 14000), baselineWalk: (0, 60),
        baselineWorkout: (0, 60), baselineSleep: (4.5, 9.0), baselineZones: [180, 30, 15, 6, 2],
        dayOverrides: {
            var d: [Int: DayOverride] = [:]
            // Alternate between extremes
            for day in 0..<30 {
                if day % 3 == 0 {
                    // Gym day
                    d[day] = DayOverride(steps: 12000, workout: 60, zones: [80, 30, 25, 15, 8], walk: 40)
                } else if day % 3 == 1 {
                    // Couch day
                    d[day] = DayOverride(sleep: Double.random(in: 4.5...5.5), steps: 600, workout: 0, zones: [285, 3, 0, 0, 0], walk: 3)
                }
                // day % 3 == 2: baseline random
            }
            return d
        }()
    )

    // MARK: 20. Jordan, Night Owl (late but adequate sleep)
    public static let jordanNightOwl = LifeStoryPersona(
        id: "jordan_night_owl",
        name: "Jordan (Night Owl, 25M)",
        age: 25, sex: .male, bodyMassKg: 72, heightM: 1.75,
        story: "Sleeps 1am-8am (7h total), good metrics. Should NOT penalize for timing if duration is fine.",
        criticalDays: [
            15: "Consistent 7h — should be at least 'ready'",
            29: "Should not be penalized for being a night owl"
        ],
        baselineRHR: (58, 66), baselineHRV: (42, 60), baselineRec1: (22, 32),
        baselineVO2: (38, 44), baselineSteps: (6000, 10000), baselineWalk: (20, 40),
        baselineWorkout: (15, 35), baselineSleep: (6.8, 7.5), baselineZones: [150, 40, 22, 8, 2],
        dayOverrides: [:]
    )

    // MARK: 21. Wei, Traveling (jet lag week)
    public static let weiTraveling = LifeStoryPersona(
        id: "wei_traveling",
        name: "Wei (Traveling, 36M)",
        age: 36, sex: .male, bodyMassKg: 73, heightM: 1.73,
        story: "Days 15-18: jet lag, sleep 3-5h fragmented. Days 19-22: adjusting. Should handle multi-day disruption arc.",
        criticalDays: [
            15: "Travel day — worst sleep",
            17: "3rd day jet lag — still disrupted",
            19: "Starting to adjust — still fragile",
            22: "Should be mostly recovered"
        ],
        baselineRHR: (62, 70), baselineHRV: (35, 52), baselineRec1: (20, 30),
        baselineVO2: (36, 42), baselineSteps: (6000, 10000), baselineWalk: (20, 45),
        baselineWorkout: (10, 30), baselineSleep: (7.0, 8.0), baselineZones: [160, 40, 20, 6, 1],
        dayOverrides: [
            15: DayOverride(sleep: 3.0, rhr: 78, hrv: 20, steps: 15000, workout: 0),  // Travel day, lots of walking
            16: DayOverride(sleep: 4.0, rhr: 76, hrv: 24, steps: 8000, workout: 0),
            17: DayOverride(sleep: 4.5, rhr: 74, hrv: 26, steps: 6000, workout: 0),
            18: DayOverride(sleep: 5.0, rhr: 72, hrv: 30, steps: 7000, workout: 0),
            19: DayOverride(sleep: 5.5, rhr: 70, hrv: 34, steps: 7000, workout: 5),
            20: DayOverride(sleep: 6.5, rhr: 68, hrv: 38, steps: 8000, workout: 10),
            21: DayOverride(sleep: 7.0, rhr: 66, hrv: 42, steps: 9000, workout: 15)
        ]
    )

    // MARK: 22. Olivia, New to Fitness (positive adaptation)
    public static let oliviaNewToFitness = LifeStoryPersona(
        id: "olivia_new_fitness",
        name: "Olivia (New to Fitness, 40F)",
        age: 40, sex: .female, bodyMassKg: 75, heightM: 1.66,
        story: "Week 1-2: 15min walks. Week 3-4: 30min jogs. RHR dropping, HRV improving. Should celebrate improvement.",
        criticalDays: [
            14: "2 weeks in — should see some improvement",
            21: "Started jogging — should encourage",
            29: "RHR dropped, HRV up — should celebrate trend"
        ],
        baselineRHR: (72, 80), baselineHRV: (22, 35), baselineRec1: (10, 18),
        baselineVO2: (26, 32), baselineSteps: (3000, 5000), baselineWalk: (10, 20),
        baselineWorkout: (0, 15), baselineSleep: (7.0, 8.0), baselineZones: [240, 20, 8, 2, 0],
        dayOverrides: {
            var d: [Int: DayOverride] = [:]
            for day in 0..<30 {
                let progress = Double(day) / 29.0
                d[day] = DayOverride(
                    rhr: 78 - progress * 8,             // 78 → 70
                    hrv: 28 + progress * 12,            // 28 → 40
                    steps: 3500 + progress * 5000,      // 3.5k → 8.5k
                    workout: progress * 35,             // 0 → 35
                    rec1: 12 + progress * 10,           // 12 → 22
                    walk: 12 + progress * 25,           // 12 → 37
                    vo2: 28 + progress * 5              // 28 → 33
                )
            }
            return d
        }()
    )

    // MARK: 23. Ryan, Gym-Then-Crash (2 good workouts → 4h sleep)
    public static let ryanGymThenCrash = LifeStoryPersona(
        id: "ryan_gym_crash",
        name: "Ryan (Gym-Then-Crash, 33M)",
        age: 33, sex: .male, bodyMassKg: 82, heightM: 1.80,
        story: "Repeating: 2 days solid workouts (45min z3-4) → Day 3: 4h sleep. Engine should NOT recommend workout despite momentum.",
        criticalDays: [
            2: "First crash day — 4h sleep after 2 good days",
            5: "Second crash — pattern forming",
            8: "Third crash — should flag the pattern",
            29: "Crash day: engine MUST say rest, not workout"
        ],
        baselineRHR: (62, 68), baselineHRV: (38, 52), baselineRec1: (22, 32),
        baselineVO2: (38, 44), baselineSteps: (7000, 10000), baselineWalk: (20, 40),
        baselineWorkout: (35, 50), baselineSleep: (7.0, 8.0), baselineZones: [130, 35, 30, 15, 5],
        dayOverrides: {
            var d: [Int: DayOverride] = [:]
            for cycle in 0..<10 {
                let base = cycle * 3
                // Day 0,1: good workouts
                if base < 30 {
                    d[base] = DayOverride(workout: 45, zones: [100, 30, 30, 20, 5], rec1: 28)
                }
                if base + 1 < 30 {
                    d[base + 1] = DayOverride(workout: 50, zones: [95, 28, 32, 22, 6], rec1: 30)
                }
                // Day 2: crash
                if base + 2 < 30 {
                    d[base + 2] = DayOverride(
                        sleep: 4.0, rhr: 76, hrv: 26,
                        steps: 3000, workout: 0,
                        zones: [270, 8, 0, 0, 0], walk: 10
                    )
                }
            }
            return d
        }()
    )

    // MARK: 24. Tanya, Accumulating Debt (2 good + 2 bad nights)
    public static let tanyaAccumulatingDebt = LifeStoryPersona(
        id: "tanya_accumulating_debt",
        name: "Tanya (Accumulating Debt, 31F)",
        age: 31, sex: .female, bodyMassKg: 60, heightM: 1.65,
        story: "Repeating: 2 days good workouts → Day 3: 4.5h sleep → Day 4: 4h sleep. Back-to-back bad. Day 4 MUST be worse than Day 3.",
        criticalDays: [
            2: "First bad night (4.5h) after workouts",
            3: "Second bad night (4h) — MUST escalate from day 2",
            6: "Pattern repeat: first bad night",
            7: "Pattern repeat: second bad night — worse than day 6",
            29: "Late-month bad night — cumulative debt should show"
        ],
        baselineRHR: (62, 70), baselineHRV: (34, 50), baselineRec1: (20, 30),
        baselineVO2: (34, 40), baselineSteps: (6000, 9000), baselineWalk: (20, 40),
        baselineWorkout: (25, 40), baselineSleep: (7.0, 8.0), baselineZones: [150, 35, 25, 10, 2],
        dayOverrides: {
            var d: [Int: DayOverride] = [:]
            for cycle in 0..<8 {
                let base = cycle * 4
                // Day 0,1: good
                if base < 30 {
                    d[base] = DayOverride(workout: 40, zones: [110, 30, 28, 15, 4])
                }
                if base + 1 < 30 {
                    d[base + 1] = DayOverride(workout: 45, zones: [105, 28, 30, 18, 5])
                }
                // Day 2: first bad night
                if base + 2 < 30 {
                    d[base + 2] = DayOverride(
                        sleep: 4.5, rhr: 74, hrv: 28,
                        steps: 4000, workout: 0, walk: 12
                    )
                }
                // Day 3: second bad night — WORSE
                if base + 3 < 30 {
                    d[base + 3] = DayOverride(
                        sleep: 4.0, rhr: 80, hrv: 22,
                        steps: 2500, workout: 0, walk: 8
                    )
                }
            }
            return d
        }()
    )

    // MARK: 25. Marcus, Split Pattern (good workouts on bad sleep)
    public static let marcusSplitPattern = LifeStoryPersona(
        id: "marcus_split",
        name: "Marcus (Split Pattern, 29M)",
        age: 29, sex: .male, bodyMassKg: 78, heightM: 1.81,
        story: "Days 1-4: normal. Days 5-7: great workouts but 4-5h sleep each night. Repeating. Training on no sleep = counterproductive.",
        criticalDays: [
            6: "3rd day of good workouts + bad sleep",
            13: "Pattern repeat: 3 days train + no sleep",
            20: "Engine should flag: workouts look great but body is deteriorating",
            29: "Should say: stop training hard until sleep improves"
        ],
        baselineRHR: (60, 68), baselineHRV: (40, 56), baselineRec1: (24, 34),
        baselineVO2: (40, 46), baselineSteps: (7000, 11000), baselineWalk: (20, 40),
        baselineWorkout: (20, 35), baselineSleep: (7.0, 8.0), baselineZones: [140, 40, 25, 10, 3],
        dayOverrides: {
            var d: [Int: DayOverride] = [:]
            for week in 0..<5 {
                let base = week * 7
                // Days 0-3: normal (use baseline)
                // Days 4-6: good workouts + bad sleep
                for i in 4...6 {
                    let day = base + i
                    if day < 30 {
                        d[day] = DayOverride(
                            sleep: Double.random(in: 3.8...5.0),
                            rhr: 70 + Double(i - 4) * 3,     // RHR creeps up through block
                            hrv: 32 - Double(i - 4) * 4,     // HRV drops
                            steps: 10000,
                            workout: 55,
                            zones: [80, 25, 30, 20, 8],
                            rec1: 22                           // Recovery gets worse on bad sleep
                        )
                    }
                }
            }
            return d
        }()
    )

    // MARK: - All Personas

    public static let all: [LifeStoryPersona] = [
        sarahNewMom,           // 1.  6 good + baby wake every 3rd night
        mikeWeekendWarrior,    // 2.  Sedentary weekdays, hammer weekends
        priyaGradStudent,      // 3.  Exam stress week
        jakePartyPhase,        // 4.  2 nights out
        lindaRetiree,          // 5.  Sedentary + great sleep
        carlosOvertrainer,     // 6.  Chronic overtraining
        emmaShiftWorker,       // 7.  Alternating shifts
        tomDeskJockey,         // 8.  Extreme sedentary + good vitals
        aishaConsistentAthlete,// 9.  Control — perfect baseline
        daveStressSpiral,      // 10. Progressive deterioration
        ninaInjuryRecovery,    // 11. Coming back from injury
        rajSleepProcrastinator,// 12. Weekday debt + weekend catch-up
        mariaAnxiousChecker,   // 13. Normal metrics, anxiety-sensitive
        benSixGoodOneBad,      // 14. THE BUG: 6 good + 1 terrible
        sophieGradualDecline,  // 15. Slow degradation
        alexAllNighter,        // 16. One night 0h sleep
        fatimaRamadan,         // 17. Fasting period
        chrisZoneJunkie,       // 18. All zone 5, no base
        patInconsistent,       // 19. Random chaos
        jordanNightOwl,        // 20. Late but adequate sleep
        weiTraveling,          // 21. Jet lag week
        oliviaNewToFitness,    // 22. Positive adaptation
        ryanGymThenCrash,      // 23. 2 good workouts → crash
        tanyaAccumulatingDebt, // 24. 2 good + 2 bad nights (escalating)
        marcusSplitPattern     // 25. Good workouts on bad sleep
    ]
}
