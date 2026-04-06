// SettingsView.swift
// Thump iOS
//
// App settings organized into sections: Profile, Subscription, Notifications,
// Data, and About. Provides access to the paywall, notification toggles,
// data export, and a legally required health disclaimer.
//
// Platforms: iOS 17+

import SwiftUI

// MARK: - SettingsView

/// Settings screen with profile info, subscription management, notifications,
/// data export, and about/disclaimer sections.
struct SettingsView: View {

    // MARK: - Environment

    @EnvironmentObject var localStore: LocalStore

    // MARK: - State

    /// Whether anomaly alert notifications are enabled.
    @AppStorage("thump_anomaly_alerts_enabled")
    private var anomalyAlertsEnabled: Bool = true

    /// Whether daily nudge reminder notifications are enabled.
    @AppStorage("thump_nudge_reminders_enabled")
    private var nudgeRemindersEnabled: Bool = true

    /// Whether anonymous engine telemetry is enabled.
    @AppStorage("thump_telemetry_consent")
    private var telemetryConsent: Bool = false

    /// Controls presentation of the paywall sheet.
    @State private var showPaywall: Bool = false

    /// Controls presentation of the export confirmation alert.
    @State private var showExportConfirmation: Bool = false

    /// Controls presentation of the Terms of Service sheet.
    @State private var showTermsOfService: Bool = false

    /// Controls presentation of the Privacy Policy sheet.
    @State private var showPrivacyPolicy: Bool = false

    /// Controls presentation of the bug report sheet.
    @State private var showBugReport: Bool = false

    /// Bug report text.
    @State private var bugReportText: String = ""

    /// Whether bug report was submitted.
    @State private var bugReportSubmitted: Bool = false

    /// Whether to include a screenshot with the bug report.
    @State private var includeScreenshot: Bool = true

    /// Whether to include health metrics with the bug report (explicit consent).
    @State private var includeHealthData: Bool = false

    /// Controls presentation of the account deletion confirmation alert.
    @State private var showDeleteAccount: Bool = false

    /// Whether account deletion is in progress.
    @State private var isDeletingAccount: Bool = false

    /// Controls presentation of the feature request sheet.
    @State private var showFeatureRequest: Bool = false

    /// Feature request text.
    @State private var featureRequestText: String = ""

    /// Whether feature request was submitted.
    @State private var featureRequestSubmitted: Bool = false

    /// Controls presentation of the debug trace share sheet.
    @State private var showDebugTraceConfirmation: Bool = false

    /// Feedback preferences.
    @State private var feedbackPrefs: FeedbackPreferences = FeedbackPreferences()

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                profileSection
                subscriptionSection
                designSection
                feedbackPreferencesSection
                notificationsSection
                analyticsSection
                dataSection
                bugReportSection
                aboutSection
                disclaimerSection
            }
            .accessibilityIdentifier("settings_screen")
            .onAppear {
                InteractionLog.pageView("Settings")
                feedbackPrefs = localStore.loadFeedbackPreferences()
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }

    // MARK: - Profile Section

    private var profileSection: some View {
        Section {
            HStack(spacing: 14) {
                // Avatar placeholder
                ZStack {
                    Circle()
                        .fill(Color.pink.opacity(0.15))
                        .frame(width: 50, height: 50)

                    Text(initials)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.pink)
                }

                VStack(alignment: .leading, spacing: 4) {
                    TextField(
                        "Your name",
                        text: Binding(
                            get: { localStore.profile.displayName },
                            set: { newName in
                                // Strip newlines to keep name single-line
                                let cleaned = newName.replacingOccurrences(of: "\n", with: " ")
                                localStore.profile.displayName = cleaned
                                localStore.saveProfile()
                            }
                        ),
                        axis: .vertical
                    )
                    .lineLimit(1...2)
                    .font(.headline)
                    .accessibilityIdentifier("settings_name")

                    Text("Joined \(formattedJoinDate)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            HStack {
                Label("Current Streak", systemImage: "flame.fill")
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(localStore.profile.streakDays) days")
                    .foregroundStyle(.secondary)
            }

            // Date of birth for Bio Age
            DatePicker(
                selection: Binding(
                    get: {
                        localStore.profile.dateOfBirth ?? Calendar.current.date(
                            byAdding: .year, value: -30, to: Date()
                        ) ?? Date()
                    },
                    set: { newDate in
                        localStore.profile.dateOfBirth = newDate
                        localStore.saveProfile()
                    }
                ),
                in: ...(Calendar.current.date(byAdding: .year, value: -13, to: Date()) ?? Date()),
                displayedComponents: .date
            ) {
                Label("Date of Birth", systemImage: "birthday.cake.fill")
                    .foregroundStyle(.primary)
            }
            .accessibilityIdentifier("settings_dob")
            .onChange(of: localStore.profile.dateOfBirth) { _, _ in
                InteractionLog.log(.datePickerChange, element: "dob_picker", page: "Settings", details: "changed")
            }

            // Biological sex for metric accuracy
            Picker(selection: Binding(
                get: { localStore.profile.biologicalSex },
                set: { newValue in
                    localStore.profile.biologicalSex = newValue
                    localStore.saveProfile()
                }
            )) {
                ForEach(BiologicalSex.allCases, id: \.self) { sex in
                    Text(sex.displayLabel).tag(sex)
                }
            } label: {
                Label("Biological Sex", systemImage: "person.fill")
                    .foregroundStyle(.primary)
            }

            if let age = localStore.profile.chronologicalAge {
                HStack {
                    Label("Bio Age", systemImage: "heart.text.square.fill")
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("Enabled (age \(age))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Profile")
        } footer: {
            Text("Your date of birth and biological sex are used for accurate Bio Age and typical ranges for your age and sex. All data stays on your device.")
        }
    }

    // MARK: - Subscription Section

    private var subscriptionSection: some View {
        Section {
            if localStore.profile.isInLaunchFreeYear {
                // Launch free year — show status instead of paywall
                HStack {
                    Label("Current Plan", systemImage: "gift.fill")
                    Spacer()
                    Text("Coach (Free)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.green)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.12), in: Capsule())
                }

                HStack {
                    Label("Free Access", systemImage: "clock.fill")
                    Spacer()
                    Text("\(localStore.profile.launchFreeDaysRemaining) days remaining")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text("All features are unlocked for your first year. No payment required.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                // Phase 2: Paywall paused — show beta messaging
                HStack {
                    Label("Current Plan", systemImage: "gift.fill")
                    Spacer()
                    Text("All Features (Beta)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.green)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.12), in: Capsule())
                }

                Text("All features are currently free during the beta period. Subscription plans will be available in a future update.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Subscription")
        }
    }

    // MARK: - Design Section

    @AppStorage("thump_design_variant_b") private var useDesignB: Bool = false

    private var designSection: some View {
        Section {
            Toggle(isOn: $useDesignB) {
                Label("Design B (Beta)", systemImage: "paintbrush.fill")
            }
            .tint(.pink)
        } header: {
            Text("Design Experiment")
        } footer: {
            Text(useDesignB
                 ? "You're seeing Design B — a refreshed card layout with enhanced visuals."
                 : "You're seeing Design A — the standard layout.")
        }
    }

    // MARK: - Notifications Section

    private var notificationsSection: some View {
        Section {
            Toggle(isOn: $anomalyAlertsEnabled) {
                Label("Unusual Pattern Alerts", systemImage: "exclamationmark.triangle.fill")
            }
            .tint(.pink)
            .onChange(of: anomalyAlertsEnabled) { _, newValue in
                InteractionLog.log(.toggleChange, element: "anomaly_alerts_toggle", page: "Settings", details: "enabled=\(newValue)")
                if !newValue {
                    // Cancel all pending anomaly notifications immediately
                    UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                        let anomalyIDs = requests.map(\.identifier).filter { $0.hasPrefix("com.thump.anomaly.") }
                        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: anomalyIDs)
                    }
                }
            }

            Toggle(isOn: $nudgeRemindersEnabled) {
                Label("Nudge Reminders", systemImage: "bell.badge.fill")
            }
            .tint(.pink)
            .onChange(of: nudgeRemindersEnabled) { _, newValue in
                InteractionLog.log(.toggleChange, element: "nudge_reminders_toggle", page: "Settings", details: "enabled=\(newValue)")
                if !newValue {
                    // Cancel all pending nudge notifications immediately
                    UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                        let nudgeIDs = requests.map(\.identifier).filter { $0.hasPrefix("com.thump.nudge.") }
                        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: nudgeIDs)
                    }
                }
            }
        } header: {
            Text("Notifications")
        } footer: {
            Text(
                "Anomaly alerts notify you when your numbers look different from your usual range. "
                    + "Nudge reminders encourage daily engagement."
            )
        }
    }

    // MARK: - Analytics Section

    private var analyticsSection: some View {
        Section {
            Toggle(isOn: $telemetryConsent) {
                Label("Share Engine Insights", systemImage: "chart.bar.xaxis.ascending")
            }
            .tint(.pink)
            .onChange(of: telemetryConsent) { _, newValue in
                InteractionLog.log(.toggleChange, element: "telemetry_consent_toggle", page: "Settings", details: "enabled=\(newValue)")
            }
        } header: {
            Text("Analytics")
        } footer: {
            Text("Help improve Thump by sharing anonymized engine scores and timing data. No raw health data (heart rate, HRV, steps, etc.) is ever shared.")
        }
    }

    // MARK: - Feedback Preferences Section

    private var feedbackPreferencesSection: some View {
        Section {
            Toggle(isOn: $feedbackPrefs.showBuddySuggestions) {
                Label("Buddy Suggestions", systemImage: "lightbulb.fill")
            }
            .tint(.pink)
            .onChange(of: feedbackPrefs.showBuddySuggestions) { _, newValue in
                localStore.saveFeedbackPreferences(feedbackPrefs)
                InteractionLog.log(.toggleChange, element: "buddy_suggestions_toggle", page: "Settings", details: "enabled=\(newValue)")
            }

            Toggle(isOn: $feedbackPrefs.showDailyCheckIn) {
                Label("Daily Check-In", systemImage: "face.smiling")
            }
            .tint(.pink)
            .onChange(of: feedbackPrefs.showDailyCheckIn) { _, newValue in
                localStore.saveFeedbackPreferences(feedbackPrefs)
                InteractionLog.log(.toggleChange, element: "daily_checkin_toggle", page: "Settings", details: "enabled=\(newValue)")
            }

            Toggle(isOn: $feedbackPrefs.showStressInsights) {
                Label("Stress Insights", systemImage: "brain.head.profile")
            }
            .tint(.pink)
            .onChange(of: feedbackPrefs.showStressInsights) { _, newValue in
                localStore.saveFeedbackPreferences(feedbackPrefs)
                InteractionLog.log(.toggleChange, element: "stress_insights_toggle", page: "Settings", details: "enabled=\(newValue)")
            }

            Toggle(isOn: $feedbackPrefs.showWeeklyTrends) {
                Label("Weekly Trends", systemImage: "chart.line.uptrend.xyaxis")
            }
            .tint(.pink)
            .onChange(of: feedbackPrefs.showWeeklyTrends) { _, newValue in
                localStore.saveFeedbackPreferences(feedbackPrefs)
                InteractionLog.log(.toggleChange, element: "weekly_trends_toggle", page: "Settings", details: "enabled=\(newValue)")
            }

            Toggle(isOn: $feedbackPrefs.showStreakBadge) {
                Label("Streak Badge", systemImage: "flame.fill")
            }
            .tint(.pink)
            .onChange(of: feedbackPrefs.showStreakBadge) { _, newValue in
                localStore.saveFeedbackPreferences(feedbackPrefs)
                InteractionLog.log(.toggleChange, element: "streak_badge_toggle", page: "Settings", details: "enabled=\(newValue)")
            }
        } header: {
            Text("What You Want to See")
        } footer: {
            Text("Choose which cards and insights appear on your dashboard.")
        }
    }

    // MARK: - Bug Report Section

    private var bugReportSection: some View {
        Section {
            Button {
                InteractionLog.log(.buttonTap, element: "bug_report_button", page: "Settings")
                showBugReport = true
            } label: {
                Label("Report a Bug", systemImage: "ant.fill")
            }
            .accessibilityIdentifier("settings_bug_report_button")
            .sheet(isPresented: $showBugReport) {
                bugReportSheet
            }

            Button {
                InteractionLog.log(.buttonTap, element: "feature_request_button", page: "Settings")
                showFeatureRequest = true
            } label: {
                Label("Send Feature Request", systemImage: "sparkles")
            }
            .accessibilityIdentifier("settings_feature_request_button")
            .sheet(isPresented: $showFeatureRequest) {
                featureRequestSheet
            }
        } header: {
            Text("Feedback")
        } footer: {
            Text("Bug reports and feature requests are sent to our team for review.")
        }
    }

    // MARK: - Bug Report Sheet

    private var bugReportSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("What went wrong?")
                    .font(.headline)

                Text("Describe what happened and what you expected instead. We read every report.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextEditor(text: $bugReportText)
                    .frame(minHeight: 150)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.secondarySystemGroupedBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color(.separator), lineWidth: 0.5)
                    )

                VStack(alignment: .leading, spacing: 8) {
                    Text("We'll include:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)

                    Label("App version: \(appVersion)", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Label("Device: \(UIDevice.current.model)", systemImage: "iphone")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Label("iOS: \(UIDevice.current.systemVersion)", systemImage: "gearshape")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Toggle(isOn: $includeScreenshot) {
                    Label("Include screenshot", systemImage: "camera.viewfinder")
                        .font(.caption)
                }
                .tint(.pink)

                Toggle(isOn: $includeHealthData) {
                    Label("Include health metrics", systemImage: "heart.text.square")
                        .font(.caption)
                }
                .tint(.pink)

                if includeHealthData {
                    Text("Your current heart rate, HRV, sleep, steps, and engine scores will be sent to our server to help reproduce the issue. No data is shared with third parties.")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                } else {
                    Text("Only your bug description, app version, and device info will be sent.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                if bugReportSubmitted {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Submitted successfully. Thank you!")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.green)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                Spacer()
            }
            .padding(20)
            .navigationTitle("Report a Bug")
            .navigationBarTitleDisplayMode(.inline)
            .animation(.easeInOut(duration: 0.3), value: bugReportSubmitted)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showBugReport = false
                        bugReportText = ""
                        bugReportSubmitted = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") {
                        submitBugReport()
                    }
                    .disabled(
                        bugReportSubmitted ||
                        bugReportText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                }
            }
        }
    }

    /// Collects all current health metrics and UI state from LocalStore,
    /// then uploads the bug report with full diagnostic context to Firestore.
    private func submitBugReport() {
        var metrics: [String: Any] = [:]

        // Only collect health metrics when the user explicitly opted in
        if includeHealthData {
            metrics = collectHealthMetrics()
        }

        // Capture screenshot of the main window (behind the sheet)
        if includeScreenshot, let screenshot = captureScreenshot() {
            metrics["screenshotBase64"] = screenshot
        }

        FeedbackService.shared.submitBugReport(
            description: bugReportText,
            appVersion: appVersion,
            deviceModel: UIDevice.current.model,
            iosVersion: UIDevice.current.systemVersion,
            healthMetrics: metrics,
            includeHealthData: includeHealthData
        ) { error in
            DispatchQueue.main.async {
                if error == nil {
                    bugReportSubmitted = true
                    // Auto-dismiss after showing success
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        showBugReport = false
                        bugReportText = ""
                        bugReportSubmitted = false
                    }
                }
            }
        }
    }

    /// Captures the app's main window as a compressed JPEG base64 string.
    /// Returns nil if the window is unavailable or rendering fails.
    private func captureScreenshot() -> String? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first(where: { $0.isKeyWindow }) else {
            return nil
        }

        let renderer = UIGraphicsImageRenderer(size: window.bounds.size)
        let image = renderer.image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: false)
        }

        // Compress to JPEG at 40% quality to stay under Firestore's 1MB doc limit
        guard let data = image.jpegData(compressionQuality: 0.4) else { return nil }

        // Cap at 500KB to be safe with Firestore document size limits
        guard data.count < 500_000 else {
            // Re-compress at lower quality
            guard let smallerData = image.jpegData(compressionQuality: 0.2) else { return nil }
            guard smallerData.count < 500_000 else { return nil }
            return smallerData.base64EncodedString()
        }

        return data.base64EncodedString()
    }

    /// Gathers every health metric currently stored — today's snapshot,
    /// engine outputs, goals, streak, and display state — so the team
    /// can see exactly what the user saw when they filed the report.
    private func collectHealthMetrics() -> [String: Any] {
        var metrics: [String: Any] = [:]

        let history = localStore.loadHistory()

        // Today's raw HealthKit snapshot
        if let today = history.last {
            let s = today.snapshot
            var snapshot: [String: Any] = [
                "date": ISO8601DateFormatter().string(from: s.date),
                "zoneMinutes": s.zoneMinutes
            ]
            if let v = s.restingHeartRate { snapshot["restingHeartRate_bpm"] = v }
            if let v = s.hrvSDNN { snapshot["hrvSDNN_ms"] = v }
            if let v = s.recoveryHR1m { snapshot["recoveryHR1m_bpm"] = v }
            if let v = s.recoveryHR2m { snapshot["recoveryHR2m_bpm"] = v }
            if let v = s.vo2Max { snapshot["vo2Max_mlkgmin"] = v }
            if let v = s.steps { snapshot["steps"] = v }
            if let v = s.walkMinutes { snapshot["walkMinutes"] = v }
            if let v = s.workoutMinutes { snapshot["workoutMinutes"] = v }
            if let v = s.sleepHours { snapshot["sleepHours"] = v }
            if let v = s.bodyMassKg { snapshot["bodyMassKg"] = v }
            if let v = s.heightM { snapshot["heightM"] = v }
            metrics["todaySnapshot"] = snapshot

            // Assessment (engine output)
            if let a = today.assessment {
                var assessment: [String: Any] = [
                    "statusRaw": a.status.rawValue,
                    "nudgeCategory": a.dailyNudge.category.rawValue,
                    "nudgeTitle": a.dailyNudge.title,
                    "nudgeDescription": a.dailyNudge.description,
                    "anomalyScore": a.anomalyScore,
                    "confidence": a.confidence.rawValue,
                    "explanation": a.explanation
                ]
                if let score = a.cardioScore {
                    assessment["cardioScore"] = score
                }
                metrics["assessment"] = assessment
            }
        }

        // User profile context
        let profile = localStore.profile
        metrics["streakDays"] = profile.streakDays
        metrics["onboardingComplete"] = profile.onboardingComplete

        // Recent history summary (last 7 days of key metrics)
        let recentDays = history.suffix(7)
        var historyArray: [[String: Any]] = []
        for stored in recentDays {
            var day: [String: Any] = [
                "date": ISO8601DateFormatter().string(from: stored.snapshot.date)
            ]
            if let v = stored.snapshot.restingHeartRate { day["rhr"] = v }
            if let v = stored.snapshot.hrvSDNN { day["hrv"] = v }
            if let v = stored.snapshot.sleepHours { day["sleep"] = v }
            if let v = stored.snapshot.steps { day["steps"] = v }
            if let v = stored.snapshot.walkMinutes { day["walkMin"] = v }
            if let v = stored.snapshot.workoutMinutes { day["workoutMin"] = v }
            if let a = stored.assessment {
                day["status"] = a.status.rawValue
            }
            historyArray.append(day)
        }
        if !historyArray.isEmpty {
            metrics["recentHistory_7d"] = historyArray
        }

        // Active screen state
        metrics["currentTab"] = "Settings"
        metrics["designVariantB"] = true
        metrics["dashboardDesign"] = "designB"
        metrics["anomalyAlertsEnabled"] = anomalyAlertsEnabled
        metrics["nudgeRemindersEnabled"] = nudgeRemindersEnabled
        metrics["telemetryConsent"] = telemetryConsent

        // Engine outputs and all UI display strings (written by DashboardViewModel)
        let diag = localStore.diagnosticSnapshot
        if !diag.isEmpty {
            metrics["uiDisplayState"] = diag
        }

        return metrics
    }

    // MARK: - Feature Request Sheet

    private var featureRequestSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("What would you like to see?")
                    .font(.headline)

                Text("Describe the feature or improvement you'd like. We read every request.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextEditor(text: $featureRequestText)
                    .frame(minHeight: 150)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.secondarySystemGroupedBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color(.separator), lineWidth: 0.5)
                    )

                VStack(alignment: .leading, spacing: 8) {
                    Text("We'll include:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)

                    Label("App version: \(appVersion)", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if featureRequestSubmitted {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Thanks! We'll consider this for a future update.")
                            .font(.subheadline)
                            .foregroundStyle(.green)
                    }
                }

                Spacer()
            }
            .padding(20)
            .navigationTitle("Feature Request")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showFeatureRequest = false
                        featureRequestText = ""
                        featureRequestSubmitted = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") {
                        submitFeatureRequest()
                    }
                    .disabled(featureRequestText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    /// Submits a feature request to Firestore.
    private func submitFeatureRequest() {
        FeedbackService.shared.submitFeatureRequest(
            description: featureRequestText,
            appVersion: appVersion
        )
        featureRequestSubmitted = true
    }

    // MARK: - Data Section

    private var dataSection: some View {
        Section {
            Button {
                InteractionLog.log(.buttonTap, element: "export_button", page: "Settings")
                showExportConfirmation = true
            } label: {
                Label("Export Health Data", systemImage: "square.and.arrow.up")
            }
            .accessibilityIdentifier("settings_export_button")
            .alert("Export Health Data", isPresented: $showExportConfirmation) {
                Button("Export CSV", role: nil) {
                    exportHealthData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will generate a CSV file containing your stored health snapshots and assessments.")
            }

            Button {
                InteractionLog.log(.buttonTap, element: "debug_trace_export", page: "Settings")
                showDebugTraceConfirmation = true
            } label: {
                Label("Export Debug Trace", systemImage: "ladybug.fill")
            }
            .accessibilityIdentifier("settings_debug_trace_button")
            .alert("Export Debug Trace", isPresented: $showDebugTraceConfirmation) {
                Button("Export JSON") {
                    exportDebugTrace()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Generates a JSON file with raw health data and engine outputs for debugging. You control who receives this file.")
            }
            Button(role: .destructive) {
                InteractionLog.log(.buttonTap, element: "delete_account_button", page: "Settings")
                showDeleteAccount = true
            } label: {
                Label("Delete Account", systemImage: "trash")
                    .foregroundStyle(.red)
            }
            .accessibilityIdentifier("settings_delete_account")
            .alert("Delete Account", isPresented: $showDeleteAccount) {
                Button("Delete Everything", role: .destructive) {
                    performAccountDeletion()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all your data from our servers, remove your sign-in credentials, and reset the app. This action cannot be undone.")
            }
        } header: {
            Text("Data")
        }
    }

    // MARK: - Account Deletion

    /// Deletes all server and local data, then returns the user to the sign-in screen.
    private func performAccountDeletion() {
        isDeletingAccount = true
        AccountDeletionService.deleteAccount(localStore: localStore) { _ in
            isDeletingAccount = false
            // The app will route back to AppleSignInView because
            // thump_signed_in was cleared by the deletion service.
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section {
            HStack {
                Label("Version", systemImage: "info.circle")
                Spacer()
                Text(appVersion)
                    .foregroundStyle(.secondary)
            }

            Label("Heart wellness tracking", systemImage: "heart.circle")
                .foregroundStyle(.secondary)
                .font(.subheadline)

            Button {
                InteractionLog.log(.linkTap, element: "terms_link", page: "Settings")
                showTermsOfService = true
            } label: {
                Label("Terms of Service", systemImage: "doc.text")
            }
            .accessibilityIdentifier("settings_terms_link")
            .sheet(isPresented: $showTermsOfService) {
                TermsOfServiceSheet()
            }

            Button {
                InteractionLog.log(.linkTap, element: "privacy_link", page: "Settings")
                showPrivacyPolicy = true
            } label: {
                Label("Privacy Policy", systemImage: "hand.raised.fill")
            }
            .accessibilityIdentifier("settings_privacy_link")
            .sheet(isPresented: $showPrivacyPolicy) {
                PrivacyPolicySheet()
            }

            if let supportURL = URL(string: "https://thump.app/support") {
                Link(destination: supportURL) {
                    Label("Help & Support", systemImage: "questionmark.circle")
                }
            }
        } header: {
            Text("About")
        }
    }

    // MARK: - Disclaimer Section

    private var disclaimerSection: some View {
        Section {
            // Health disclaimer
            disclaimerRow(
                icon: "heart.text.square",
                iconColor: .orange,
                title: "Not a Medical Device",
                body: "Thump is a wellness companion, not a medical "
                    + "device. It is not intended to diagnose, treat, "
                    + "cure, or prevent any disease or health condition."
            )

            // Data accuracy
            disclaimerRow(
                icon: "waveform.path.ecg",
                iconColor: .pink,
                title: "Data Accuracy",
                body: "Wellness insights are based on data from Apple "
                    + "Watch sensors, which may vary in accuracy. "
                    + "Numbers shown are estimates, not exact readings."
            )

            // Professional advice (Apple Guideline 1.4.1)
            disclaimerRow(
                icon: "stethoscope",
                iconColor: .blue,
                title: "Consult Your Doctor",
                body: "Always consult a qualified healthcare "
                    + "professional before making changes to your "
                    + "exercise, sleep, or health routine. Use Thump's "
                    + "suggestions as a starting point, not a substitute "
                    + "for medical advice."
            )

            // Emergency
            disclaimerRow(
                icon: "phone.fill",
                iconColor: .red,
                title: "Emergencies",
                body: "If you are experiencing a medical emergency, "
                    + "call 911 or your local emergency number "
                    + "immediately. Thump is not an emergency service."
            )

            // Privacy
            disclaimerRow(
                icon: "lock.shield.fill",
                iconColor: .green,
                title: "Privacy First",
                body: "All health data is processed on your iPhone "
                    + "and Apple Watch. Health metrics are only sent to "
                    + "our server if you explicitly opt in when filing "
                    + "a bug report. Anonymous engine scores may be "
                    + "shared if you enable analytics in Settings."
            )
        } header: {
            Text("Important Information")
        }
    }

    /// Reusable disclaimer row with icon, title, and body text.
    private func disclaimerRow(
        icon: String,
        iconColor: Color,
        title: String,
        body: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(iconColor)

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
            }

            Text(body)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Helpers

    /// The user's initials from their display name.
    private var initials: String {
        let name = localStore.profile.displayName
        let parts = name.split(separator: " ")
        if parts.isEmpty { return "T" }
        let first = parts.first?.prefix(1) ?? "T"
        let last = parts.count > 1 ? parts.last?.prefix(1) ?? "" : ""
        return "\(first)\(last)".uppercased()
    }

    /// Formatted join date string.
    private var formattedJoinDate: String {
        localStore.profile.joinDate.formatted(.dateTime.month(.wide).year())
    }

    /// Display name for the current subscription tier.
    private var currentTierDisplayName: String {
        localStore.tier.displayName
    }

    /// App version string from the bundle.
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    /// Generates a JSON debug trace with full raw health data and engine
    /// outputs for local debugging. The user shares it manually via the
    /// system share sheet — Apple-compliant because the user controls sharing.
    private func exportDebugTrace() {
        let history = localStore.loadHistory()
        guard !history.isEmpty else { return }

        let dateFormatter = ISO8601DateFormatter()
        var entries: [[String: Any]] = []

        for stored in history {
            let snap = stored.snapshot
            var entry: [String: Any] = [
                "date": dateFormatter.string(from: snap.date)
            ]

            // Raw health data (only in local export, never uploaded)
            var rawData: [String: Any] = [:]
            if let rhr = snap.restingHeartRate { rawData["restingHeartRate"] = rhr }
            if let hrv = snap.hrvSDNN { rawData["hrvSDNN"] = hrv }
            if let rec1 = snap.recoveryHR1m { rawData["recoveryHR1m"] = rec1 }
            if let rec2 = snap.recoveryHR2m { rawData["recoveryHR2m"] = rec2 }
            if let vo2 = snap.vo2Max { rawData["vo2Max"] = vo2 }
            if let steps = snap.steps { rawData["steps"] = steps }
            if let walk = snap.walkMinutes { rawData["walkMinutes"] = walk }
            if let workout = snap.workoutMinutes { rawData["workoutMinutes"] = workout }
            if let sleep = snap.sleepHours { rawData["sleepHours"] = sleep }
            if let mass = snap.bodyMassKg { rawData["bodyMassKg"] = mass }
            if !snap.zoneMinutes.isEmpty { rawData["zoneMinutes"] = snap.zoneMinutes }
            entry["rawData"] = rawData

            // Engine outputs
            if let assessment = stored.assessment {
                var engineOutput: [String: Any] = [
                    "status": assessment.status.rawValue,
                    "confidence": assessment.confidence.rawValue,
                    "anomalyScore": assessment.anomalyScore,
                    "regressionFlag": assessment.regressionFlag,
                    "stressFlag": assessment.stressFlag,
                    "nudgeCategory": assessment.dailyNudge.category.rawValue,
                    "nudgeTitle": assessment.dailyNudge.title
                ]
                if let cardio = assessment.cardioScore { engineOutput["cardioScore"] = cardio }
                if let scenario = assessment.scenario { engineOutput["scenario"] = scenario.rawValue }

                if let wow = assessment.weekOverWeekTrend {
                    engineOutput["weekOverWeek"] = [
                        "currentWeekMean": wow.currentWeekMean,
                        "baselineMean": wow.baselineMean,
                        "direction": String(describing: wow.direction)
                    ]
                }

                entry["engineOutput"] = engineOutput
            }

            entries.append(entry)
        }

        let trace: [String: Any] = [
            "exportDate": dateFormatter.string(from: Date()),
            "appVersion": appVersion,
            "deviceModel": UIDevice.current.model,
            "iosVersion": UIDevice.current.systemVersion,
            "historyDays": entries.count,
            "entries": entries
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: trace, options: [.prettyPrinted, .sortedKeys]) else {
            return
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("thump-debug-trace.json")
        do {
            try jsonData.write(to: tempURL)
        } catch {
            debugPrint("[SettingsView] Failed to write debug trace: \(error)")
            return
        }

        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first,
              let rootVC = window.rootViewController else { return }
        let activityVC = UIActivityViewController(
            activityItems: [tempURL],
            applicationActivities: nil
        )
        rootVC.present(activityVC, animated: true)
    }

    /// Generates a CSV export of the user's health snapshot history
    /// and presents a system share sheet for saving or sending.
    private func exportHealthData() {
        let history = localStore.loadHistory()
        guard !history.isEmpty else { return }

        // Build CSV header
        var csv = "Date,Resting HR,Heart Rate Variability (ms),Recovery 1m,Recovery 2m,"
            + "VO2 Max,Steps,Walk Min,Activity Min,Sleep Hours,"
            + "Status,Cardio Score\n"

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        // Build CSV rows from stored snapshots
        for stored in history {
            let snap = stored.snapshot
            let dateStr = dateFormatter.string(from: snap.date)
            let rhr: String = snap.restingHeartRate.map { String(format: "%.1f", $0) } ?? ""
            let hrv: String = snap.hrvSDNN.map { String(format: "%.1f", $0) } ?? ""
            let rec1: String = snap.recoveryHR1m.map { String(format: "%.1f", $0) } ?? ""
            let rec2: String = snap.recoveryHR2m.map { String(format: "%.1f", $0) } ?? ""
            let vo2: String = snap.vo2Max.map { String(format: "%.1f", $0) } ?? ""
            let steps: String = snap.steps.map { String(format: "%.0f", $0) } ?? ""
            let walk: String = snap.walkMinutes.map { String(format: "%.0f", $0) } ?? ""
            let workout: String = snap.workoutMinutes.map { String(format: "%.0f", $0) } ?? ""
            let sleep: String = snap.sleepHours.map { String(format: "%.1f", $0) } ?? ""
            let status: String = stored.assessment?.status.rawValue ?? ""
            let cardio: String = stored.assessment?.cardioScore.map { String(format: "%.0f", $0) } ?? ""
            let row = [dateStr, rhr, hrv, rec1, rec2, vo2, steps, walk, workout, sleep, status, cardio]
                .joined(separator: ",")
            csv += row + "\n"
        }

        // Write to temp file and present share sheet
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("thump-health-export.csv")
        do {
            try csv.write(to: tempURL, atomically: true, encoding: .utf8)
        } catch {
            debugPrint("[SettingsView] Failed to write export CSV: \(error)")
            return
        }

        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first,
              let rootVC = window.rootViewController else { return }
        let activityVC = UIActivityViewController(
            activityItems: [tempURL],
            applicationActivities: nil
        )
        rootVC.present(activityVC, animated: true)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Settings") {
    SettingsView()
        .environmentObject(LocalStore.preview)
}
#endif
