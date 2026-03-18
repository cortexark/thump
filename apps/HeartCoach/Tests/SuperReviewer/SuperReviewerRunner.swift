// SuperReviewerRunner.swift
// Thump Tests
//
// Core engine runner for the Super Reviewer system.
// Takes a persona + journey day + timestamp and produces a complete
// SuperReviewerCapture by running all 10 engines, composing AdviceState,
// and mapping through AdvicePresenter for every text field on every page.

import Foundation
@testable import Thump

// MARK: - Runner Configuration

struct SuperReviewerRunConfig {
    let journeys: [JourneyScenario]
    let personas: [PersonaBaseline]
    let timestamps: [TimeOfDayStamp]
    let outputDirectory: String
    let captureJSON: Bool

    static let tierA = SuperReviewerRunConfig(
        journeys: JourneyScenarios.all,
        personas: JourneyPersonas.all,
        timestamps: [
            TimeOfDayStamps.all[2],   // 6:00 AM - early morning
            TimeOfDayStamps.all[8],   // 12:00 PM - midday
            TimeOfDayStamps.all[16],  // 9:00 PM - evening
        ],
        outputDirectory: "SuperReviewerOutput/TierA",
        captureJSON: true
    )

    static let tierB = SuperReviewerRunConfig(
        journeys: JourneyScenarios.all,
        personas: JourneyPersonas.all,
        timestamps: Array(TimeOfDayStamps.all.prefix(10)),
        outputDirectory: "SuperReviewerOutput/TierB",
        captureJSON: true
    )

    static let tierC = SuperReviewerRunConfig(
        journeys: JourneyScenarios.all,
        personas: JourneyPersonas.all,
        timestamps: TimeOfDayStamps.all,
        outputDirectory: "SuperReviewerOutput/TierC",
        captureJSON: true
    )

    var totalCaptures: Int {
        journeys.count * personas.count * timestamps.count * (journeys.first?.dayCount ?? 7)
    }
}

// MARK: - Runner Result

struct SuperReviewerRunResult {
    let captures: [SuperReviewerCapture]
    let failures: [CaptureFailure]
    let totalDurationMs: Double

    struct CaptureFailure {
        let personaName: String
        let journeyID: String
        let dayIndex: Int
        let timestamp: TimeOfDayStamp
        let error: String
    }

    var successRate: Double {
        guard !captures.isEmpty || !failures.isEmpty else { return 0 }
        return Double(captures.count) / Double(captures.count + failures.count)
    }
}

// MARK: - Super Reviewer Runner

struct SuperReviewerRunner {

    // MARK: - Single Capture

    /// Runs the full engine pipeline for a single (persona, journey, day, time) combination
    /// and captures ALL user-facing text from every page.
    static func capture(
        persona: PersonaBaseline,
        journey: JourneyScenario,
        dayIndex: Int,
        timestamp: TimeOfDayStamp,
        config: HealthPolicyConfig = ConfigService.activePolicy
    ) -> SuperReviewerCapture {
        // 1. Generate full history (warmup + journey days) using existing infrastructure
        let allSnapshots = persona.generateJourneyHistory(journey: journey)

        // Extract current day snapshot and prior history
        // generateJourneyHistory returns warmup(7) + journey(dayCount) snapshots
        let warmupDays = 7
        let currentIdx = min(warmupDays + dayIndex, allSnapshots.count - 1)
        let currentSnapshot = allSnapshots[currentIdx]
        let history = Array(allSnapshots[0..<currentIdx])

        // 2. Run engines in DAG order (same as DailyEngineCoordinator)
        let trendEngine = HeartTrendEngine()
        let stressEngine = StressEngine()
        let readinessEngine = ReadinessEngine()
        let coachingEngine = CoachingEngine()
        let bioAgeEngine = BioAgeEngine()
        let zoneEngine = HeartRateZoneEngine()
        let buddyEngine = BuddyRecommendationEngine()
        let correlationEngine = CorrelationEngine()
        let nudgeScheduler = SmartNudgeScheduler()
        let adviceComposer = AdviceComposer()

        // Step 1: HeartTrend assessment (initial pass without stress)
        let initialAssessment = trendEngine.assess(
            history: history,
            current: currentSnapshot,
            feedback: nil,
            stressScore: nil,
            readinessResult: nil
        )

        // Step 2: Stress
        let stressResult = stressEngine.computeStress(
            snapshot: currentSnapshot,
            recentHistory: history
        )

        // Step 3: Readiness
        let readinessResult = readinessEngine.compute(
            snapshot: currentSnapshot,
            stressScore: stressResult?.score,
            stressConfidence: stressResult?.confidence,
            recentHistory: history,
            consecutiveAlert: initialAssessment.consecutiveAlert
        )

        // Step 4: Re-run trend with stress + readiness for better accuracy
        let assessment = trendEngine.assess(
            history: history,
            current: currentSnapshot,
            feedback: nil,
            stressScore: stressResult?.score,
            readinessResult: readinessResult
        )

        // Step 5: Coaching report
        let coachingReport = history.count >= 3
            ? coachingEngine.generateReport(
                current: currentSnapshot,
                history: history,
                streakDays: dayIndex,
                readiness: readinessResult
            )
            : nil

        // Step 6: Bio age (if age available)
        let bioAgeResult: BioAgeResult? = {
            guard persona.age > 0 else { return nil }
            return bioAgeEngine.estimate(
                snapshot: currentSnapshot,
                chronologicalAge: persona.age,
                sex: persona.sex
            )
        }()

        // Step 7: Zone analysis
        let zoneAnalysis = zoneEngine.analyzeZoneDistribution(
            zoneMinutes: currentSnapshot.zoneMinutes
        )

        // Step 8: Buddy recommendations
        let buddyRecs = buddyEngine.recommend(
            assessment: assessment,
            stressResult: stressResult,
            readinessScore: readinessResult.map { Double($0.score) },
            current: currentSnapshot,
            history: history
        )

        // Step 9: Correlations
        let _ = correlationEngine.analyze(history: allSnapshots)

        // Step 10: Sleep patterns
        let _ = nudgeScheduler.learnSleepPatterns(from: allSnapshots)

        // Step 11: Compose AdviceState
        let adviceState = adviceComposer.compose(
            snapshot: currentSnapshot,
            assessment: assessment,
            stressResult: stressResult,
            readinessResult: readinessResult,
            zoneAnalysis: zoneAnalysis,
            config: config
        )

        // 3. Map through AdvicePresenter for all user-facing text
        return buildCapture(
            persona: persona,
            journey: journey,
            dayIndex: dayIndex,
            timestamp: timestamp,
            snapshot: currentSnapshot,
            assessment: assessment,
            stressResult: stressResult,
            readinessResult: readinessResult,
            coachingReport: coachingReport,
            buddyRecs: buddyRecs,
            adviceState: adviceState
        )
    }

    // MARK: - Build Capture from Engine Outputs

    private static func buildCapture(
        persona: PersonaBaseline,
        journey: JourneyScenario,
        dayIndex: Int,
        timestamp: TimeOfDayStamp,
        snapshot: HeartSnapshot,
        assessment: HeartAssessment,
        stressResult: StressResult?,
        readinessResult: ReadinessResult?,
        coachingReport: CoachingReport?,
        buddyRecs: [BuddyRecommendation],
        adviceState: AdviceState
    ) -> SuperReviewerCapture {
        // Dashboard page text via AdvicePresenter
        let heroMessage = AdvicePresenter.heroMessage(for: adviceState, snapshot: snapshot)
        let focusInsight = AdvicePresenter.focusInsight(for: adviceState)
        let recoveryNarrative = AdvicePresenter.recoveryNarrative(for: adviceState)
        let checkRecommendation = AdvicePresenter.checkRecommendation(
            for: adviceState,
            readinessScore: readinessResult?.score ?? 50,
            snapshot: snapshot
        )
        let positivityAnchor = AdvicePresenter.positivityAnchor(for: adviceState.positivityAnchorID)

        // Stress page text
        let stressGuidance: StressGuidanceSpec? = {
            guard let level = adviceState.stressGuidanceLevel else { return nil }
            return AdvicePresenter.stressGuidance(for: level)
        }()

        // Goals with nudge text
        let capturedGoals = adviceState.goals.map { goal in
            CapturedGoal(
                label: goal.label,
                target: goal.target,
                current: goal.current,
                nudgeText: AdvicePresenter.goalNudgeText(for: goal)
            )
        }

        // Nudges from assessment
        let capturedNudges: [CapturedNudge] = {
            var nudges: [CapturedNudge] = []
            let primary = assessment.dailyNudge
            nudges.append(CapturedNudge(
                category: String(describing: primary.category),
                title: primary.title,
                description: primary.description
            ))
            for nudge in assessment.dailyNudges where nudge.title != primary.title {
                nudges.append(CapturedNudge(
                    category: String(describing: nudge.category),
                    title: nudge.title,
                    description: nudge.description
                ))
            }
            return nudges
        }()

        // Buddy recommendations
        let capturedBuddyRecs: [CapturedBuddyRec] = buddyRecs.map { rec in
            CapturedBuddyRec(
                title: rec.title,
                message: rec.message,
                priority: String(describing: rec.priority)
            )
        }

        // Apply daily guidance budget (V-015): trim combined nudges+buddyRecs to fit budget.
        // Nudges are higher priority (more specific to today's metrics) so they get first slots.
        let budget = adviceState.dailyActionBudget
        let nudgeCap = min(capturedNudges.count, budget)
        let recCap = max(0, budget - nudgeCap)
        let capturedNudgesTrimmed = Array(capturedNudges.prefix(nudgeCap))
        let capturedBuddyRecsTrimmed = Array(capturedBuddyRecs.prefix(recCap))

        // Recovery trend label from week-over-week data
        let recoveryTrendLabel: String? = {
            guard let wow = assessment.weekOverWeekTrend else { return nil }
            return recoveryTrendText(for: wow.direction)
        }()

        // Recovery action (when trend is going up / not great)
        let recoveryAction: String? = {
            guard let wow = assessment.weekOverWeekTrend else { return nil }
            let diff = wow.currentWeekMean - wow.baselineMean
            guard diff > 0 else { return nil }
            if let stress = stressResult, stress.level == .elevated {
                return "Stress is high - an easy walk and early bedtime will help"
            }
            if diff > 3 {
                return "Rest day recommended - extra sleep tonight"
            }
            return "Consider a lighter day or an extra 30 min of sleep"
        }()

        return SuperReviewerCapture(
            // Identity
            personaName: persona.name,
            journeyID: journey.id,
            dayIndex: dayIndex,
            timeStampLabel: timestamp.label,
            timeStampHour: timestamp.hour,

            // Metrics context
            sleepHours: snapshot.sleepHours,
            rhr: snapshot.restingHeartRate,
            hrv: snapshot.hrvSDNN,
            steps: snapshot.steps,
            readinessScore: readinessResult?.score,
            stressScore: stressResult?.score,
            stressLevel: stressResult.map { String(describing: $0.level) },

            // Dashboard page
            greetingText: timestamp.expectedGreeting,
            buddyMood: buddyMoodEmoji(for: adviceState.buddyMoodCategory),
            heroMessage: heroMessage,
            focusInsight: focusInsight,
            checkBadge: adviceState.checkBadgeID,
            checkRecommendation: checkRecommendation,
            recoveryNarrative: recoveryNarrative,
            recoveryTrendLabel: recoveryTrendLabel,
            recoveryAction: recoveryAction,
            goals: capturedGoals,
            positivityAnchor: positivityAnchor,

            // Stress page
            stressLevelLabel: stressResult.map { String(describing: $0.level) },
            friendlyMessage: stressResult?.description,
            guidanceHeadline: stressGuidance?.headline,
            guidanceDetail: stressGuidance?.detail,
            guidanceActions: stressGuidance?.actions,

            // Nudges
            nudges: capturedNudgesTrimmed,

            // Buddy recommendations
            buddyRecs: capturedBuddyRecsTrimmed,

            // Coaching
            coachingHeroMessage: coachingReport?.heroMessage,
            coachingInsights: coachingReport?.insights.map { $0.message } ?? []
        )
    }

    // MARK: - Batch Execution

    /// Runs the full Super Reviewer suite for a given configuration.
    static func runBatch(config: SuperReviewerRunConfig) -> SuperReviewerRunResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        var captures: [SuperReviewerCapture] = []
        let failures: [SuperReviewerRunResult.CaptureFailure] = []

        for persona in config.personas {
            for journey in config.journeys {
                for dayIndex in 0..<journey.dayCount {
                    for timestamp in config.timestamps {
                        let cap = capture(
                            persona: persona,
                            journey: journey,
                            dayIndex: dayIndex,
                            timestamp: timestamp
                        )
                        captures.append(cap)
                    }
                }
            }
        }

        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

        // Write JSON if configured
        if config.captureJSON {
            writeCapturesToDisk(captures: captures, directory: config.outputDirectory)
        }

        return SuperReviewerRunResult(
            captures: captures,
            failures: failures,
            totalDurationMs: elapsed
        )
    }

    // MARK: - JSON Serialization

    static func writeCapturesToDisk(captures: [SuperReviewerCapture], directory: String) {
        let fm = FileManager.default
        // Write to Tests/SuperReviewer/CaptureOutput/ so outputs live in the project,
        // not the volatile simulator tmp dir. The CaptureOutput/ folder is .gitignored.
        let sourceDir = URL(fileURLWithPath: #file).deletingLastPathComponent()
        let baseURL = sourceDir.appendingPathComponent("CaptureOutput").appendingPathComponent(directory)
        try? fm.createDirectory(at: baseURL, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        // Write individual captures grouped by persona + journey
        var grouped: [String: [SuperReviewerCapture]] = [:]
        for cap in captures {
            let key = "\(cap.personaName)_\(cap.journeyID)"
            grouped[key, default: []].append(cap)
        }

        for (key, caps) in grouped {
            let fileURL = baseURL.appendingPathComponent("\(key).json")
            if let data = try? encoder.encode(caps) {
                try? data.write(to: fileURL)
            }
        }

        // Write summary manifest
        let manifest = CaptureManifest(
            totalCaptures: captures.count,
            personas: Array(Set(captures.map(\.personaName))).sorted(),
            journeys: Array(Set(captures.map(\.journeyID))).sorted(),
            timestamps: Array(Set(captures.map(\.timeStampLabel))).sorted(),
            generatedAt: ISO8601DateFormatter().string(from: Date())
        )
        if let data = try? encoder.encode(manifest) {
            let manifestURL = baseURL.appendingPathComponent("manifest.json")
            try? data.write(to: manifestURL)
        }

        print("[SuperReviewer] Wrote \(captures.count) captures to \(baseURL.path)")
    }

    /// Serialize a single capture to JSON string for LLM judge input.
    static func captureToJSON(_ capture: SuperReviewerCapture) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(capture),
              let json = String(data: data, encoding: .utf8) else {
            return "{\"error\": \"serialization_failed\"}"
        }
        return json
    }

    // MARK: - Helpers

    private static func buddyMoodEmoji(for mood: BuddyMoodCategory) -> String {
        switch mood {
        case .celebrating:  return "🎉"
        case .encouraging:  return "💪"
        case .concerned:    return "🫂"
        case .resting:      return "😴"
        case .neutral:      return "👋"
        }
    }

    private static func recoveryTrendText(for direction: WeeklyTrendDirection) -> String {
        switch direction {
        case .significantImprovement: return "Great"
        case .improving:             return "Improving"
        case .stable:                return "Steady"
        case .elevated:              return "Elevated"
        case .significantElevation:  return "Needs rest"
        }
    }
}

// MARK: - Manifest

struct CaptureManifest: Codable {
    let totalCaptures: Int
    let personas: [String]
    let journeys: [String]
    let timestamps: [String]
    let generatedAt: String
}
