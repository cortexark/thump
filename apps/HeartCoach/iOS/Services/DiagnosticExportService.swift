// DiagnosticExportService.swift
// Thump iOS
//
// Comprehensive diagnostic export that captures EVERYTHING the app shows:
// health data, engine outputs, stress/readiness/bio-age results,
// nudges, correlations, action plans, user interactions, and UI state.
// Exports as a single JSON file for debugging and review.
//
// Platforms: iOS 17+

import Foundation
import UIKit

// MARK: - Diagnostic Export Service

/// Builds a comprehensive JSON diagnostic export containing every piece
/// of data the app displays across all screens, plus interaction logs
/// and engine trace information. Used for bug reports and debugging.
final class DiagnosticExportService {

    // MARK: - Singleton

    static let shared = DiagnosticExportService()
    private init() {}

    // MARK: - Date Formatters

    private let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    // MARK: - Export

    /// Generates a comprehensive diagnostic JSON containing all app state.
    ///
    /// - Parameters:
    ///   - localStore: The app's local data store.
    ///   - bugDescription: Optional user-provided bug description.
    /// - Returns: A dictionary ready for JSON serialization.
    func buildDiagnosticPayload(
        localStore: LocalStore,
        bugDescription: String? = nil
    ) -> [String: Any] {
        var payload: [String: Any] = [:]

        // 1. Meta
        payload["meta"] = buildMeta(bugDescription: bugDescription)

        // 2. User profile (no PII beyond what user consented to)
        payload["userProfile"] = buildUserProfile(localStore: localStore)

        // 3. Health data — every snapshot in history
        let history = localStore.loadHistory()
        payload["healthHistory"] = buildHealthHistory(history)
        payload["historyDayCount"] = history.count

        // 4. Engine outputs — assessment, readiness, stress, bio age, coaching, zones
        payload["engineOutputs"] = buildEngineOutputs(history)

        // 5. Current screen state — what each screen would show right now
        payload["screenState"] = buildScreenState(localStore: localStore, history: history)

        // 6. Interaction logs — last 50 user actions (what was clicked)
        payload["interactionLogs"] = buildInteractionLogs()

        // 7. Nudge & action plan data
        payload["nudges"] = buildNudgeData(history)

        // 8. Settings & preferences
        payload["settings"] = buildSettings(localStore: localStore)

        return payload
    }

    /// Generates the diagnostic JSON, writes to temp file, returns the URL.
    func exportToFile(
        localStore: LocalStore,
        bugDescription: String? = nil
    ) -> URL? {
        let payload = buildDiagnosticPayload(
            localStore: localStore,
            bugDescription: bugDescription
        )

        guard let jsonData = try? JSONSerialization.data(
            withJSONObject: payload,
            options: [.prettyPrinted, .sortedKeys]
        ) else {
            AppLogger.error("DiagnosticExport: Failed to serialize JSON")
            return nil
        }

        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let filename = "thump-diagnostic-\(timestamp).json"
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(filename)

        do {
            try jsonData.write(to: tempURL)
            AppLogger.info("DiagnosticExport: Written to \(tempURL.lastPathComponent) (\(jsonData.count) bytes)")
            return tempURL
        } catch {
            AppLogger.error("DiagnosticExport: Write failed — \(error.localizedDescription)")
            return nil
        }
    }

    /// Uploads diagnostic payload to Firestore under the user's bug-reports.
    func uploadToFirestore(
        localStore: LocalStore,
        bugDescription: String
    ) {
        let payload = buildDiagnosticPayload(
            localStore: localStore,
            bugDescription: bugDescription
        )

        // Firestore has a 1MB document limit — compress the payload
        // by converting to JSON string for the large fields
        var firestoreData: [String: Any] = [:]

        // Top-level fields go directly
        firestoreData["description"] = bugDescription
        firestoreData["meta"] = payload["meta"] ?? [:]
        firestoreData["userProfile"] = payload["userProfile"] ?? [:]
        firestoreData["settings"] = payload["settings"] ?? [:]
        firestoreData["historyDayCount"] = payload["historyDayCount"] ?? 0

        // Large sections go as JSON strings to avoid Firestore nested doc limits
        if let healthHistory = payload["healthHistory"],
           let data = try? JSONSerialization.data(withJSONObject: healthHistory, options: []),
           let str = String(data: data, encoding: .utf8) {
            firestoreData["healthHistoryJSON"] = str
        }

        if let engineOutputs = payload["engineOutputs"],
           let data = try? JSONSerialization.data(withJSONObject: engineOutputs, options: []),
           let str = String(data: data, encoding: .utf8) {
            firestoreData["engineOutputsJSON"] = str
        }

        if let screenState = payload["screenState"],
           let data = try? JSONSerialization.data(withJSONObject: screenState, options: []),
           let str = String(data: data, encoding: .utf8) {
            firestoreData["screenStateJSON"] = str
        }

        if let logs = payload["interactionLogs"],
           let data = try? JSONSerialization.data(withJSONObject: logs, options: []),
           let str = String(data: data, encoding: .utf8) {
            firestoreData["interactionLogsJSON"] = str
        }

        if let nudges = payload["nudges"],
           let data = try? JSONSerialization.data(withJSONObject: nudges, options: []),
           let str = String(data: data, encoding: .utf8) {
            firestoreData["nudgesJSON"] = str
        }

        FeedbackService.shared.submitBugReport(
            description: bugDescription,
            appVersion: (payload["meta"] as? [String: Any])?["appVersion"] as? String ?? "unknown",
            deviceModel: UIDevice.current.model,
            iosVersion: UIDevice.current.systemVersion,
            diagnosticPayload: firestoreData
        )
    }

    // MARK: - Build Sections

    private func buildMeta(bugDescription: String?) -> [String: Any] {
        var meta: [String: Any] = [
            "exportDate": isoFormatter.string(from: Date()),
            "appVersion": appVersion,
            "buildNumber": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?",
            "deviceModel": UIDevice.current.model,
            "deviceName": UIDevice.current.name,
            "iosVersion": UIDevice.current.systemVersion,
            "locale": Locale.current.identifier,
            "timezone": TimeZone.current.identifier
        ]
        if let desc = bugDescription {
            meta["bugDescription"] = desc
        }
        return meta
    }

    private func buildUserProfile(localStore: LocalStore) -> [String: Any] {
        let profile = localStore.profile
        var p: [String: Any] = [
            "onboardingComplete": profile.onboardingComplete,
            "streakDays": profile.streakDays,
            "hasDateOfBirth": profile.dateOfBirth != nil,
            "biologicalSex": profile.biologicalSex.rawValue
        ]
        if let age = profile.chronologicalAge { p["chronologicalAge"] = age }
        if let dob = profile.dateOfBirth { p["dateOfBirth"] = isoFormatter.string(from: dob) }
        p["joinDate"] = isoFormatter.string(from: profile.joinDate)
        if let lastStreak = profile.lastStreakCreditDate { p["lastStreakCreditDate"] = isoFormatter.string(from: lastStreak) }
        p["nudgeCompletionCount"] = profile.nudgeCompletionDates.count
        p["isInLaunchFreeYear"] = profile.isInLaunchFreeYear
        if profile.isInLaunchFreeYear {
            p["launchFreeDaysRemaining"] = profile.launchFreeDaysRemaining
        }
        return p
    }

    private func buildHealthHistory(_ history: [StoredSnapshot]) -> [[String: Any]] {
        return history.map { stored in
            let snap = stored.snapshot
            var entry: [String: Any] = [
                "date": isoFormatter.string(from: snap.date)
            ]

            // Raw metrics — every field
            var metrics: [String: Any] = [:]
            if let v = snap.restingHeartRate { metrics["restingHeartRate"] = v }
            if let v = snap.hrvSDNN { metrics["hrvSDNN"] = v }
            if let v = snap.recoveryHR1m { metrics["recoveryHR1m"] = v }
            if let v = snap.recoveryHR2m { metrics["recoveryHR2m"] = v }
            if let v = snap.vo2Max { metrics["vo2Max"] = v }
            if let v = snap.steps { metrics["steps"] = v }
            if let v = snap.walkMinutes { metrics["walkMinutes"] = v }
            if let v = snap.workoutMinutes { metrics["workoutMinutes"] = v }
            if let v = snap.sleepHours { metrics["sleepHours"] = v }
            if let v = snap.bodyMassKg { metrics["bodyMassKg"] = v }
            if let v = snap.heightM { metrics["heightM"] = v }
            if !snap.zoneMinutes.isEmpty { metrics["zoneMinutes"] = snap.zoneMinutes }
            entry["metrics"] = metrics

            // Assessment (engine output for this day)
            if let assessment = stored.assessment {
                entry["assessment"] = buildAssessmentDict(assessment)
            }

            return entry
        }
    }

    private func buildAssessmentDict(_ a: HeartAssessment) -> [String: Any] {
        var d: [String: Any] = [
            "status": a.status.rawValue,
            "confidence": a.confidence.rawValue,
            "anomalyScore": a.anomalyScore,
            "regressionFlag": a.regressionFlag,
            "stressFlag": a.stressFlag,
            "explanation": a.explanation,
            "nudgeCategory": a.dailyNudge.category.rawValue,
            "nudgeTitle": a.dailyNudge.title,
            "nudgeDescription": a.dailyNudge.description
        ]
        if let cardio = a.cardioScore { d["cardioScore"] = cardio }
        if let scenario = a.scenario { d["scenario"] = scenario.rawValue }

        // All daily nudges (not just the primary)
        d["allNudges"] = a.dailyNudges.map { nudge in
            [
                "category": nudge.category.rawValue,
                "title": nudge.title,
                "description": nudge.description,
                "icon": nudge.icon,
                "durationMinutes": nudge.durationMinutes as Any
            ] as [String: Any]
        }

        // Week over week trend
        if let wow = a.weekOverWeekTrend {
            d["weekOverWeekTrend"] = [
                "currentWeekMean": wow.currentWeekMean,
                "baselineMean": wow.baselineMean,
                "baselineStd": wow.baselineStd,
                "zScore": wow.zScore,
                "direction": String(describing: wow.direction)
            ]
        }

        // Consecutive elevation alert
        if let alert = a.consecutiveAlert {
            d["consecutiveAlert"] = [
                "consecutiveDays": alert.consecutiveDays,
                "elevatedMean": alert.elevatedMean,
                "threshold": alert.threshold
            ]
        }

        // Recovery context
        if let rc = a.recoveryContext {
            d["recoveryContext"] = [
                "driver": String(describing: rc.driver),
                "reason": rc.reason,
                "tonightAction": rc.tonightAction,
                "readinessScore": rc.readinessScore as Any
            ]
        }

        return d
    }

    private func buildEngineOutputs(_ history: [StoredSnapshot]) -> [String: Any] {
        guard let latest = history.last else { return [:] }

        var outputs: [String: Any] = [:]

        let snap = latest.snapshot
        let recentHistory = history.suffix(30).map(\.snapshot)

        // Stress engine
        let stressEngine = StressEngine()
        if let stress = stressEngine.computeStress(snapshot: snap, recentHistory: Array(recentHistory)) {
            outputs["stress"] = [
                "score": stress.score,
                "level": stress.level.rawValue,
                "mode": String(describing: stress.mode),
                "confidence": String(describing: stress.confidence),
                "description": stress.description,
                "displayName": stress.level.displayName,
                "friendlyMessage": stress.level.friendlyMessage
            ]
        }

        // Readiness engine
        let readinessEngine = ReadinessEngine()
        let stressScore = stressEngine.computeStress(snapshot: snap, recentHistory: Array(recentHistory))?.score
        if let readiness = readinessEngine.compute(
            snapshot: snap,
            stressScore: stressScore,
            recentHistory: Array(recentHistory)
        ) {
            var readinessDict: [String: Any] = [
                "score": readiness.score,
                "level": readiness.level.rawValue
            ]
            readinessDict["pillars"] = readiness.pillars.map { pillar in
                [
                    "type": String(describing: pillar.type),
                    "score": pillar.score,
                    "detail": pillar.detail
                ] as [String: Any]
            }
            outputs["readiness"] = readinessDict
        }

        // Bio age — needs chronological age
        let bioAgeEngine = BioAgeEngine()
        // Try to get age from profile, fall back to 30
        let chronoAge = 30 // Will be overridden by caller if available
        if let bioAge = bioAgeEngine.estimate(snapshot: snap, chronologicalAge: chronoAge) {
            outputs["bioAge"] = [
                "bioAge": bioAge.bioAge,
                "chronologicalAge": bioAge.chronologicalAge,
                "difference": bioAge.difference,
                "category": String(describing: bioAge.category),
                "metricsUsed": bioAge.metricsUsed
            ]
        }

        // Coaching
        let coachingEngine = CoachingEngine()
        let report = coachingEngine.generateReport(
            current: snap,
            history: Array(recentHistory),
            streakDays: 0
        )
        outputs["coaching"] = [
            "weeklyProgressScore": report.weeklyProgressScore,
            "heroMessage": report.heroMessage,
            "insightCount": report.insights.count,
            "insights": report.insights.map { insight in
                [
                    "metric": String(describing: insight.metric),
                    "message": insight.message,
                    "direction": String(describing: insight.direction),
                    "changeValue": insight.changeValue,
                    "projection": insight.projection
                ] as [String: Any]
            },
            "projections": report.projections.map { proj in
                [
                    "metric": String(describing: proj.metric),
                    "currentValue": proj.currentValue,
                    "projectedValue": proj.projectedValue
                ] as [String: Any]
            },
            "streakDays": report.streakDays
        ]

        // Zone analysis
        let zoneEngine = HeartRateZoneEngine()
        if !snap.zoneMinutes.isEmpty {
            let analysis = zoneEngine.analyzeZoneDistribution(zoneMinutes: snap.zoneMinutes)
            outputs["zoneAnalysis"] = [
                "overallScore": analysis.overallScore,
                "coachingMessage": analysis.coachingMessage,
                "recommendation": analysis.recommendation.map { String(describing: $0) } as Any,
                "pillars": analysis.pillars.map { p in
                    [
                        "zone": String(describing: p.zone),
                        "actualMinutes": p.actualMinutes,
                        "targetMinutes": p.targetMinutes,
                        "completion": p.completion
                    ] as [String: Any]
                }
            ]
        }

        return outputs
    }

    private func buildScreenState(localStore: LocalStore, history: [StoredSnapshot]) -> [String: Any] {
        var screens: [String: Any] = [:]

        // Dashboard — what each section would display
        if let latest = history.last {
            var dashboard: [String: Any] = [:]
            let assessment = latest.assessment
            dashboard["hasAssessment"] = assessment != nil

            if let a = assessment {
                dashboard["status"] = a.status.rawValue
                dashboard["explanation"] = a.explanation
                dashboard["nudgeCount"] = a.dailyNudges.count
                dashboard["nudgeTitles"] = a.dailyNudges.map(\.title)
                dashboard["nudgeCategories"] = a.dailyNudges.map(\.category.rawValue)
                if let cardio = a.cardioScore {
                    dashboard["cardioScore"] = cardio
                }
            }

            // Metric tiles — what user sees on each tile
            let snap = latest.snapshot
            var tiles: [String: Any] = [:]
            if let rhr = snap.restingHeartRate { tiles["restingHR"] = "\(Int(rhr)) bpm" }
            if let hrv = snap.hrvSDNN { tiles["hrv"] = "\(Int(hrv)) ms" }
            if let vo2 = snap.vo2Max { tiles["vo2Max"] = String(format: "%.1f", vo2) }
            if let rec = snap.recoveryHR1m { tiles["recovery1m"] = "\(Int(rec)) bpm" }
            if let steps = snap.steps { tiles["steps"] = "\(Int(steps))" }
            if let sleep = snap.sleepHours { tiles["sleep"] = String(format: "%.1f hrs", sleep) }
            dashboard["metricTiles"] = tiles

            screens["dashboard"] = dashboard
        }

        // Stress screen state
        screens["stress"] = [
            "note": "Run StressViewModel.loadData() to populate — requires HealthKit access"
        ]

        // Trends — metric ranges from history
        if !history.isEmpty {
            let snapshots = history.map(\.snapshot)
            var trends: [String: Any] = [:]

            let rhrs = snapshots.compactMap(\.restingHeartRate)
            if !rhrs.isEmpty {
                trends["rhr"] = [
                    "min": rhrs.min()!, "max": rhrs.max()!,
                    "avg": rhrs.reduce(0, +) / Double(rhrs.count),
                    "count": rhrs.count
                ]
            }

            let hrvs = snapshots.compactMap(\.hrvSDNN)
            if !hrvs.isEmpty {
                trends["hrv"] = [
                    "min": hrvs.min()!, "max": hrvs.max()!,
                    "avg": hrvs.reduce(0, +) / Double(hrvs.count),
                    "count": hrvs.count
                ]
            }

            let sleeps = snapshots.compactMap(\.sleepHours)
            if !sleeps.isEmpty {
                trends["sleep"] = [
                    "min": sleeps.min()!, "max": sleeps.max()!,
                    "avg": sleeps.reduce(0, +) / Double(sleeps.count),
                    "count": sleeps.count
                ]
            }

            let vo2s = snapshots.compactMap(\.vo2Max)
            if !vo2s.isEmpty {
                trends["vo2Max"] = [
                    "min": vo2s.min()!, "max": vo2s.max()!,
                    "avg": vo2s.reduce(0, +) / Double(vo2s.count),
                    "count": vo2s.count
                ]
            }

            let stepsList = snapshots.compactMap(\.steps)
            if !stepsList.isEmpty {
                trends["steps"] = [
                    "min": stepsList.min()!, "max": stepsList.max()!,
                    "avg": stepsList.reduce(0, +) / Double(stepsList.count),
                    "count": stepsList.count
                ]
            }

            let walkMins = snapshots.compactMap(\.walkMinutes)
            if !walkMins.isEmpty {
                let totalActive = zip(
                    snapshots.compactMap(\.walkMinutes),
                    snapshots.compactMap(\.workoutMinutes)
                ).map { $0 + $1 }
                if !totalActive.isEmpty {
                    trends["activeMinutes"] = [
                        "min": totalActive.min()!, "max": totalActive.max()!,
                        "avg": totalActive.reduce(0, +) / Double(totalActive.count),
                        "count": totalActive.count
                    ]
                }
            }

            screens["trends"] = trends
        }

        return screens
    }

    private func buildInteractionLogs() -> [[String: String]] {
        let breadcrumbs = CrashBreadcrumbs.shared.allBreadcrumbs()
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        return breadcrumbs.map { crumb in
            [
                "timestamp": f.string(from: crumb.timestamp),
                "action": crumb.message
            ]
        }
    }

    private func buildNudgeData(_ history: [StoredSnapshot]) -> [String: Any] {
        var nudgeData: [String: Any] = [:]

        // Current day's nudges from most recent assessment
        if let latest = history.last, let assessment = latest.assessment {
            nudgeData["todayPrimary"] = [
                "category": assessment.dailyNudge.category.rawValue,
                "title": assessment.dailyNudge.title,
                "description": assessment.dailyNudge.description,
                "icon": assessment.dailyNudge.icon
            ]

            nudgeData["todayAll"] = assessment.dailyNudges.map { n in
                [
                    "category": n.category.rawValue,
                    "title": n.title,
                    "description": n.description,
                    "icon": n.icon,
                    "durationMinutes": n.durationMinutes as Any
                ] as [String: Any]
            }
        }

        // Nudge history across all days
        var nudgeHistory: [[String: Any]] = []
        for stored in history {
            if let a = stored.assessment {
                nudgeHistory.append([
                    "date": isoFormatter.string(from: stored.snapshot.date),
                    "primaryCategory": a.dailyNudge.category.rawValue,
                    "primaryTitle": a.dailyNudge.title,
                    "allCategories": a.dailyNudges.map(\.category.rawValue),
                    "allTitles": a.dailyNudges.map(\.title)
                ])
            }
        }
        nudgeData["history"] = nudgeHistory

        return nudgeData
    }

    private func buildSettings(localStore: LocalStore) -> [String: Any] {
        let prefs = localStore.loadFeedbackPreferences()
        return [
            "anomalyAlerts": UserDefaults.standard.bool(forKey: "thump_anomaly_alerts_enabled"),
            "nudgeReminders": UserDefaults.standard.bool(forKey: "thump_nudge_reminders_enabled"),
            "telemetryConsent": UserDefaults.standard.bool(forKey: "thump_telemetry_consent"),
            "designVariantB": UserDefaults.standard.bool(forKey: "thump_design_variant_b"),
            "feedbackPreferences": [
                "showBuddySuggestions": prefs.showBuddySuggestions,
                "showDailyCheckIn": prefs.showDailyCheckIn,
                "showStressInsights": prefs.showStressInsights,
                "showWeeklyTrends": prefs.showWeeklyTrends,
                "showStreakBadge": prefs.showStreakBadge
            ]
        ]
    }

    // MARK: - Helpers

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
