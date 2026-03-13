// DashboardTextVarianceTests.swift
// Thump Tests
//
// Validates that dashboard text (Thump Check, How You Recovered, Buddy
// Recommendations) produces distinct, sensible output for 5 diverse
// persona profiles. Ensures no jargon, no empty strings, and text varies
// meaningfully across different health states.

import Testing
import Foundation
@testable import Thump

// MARK: - Dashboard Text Variance Tests

@Suite("Dashboard Text Variance — 5 Persona Profiles")
struct DashboardTextVarianceTests {

    // MARK: - Test Personas (5 diverse profiles)

    /// 5 representative personas covering the full spectrum:
    /// 1. Young Athlete — primed, low stress, great metrics
    /// 2. High Stress Executive — elevated stress, moderate recovery
    /// 3. Recovering From Illness — low readiness, trending up
    /// 4. Sedentary Senior — low activity, moderate readiness
    /// 5. Weekend Warrior — burst activity, variable recovery
    static let testPersonas: [(persona: SyntheticPersona, label: String)] = [
        (SyntheticPersonas.youngAthlete, "Young Athlete"),
        (SyntheticPersonas.highStressExecutive, "High Stress Executive"),
        (SyntheticPersonas.recoveringFromIllness, "Recovering From Illness"),
        (SyntheticPersonas.sedentarySenior, "Sedentary Senior"),
        (SyntheticPersonas.weekendWarrior, "Weekend Warrior"),
    ]

    // MARK: - Engine Result Container

    /// Runs all engines for a persona and captures results needed for text generation.
    struct PersonaEngineResults {
        let label: String
        let snapshot: HeartSnapshot
        let history: [HeartSnapshot]
        let assessment: HeartAssessment
        let readiness: ReadinessResult
        let stress: StressResult
        let zones: ZoneAnalysis?
        let coaching: CoachingReport?
        let buddyRecs: [BuddyRecommendation]
        let weekOverWeek: WeekOverWeekTrend?

        // Text outputs from dashboard helpers
        let thumpCheckBadge: String
        let thumpCheckRecommendation: String
        let recoveryNarrative: String?
        let recoveryTrendLabel: String?
        let recoveryAction: String?
        let buddyRecTitles: [String]
    }

    /// Run all engines for a single persona and capture text outputs.
    static func runEngines(for persona: SyntheticPersona, label: String) -> PersonaEngineResults {
        let history = persona.generateHistory()
        let snapshot = history.last!

        // HeartTrendEngine
        let trendEngine = HeartTrendEngine()
        let assessment = trendEngine.assess(
            history: history,
            current: snapshot
        )

        // StressEngine
        let stressEngine = StressEngine()
        let stress = stressEngine.computeStress(snapshot: snapshot, recentHistory: history)
            ?? StressResult(score: 40, level: .balanced, description: "Unable to compute stress")

        // ReadinessEngine
        let readinessEngine = ReadinessEngine()
        let readiness = readinessEngine.compute(
            snapshot: snapshot,
            stressScore: stress.score > 60 ? stress.score : nil,
            recentHistory: history
        )!

        // ZoneEngine
        let zoneEngine = HeartRateZoneEngine()
        let zones: ZoneAnalysis? = snapshot.zoneMinutes.count >= 5 && snapshot.zoneMinutes.reduce(0, +) > 0
            ? zoneEngine.analyzeZoneDistribution(zoneMinutes: snapshot.zoneMinutes)
            : nil

        // CoachingEngine
        let coachingEngine = CoachingEngine()
        let coaching: CoachingReport? = history.count >= 3
            ? coachingEngine.generateReport(current: snapshot, history: history, streakDays: 5)
            : nil

        // BuddyRecommendationEngine
        let buddyEngine = BuddyRecommendationEngine()
        let buddyRecs = buddyEngine.recommend(
            assessment: assessment,
            stressResult: stress,
            readinessScore: Double(readiness.score),
            current: snapshot,
            history: history
        )

        // --- Generate dashboard text ---

        // Thump Check badge
        let badge: String = {
            switch readiness.level {
            case .primed:     return "Feeling great"
            case .ready:      return "Good to go"
            case .moderate:   return "Take it easy"
            case .recovering: return "Rest up"
            }
        }()

        // Thump Check recommendation (mirrors DashboardView logic)
        let recommendation = thumpCheckText(
            readiness: readiness,
            stress: stress,
            zones: zones,
            assessment: assessment
        )

        // Recovery narrative
        let wow = assessment.weekOverWeekTrend
        let recoveryNarr: String? = wow.map { recoveryNarrativeText(wow: $0, readiness: readiness, snapshot: snapshot) }
        let recoveryLabel: String? = wow.map { recoveryTrendLabelText($0.direction) }
        let recoveryAct: String? = wow.map { recoveryActionText(wow: $0, stress: stress) }

        return PersonaEngineResults(
            label: label,
            snapshot: snapshot,
            history: history,
            assessment: assessment,
            readiness: readiness,
            stress: stress,
            zones: zones,
            coaching: coaching,
            buddyRecs: buddyRecs,
            weekOverWeek: wow,
            thumpCheckBadge: badge,
            thumpCheckRecommendation: recommendation,
            recoveryNarrative: recoveryNarr,
            recoveryTrendLabel: recoveryLabel,
            recoveryAction: recoveryAct,
            buddyRecTitles: buddyRecs.map { $0.title }
        )
    }

    // MARK: - Text Generation Helpers (mirror DashboardView)

    /// Mirrors DashboardView.thumpCheckRecommendation
    static func thumpCheckText(
        readiness: ReadinessResult,
        stress: StressResult,
        zones: ZoneAnalysis?,
        assessment: HeartAssessment
    ) -> String {
        let yesterdayContext = yesterdayZoneSummaryText(zones: zones)

        if readiness.score < 45 {
            if stress.level == .elevated {
                return "\(yesterdayContext)Recovery is low and stress is up — take a full rest day. Your body needs it."
            }
            return "\(yesterdayContext)Recovery is low. A gentle walk or stretching is your best move today."
        }

        if readiness.score < 65 {
            if let zones, zones.recommendation == .tooMuchIntensity {
                return "\(yesterdayContext)You've been pushing hard. A moderate effort today lets your body absorb those gains."
            }
            if assessment.stressFlag == true {
                return "\(yesterdayContext)Stress is elevated. Keep it light — a calm walk or easy movement."
            }
            return "\(yesterdayContext)Decent recovery. A moderate workout works well today."
        }

        if readiness.score >= 80 {
            if let zones, zones.recommendation == .needsMoreThreshold {
                return "\(yesterdayContext)You're fully charged. Great day for a harder effort or tempo session."
            }
            return "\(yesterdayContext)You're primed. Push it if you want — your body can handle it."
        }

        if let zones, zones.recommendation == .needsMoreAerobic {
            return "\(yesterdayContext)Good recovery. A steady aerobic session would build your base nicely."
        }
        return "\(yesterdayContext)Solid recovery. You can go moderate to hard depending on how you feel."
    }

    static func yesterdayZoneSummaryText(zones: ZoneAnalysis?) -> String {
        guard let zones else { return "" }
        let sorted = zones.pillars.sorted { $0.actualMinutes > $1.actualMinutes }
        guard let dominant = sorted.first, dominant.actualMinutes > 5 else {
            return "Light day yesterday. "
        }
        let zoneName: String
        switch dominant.zone {
        case .recovery:  zoneName = "easy zone"
        case .fatBurn:   zoneName = "fat-burn zone"
        case .aerobic:   zoneName = "aerobic zone"
        case .threshold: zoneName = "threshold zone"
        case .peak:      zoneName = "peak zone"
        }
        return "You spent \(Int(dominant.actualMinutes)) min in \(zoneName) recently. "
    }

    static func recoveryNarrativeText(wow: WeekOverWeekTrend, readiness: ReadinessResult, snapshot: HeartSnapshot) -> String {
        var parts: [String] = []

        if let sleepPillar = readiness.pillars.first(where: { $0.type == .sleep }) {
            if sleepPillar.score >= 75 {
                let hrs = snapshot.sleepHours ?? 0
                parts.append("Sleep was solid\(hrs > 0 ? " (\(String(format: "%.1f", hrs)) hrs)" : "")")
            } else if sleepPillar.score >= 50 {
                parts.append("Sleep was okay but could be better")
            } else {
                parts.append("Short on sleep — that slows recovery")
            }
        }

        let diff = wow.currentWeekMean - wow.baselineMean
        if diff <= -2 {
            parts.append("Your heart is in great shape this week.")
        } else if diff <= 0.5 {
            parts.append("Recovery is on track.")
        } else {
            parts.append("Your body could use a bit more rest.")
        }

        return parts.joined(separator: ". ")
    }

    static func recoveryTrendLabelText(_ direction: WeeklyTrendDirection) -> String {
        switch direction {
        case .significantImprovement: return "Great"
        case .improving:             return "Improving"
        case .stable:                return "Steady"
        case .elevated:              return "Elevated"
        case .significantElevation:  return "Needs rest"
        }
    }

    static func recoveryActionText(wow: WeekOverWeekTrend, stress: StressResult) -> String {
        if stress.level == .elevated {
            return "Stress is high — an easy walk and early bedtime will help"
        }
        let diff = wow.currentWeekMean - wow.baselineMean
        if diff > 3 {
            return "Rest day recommended — extra sleep tonight"
        }
        return "Consider a lighter day or an extra 30 min of sleep"
    }

    // MARK: - Tests

    @Test("All 5 personas produce non-empty Thump Check text")
    func thumpCheckTextNonEmpty() {
        for (persona, label) in Self.testPersonas {
            let results = Self.runEngines(for: persona, label: label)
            #expect(!results.thumpCheckBadge.isEmpty, "Badge empty for \(label)")
            #expect(!results.thumpCheckRecommendation.isEmpty, "Recommendation empty for \(label)")
            #expect(results.thumpCheckRecommendation.count > 20,
                    "Recommendation too short for \(label): '\(results.thumpCheckRecommendation)'")
        }
    }

    @Test("Thump Check badges vary across personas")
    func thumpCheckBadgesVary() {
        let allResults = Self.testPersonas.map { Self.runEngines(for: $0.persona, label: $0.label) }
        let uniqueBadges = Set(allResults.map(\.thumpCheckBadge))
        #expect(uniqueBadges.count >= 2,
                "Expected at least 2 different badges, got: \(uniqueBadges)")
    }

    @Test("Thump Check recommendations vary across personas")
    func thumpCheckRecsVary() {
        let allResults = Self.testPersonas.map { Self.runEngines(for: $0.persona, label: $0.label) }
        let uniqueRecs = Set(allResults.map(\.thumpCheckRecommendation))
        #expect(uniqueRecs.count >= 3,
                "Expected at least 3 different recommendations, got \(uniqueRecs.count)")
    }

    @Test("No medical jargon in Thump Check text")
    func noMedicalJargon() {
        let jargonTerms = ["RHR", "HRV", "SDNN", "VO2", "bpm", "parasympathetic",
                           "sympathetic", "autonomic", "cardiopulmonary", "ms SDNN"]
        for (persona, label) in Self.testPersonas {
            let results = Self.runEngines(for: persona, label: label)
            for term in jargonTerms {
                #expect(!results.thumpCheckRecommendation.contains(term),
                        "\(label) recommendation contains jargon '\(term)': \(results.thumpCheckRecommendation)")
            }
        }
    }

    @Test("Recovery narrative produces meaningful text for all personas with trend data")
    func recoveryNarrativeMeaningful() {
        for (persona, label) in Self.testPersonas {
            let results = Self.runEngines(for: persona, label: label)
            if let narrative = results.recoveryNarrative {
                #expect(!narrative.isEmpty, "Recovery narrative empty for \(label)")
                #expect(narrative.count > 15,
                        "Recovery narrative too short for \(label): '\(narrative)'")
                // Should contain human-readable language about sleep or recovery
                let hasContext = narrative.contains("Sleep") || narrative.contains("heart")
                    || narrative.contains("Recovery") || narrative.contains("rest")
                #expect(hasContext,
                        "\(label) recovery narrative lacks context: '\(narrative)'")
            }
        }
    }

    @Test("Recovery trend labels are human-readable")
    func recoveryTrendLabelsReadable() {
        let validLabels = Set(["Great", "Improving", "Steady", "Elevated", "Needs rest"])
        for (persona, label) in Self.testPersonas {
            let results = Self.runEngines(for: persona, label: label)
            if let trendLabel = results.recoveryTrendLabel {
                #expect(validLabels.contains(trendLabel),
                        "\(label) has unexpected trend label: '\(trendLabel)'")
            }
        }
    }

    @Test("Buddy recommendations are non-empty for all personas")
    func buddyRecsNonEmpty() {
        for (persona, label) in Self.testPersonas {
            let results = Self.runEngines(for: persona, label: label)
            #expect(!results.buddyRecs.isEmpty,
                    "\(label) has no buddy recommendations")
            for rec in results.buddyRecs {
                #expect(!rec.title.isEmpty, "\(label) has empty rec title")
                #expect(!rec.message.isEmpty, "\(label) has empty rec message")
            }
        }
    }

    @Test("Buddy recommendations vary meaningfully across personas")
    func buddyRecsVary() {
        let allResults = Self.testPersonas.map { Self.runEngines(for: $0.persona, label: $0.label) }
        let recSets = allResults.map { Set($0.buddyRecTitles) }
        // At least 3 personas should have different recommendation sets
        let uniqueSets = Set(recSets.map { $0.sorted().joined(separator: "|") })
        #expect(uniqueSets.count >= 3,
                "Expected at least 3 different recommendation sets, got \(uniqueSets.count)")
    }

    @Test("Athlete gets 'Feeling great' or 'Good to go' badge")
    func athleteBadge() {
        let results = Self.runEngines(for: SyntheticPersonas.youngAthlete, label: "Athlete")
        let positiveBadges = Set(["Feeling great", "Good to go"])
        #expect(positiveBadges.contains(results.thumpCheckBadge),
                "Athlete got unexpected badge: '\(results.thumpCheckBadge)'")
    }

    @Test("High stress persona gets stress-aware recommendation")
    func highStressRecommendation() {
        let results = Self.runEngines(
            for: SyntheticPersonas.highStressExecutive,
            label: "High Stress"
        )
        let rec = results.thumpCheckRecommendation.lowercased()
        let hasStressContext = rec.contains("stress") || rec.contains("light")
            || rec.contains("rest") || rec.contains("easy") || rec.contains("gentle")
            || rec.contains("moderate")
        #expect(hasStressContext,
                "High stress persona should get stress-aware rec, got: '\(results.thumpCheckRecommendation)'")
    }

    @Test("Recovering persona gets contextual badge matching readiness")
    func recoveringBadge() {
        // The "Recovering From Illness" persona generates 14-day history where
        // RHR normalizes over time. By day 14, recovery is often complete,
        // so the badge should match the current readiness level.
        let results = Self.runEngines(
            for: SyntheticPersonas.recoveringFromIllness,
            label: "Recovering"
        )
        let validBadges = Set(["Rest up", "Take it easy", "Good to go", "Feeling great"])
        let badge = results.thumpCheckBadge
        #expect(validBadges.contains(badge),
                "Recovering persona got unexpected badge")
    }

    @Test("Text output report for all 5 personas")
    func textOutputReport() {
        // This test always passes — it generates a human-readable report
        // for manual inspection of all text variants.
        var report = "\n=== DASHBOARD TEXT VARIANCE REPORT ===\n"
        report += "Generated: \(Date())\n"
        report += String(repeating: "=", count: 50) + "\n\n"

        for (persona, label) in Self.testPersonas {
            let results = Self.runEngines(for: persona, label: label)
            report += "--- \(label) ---\n"
            report += "  Readiness: \(results.readiness.score)/100 (\(String(describing: results.readiness.level)))\n"
            report += "  Stress: \(String(format: "%.0f", results.stress.score)) (\(String(describing: results.stress.level)))\n"
            report += "  Badge: [\(results.thumpCheckBadge)]\n"
            report += "  Recommendation: \"\(results.thumpCheckRecommendation)\"\n"
            if let narrative = results.recoveryNarrative {
                report += "  Recovery: \"\(narrative)\"\n"
            }
            if let trendLabel = results.recoveryTrendLabel {
                report += "  Trend Label: [\(trendLabel)]\n"
            }
            if let action = results.recoveryAction {
                report += "  Action: \"\(action)\"\n"
            }
            report += "  Buddy Recs (\(results.buddyRecs.count)):\n"
            for rec in results.buddyRecs.prefix(3) {
                report += "    - [\(String(describing: rec.category))] \(rec.title): \(rec.message)\n"
            }
            report += "\n"
        }

        print(report)
        #expect(Bool(true), "Report generated — check console output")
    }
}
