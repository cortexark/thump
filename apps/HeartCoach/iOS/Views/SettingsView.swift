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

    /// Feedback preferences.
    @State private var feedbackPrefs: FeedbackPreferences = FeedbackPreferences()

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                profileSection
                subscriptionSection
                feedbackPreferencesSection
                notificationsSection
                dataSection
                bugReportSection
                aboutSection
                disclaimerSection
            }
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
                    Text(localStore.profile.displayName.isEmpty
                         ? "Thump User"
                         : localStore.profile.displayName)
                        .font(.headline)

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
                in: ...Calendar.current.date(byAdding: .year, value: -13, to: Date())!,
                displayedComponents: .date
            ) {
                Label("Date of Birth", systemImage: "birthday.cake.fill")
                    .foregroundStyle(.primary)
            }
            .accessibilityIdentifier("settings_dob_picker")
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
            HStack {
                Label("Current Plan", systemImage: "creditcard.fill")
                Spacer()
                Text(currentTierDisplayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.pink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.pink.opacity(0.12), in: Capsule())
            }

            Button {
                InteractionLog.log(.buttonTap, element: "upgrade_button", page: "Settings")
                showPaywall = true
            } label: {
                HStack {
                    Label("Upgrade Plan", systemImage: "arrow.up.circle.fill")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityIdentifier("settings_upgrade_button")
        } header: {
            Text("Subscription")
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
            }

            Toggle(isOn: $nudgeRemindersEnabled) {
                Label("Nudge Reminders", systemImage: "bell.badge.fill")
            }
            .tint(.pink)
            .onChange(of: nudgeRemindersEnabled) { _, newValue in
                InteractionLog.log(.toggleChange, element: "nudge_reminders_toggle", page: "Settings", details: "enabled=\(newValue)")
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
            .sheet(isPresented: $showBugReport) {
                bugReportSheet
            }

            if let supportURL = URL(string: "https://thump.app/feedback") {
                Link(destination: supportURL) {
                    Label("Send Feature Request", systemImage: "sparkles")
                }
            }
        } header: {
            Text("Feedback")
        } footer: {
            Text(
                "Bug reports are sent via email. You can also leave feedback "
                + "through the App Store review or our website."
            )
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

                if bugReportSubmitted {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Thanks! We'll look into this.")
                            .font(.subheadline)
                            .foregroundStyle(.green)
                    }
                }

                Spacer()
            }
            .padding(20)
            .navigationTitle("Report a Bug")
            .navigationBarTitleDisplayMode(.inline)
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
                    .disabled(bugReportText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    /// Submits a bug report via the system email compose sheet.
    /// Falls back to copying to clipboard if no email is available.
    private func submitBugReport() {
        let body = """
        Bug Report
        ----------
        \(bugReportText)

        Device Info
        ----------
        App: \(appVersion)
        Device: \(UIDevice.current.model)
        iOS: \(UIDevice.current.systemVersion)
        """

        // Try to compose an email
        if let emailURL = URL(string: "mailto:bugs@thump.app?subject=Bug%20Report&body=\(body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
            UIApplication.shared.open(emailURL)
        }

        bugReportSubmitted = true
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
        } header: {
            Text("Data")
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

            // Professional advice
            disclaimerRow(
                icon: "stethoscope",
                iconColor: .blue,
                title: "Consult a Professional",
                body: "Always consult a qualified healthcare "
                    + "professional before making changes to your "
                    + "health routine or if you have concerns."
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
                title: "Your Data Stays on Your Device",
                body: "All health data is processed on your iPhone "
                    + "and Apple Watch. No health data is sent to any "
                    + "server. We collect anonymous usage analytics to "
                    + "improve the app experience."
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

#Preview("Settings") {
    SettingsView()
        .environmentObject(LocalStore.preview)
}
