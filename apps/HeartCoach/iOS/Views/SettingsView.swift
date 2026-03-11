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
    @State private var anomalyAlertsEnabled: Bool = true

    /// Whether daily nudge reminder notifications are enabled.
    @State private var nudgeRemindersEnabled: Bool = true

    /// Controls presentation of the paywall sheet.
    @State private var showPaywall: Bool = false

    /// Controls presentation of the export confirmation alert.
    @State private var showExportConfirmation: Bool = false

    /// Controls presentation of the privacy policy sheet.
    @State private var showPrivacyPolicy: Bool = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                profileSection
                subscriptionSection
                notificationsSection
                dataSection
                aboutSection
                disclaimerSection
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
        } header: {
            Text("Profile")
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
        } header: {
            Text("Subscription")
        }
    }

    // MARK: - Notifications Section

    private var notificationsSection: some View {
        Section {
            Toggle(isOn: $anomalyAlertsEnabled) {
                Label("Anomaly Alerts", systemImage: "exclamationmark.triangle.fill")
            }
            .tint(.pink)

            Toggle(isOn: $nudgeRemindersEnabled) {
                Label("Nudge Reminders", systemImage: "bell.badge.fill")
            }
            .tint(.pink)
        } header: {
            Text("Notifications")
        } footer: {
            Text(
                "Anomaly alerts notify you when unusual heart patterns are detected. "
                    + "Nudge reminders encourage daily engagement."
            )
        }
    }

    // MARK: - Data Section

    private var dataSection: some View {
        Section {
            Button {
                showExportConfirmation = true
            } label: {
                Label("Export Health Data", systemImage: "square.and.arrow.up")
            }
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

            Label("Your heart's daily story", systemImage: "heart.circle")
                .foregroundStyle(.secondary)
                .font(.subheadline)

            Button {
                showPrivacyPolicy = true
            } label: {
                Label("Privacy Policy", systemImage: "hand.raised.fill")
            }
            .sheet(isPresented: $showPrivacyPolicy) {
                privacyPolicySheet
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

    // MARK: - Privacy Policy Sheet

    private var privacyPolicySheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Privacy Policy")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(
                        "Thump takes your privacy seriously. All health data is "
                            + "processed on-device and is never transmitted to "
                            + "external servers. Your data stays on your iPhone "
                            + "and Apple Watch."
                    )
                        .font(.body)
                        .foregroundStyle(.secondary)

                    Text("Data Collection")
                        .font(.headline)

                    Text(
                        "Thump reads health metrics from Apple HealthKit with "
                            + "your explicit permission. No data is shared with "
                            + "third parties. Subscription management is handled "
                            + "through Apple's App Store infrastructure."
                    )
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .padding(20)
            }
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showPrivacyPolicy = false
                    }
                }
            }
        }
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
        var csv = "Date,Resting HR,HRV (SDNN),Recovery 1m,Recovery 2m,"
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
