// WeeklyReportDetailView.swift
// Thump iOS
//
// Full-screen sheet presenting the weekly report with personalised,
// tappable action items. Each item can set a local reminder via
// UNUserNotificationCenter. Covers sleep, breathe/meditate,
// activity goal, and sunlight exposure.
// Platforms: iOS 17+

import SwiftUI
import UserNotifications

// MARK: - Weekly Report Detail View

/// Presents the full weekly report with tappable action cards.
///
/// Shown as a sheet from `InsightsView` when the user taps the
/// weekly report card. Each `WeeklyActionItem` can set a local
/// reminder at its suggested hour.
struct WeeklyReportDetailView: View {

    let report: WeeklyReport
    let plan: WeeklyActionPlan

    @Environment(\.dismiss) private var dismiss

    // Per-item reminder scheduling state
    @State private var reminderScheduled: Set<UUID> = []
    @State private var showingReminderConfirmation: UUID? = nil
    @State private var notificationsDenied = false
    @State private var permissionAlertShown = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    summaryHeader
                    actionItemsSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Weekly Plan")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Notifications Turned Off", isPresented: $permissionAlertShown) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Enable notifications in Settings so Thump can remind you about your action items.")
            }
        }
    }

    // MARK: - Summary Header

    private var summaryHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(dateRange)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if let score = report.avgCardioScore {
                    Text("\(Int(score))")
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text("avg score")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 4)
                }
            }

            trendRow

            Text(report.topInsight)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            nudgeProgressBar
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .padding(.top, 8)
    }

    private var trendRow: some View {
        HStack(spacing: 6) {
            let (icon, color, label) = trendMeta(report.trendDirection)
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(color)
        }
    }

    private var nudgeProgressBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Week completion")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(report.nudgeCompletionRate * 100))%")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.green)
                        .frame(width: geo.size.width * report.nudgeCompletionRate, height: 6)
                }
            }
            .frame(height: 6)
        }
    }

    // MARK: - Action Items Section

    private var actionItemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "checklist")
                    .font(.subheadline)
                    .foregroundStyle(.pink)
                Text("Next Actions")
                    .font(.headline)
            }

            ForEach(plan.items) { item in
                actionCard(for: item)
            }
        }
    }

    // MARK: - Action Card

    @ViewBuilder
    private func actionCard(for item: WeeklyActionItem) -> some View {
        if item.category == .sunlight, let windows = item.sunlightWindows {
            sunlightCard(item: item, windows: windows)
        } else {
            standardCard(for: item)
        }
    }

    // MARK: - Standard Card

    private func standardCard(for item: WeeklyActionItem) -> some View {
        let accentColor = Color(item.colorName)

        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                iconBadge(systemName: item.icon, color: accentColor)

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    Text(item.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(14)

            if item.supportsReminder, let hour = item.suggestedReminderHour {
                Divider().padding(.horizontal, 14)
                reminderRow(
                    itemId: item.id,
                    hour: hour,
                    title: item.title,
                    body: item.detail,
                    accentColor: accentColor
                )
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Sunlight Card

    private func sunlightCard(item: WeeklyActionItem, windows: [SunlightWindow]) -> some View {
        let accentColor = Color(item.colorName)

        return VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(alignment: .top, spacing: 12) {
                iconBadge(systemName: item.icon, color: accentColor)

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    Text(item.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(14)

            // "No GPS needed" badge
            HStack(spacing: 5) {
                Image(systemName: "location.slash.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("No location access needed — inferred from your movement")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 10)

            Divider().padding(.horizontal, 14)

            // Window rows
            ForEach(windows) { window in
                sunlightWindowRow(window: window, accentColor: accentColor)
                if window.id != windows.last?.id {
                    Divider().padding(.horizontal, 14)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private func sunlightWindowRow(window: SunlightWindow, accentColor: Color) -> some View {
        let windowScheduled = reminderScheduled.contains(window.id)
        let slotColor: Color = window.hasObservedMovement ? accentColor : .secondary

        return VStack(alignment: .leading, spacing: 8) {
            // Slot label row
            HStack(spacing: 8) {
                Image(systemName: window.slot.icon)
                    .font(.caption)
                    .foregroundStyle(slotColor)

                Text(window.slot.label)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                Spacer()

                if window.hasObservedMovement {
                    HStack(spacing: 3) {
                        Image(systemName: "figure.walk")
                            .font(.caption2)
                        Text("Active")
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(accentColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(accentColor.opacity(0.12), in: Capsule())
                } else {
                    HStack(spacing: 3) {
                        Image(systemName: "plus.circle")
                            .font(.caption2)
                        Text("Opportunity")
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color(.systemGray5), in: Capsule())
                }
            }

            // Coaching tip
            Text(window.tip)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // Reminder button for this window
            Button {
                Task { await scheduleWindowReminder(for: window) }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: windowScheduled ? "bell.fill" : "bell")
                        .font(.caption2)
                        .foregroundStyle(windowScheduled ? accentColor : .secondary)

                    Text(windowScheduled
                         ? "Reminder set for \(formattedHour(window.reminderHour))"
                         : "Remind me at \(formattedHour(window.reminderHour))")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(windowScheduled ? accentColor : .secondary)

                    Spacer()

                    if windowScheduled {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(accentColor)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Shared Sub-views

    private func iconBadge(systemName: String, color: Color) -> some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.15))
                .frame(width: 40, height: 40)
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(color)
        }
    }

    private func reminderRow(
        itemId: UUID,
        hour: Int,
        title: String,
        body: String,
        accentColor: Color
    ) -> some View {
        let isScheduled = reminderScheduled.contains(itemId)
        return Button {
            Task {
                await scheduleReminderById(
                    id: itemId,
                    hour: hour,
                    title: title,
                    body: body
                )
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isScheduled ? "bell.fill" : "bell")
                    .font(.caption)
                    .foregroundStyle(isScheduled ? accentColor : .secondary)

                Text(isScheduled
                     ? "Reminder set for \(formattedHour(hour))"
                     : "Remind me at \(formattedHour(hour))")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(isScheduled ? accentColor : .secondary)

                Spacer()

                if isScheduled {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(accentColor)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Reminder Scheduling

    private func scheduleReminder(for item: WeeklyActionItem) async {
        guard let hour = item.suggestedReminderHour else { return }
        await scheduleReminderById(id: item.id, hour: hour, title: item.title, body: item.detail)
    }

    private func scheduleWindowReminder(for window: SunlightWindow) async {
        await scheduleReminderById(
            id: window.id,
            hour: window.reminderHour,
            title: "Sunlight — \(window.slot.label)",
            body: window.tip
        )
    }

    private func scheduleReminderById(
        id: UUID,
        hour: Int,
        title: String,
        body: String
    ) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .notDetermined:
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
            if !granted {
                permissionAlertShown = true
                return
            }
        case .denied:
            permissionAlertShown = true
            return
        default:
            break
        }

        center.removePendingNotificationRequests(withIdentifiers: [id.uuidString])

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        var components = DateComponents()
        components.hour = hour
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: id.uuidString,
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
            reminderScheduled.insert(id)
        } catch {
            debugPrint("[WeeklyReportDetailView] Failed to schedule reminder: \(error)")
        }
    }

    // MARK: - Helpers

    private var dateRange: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return "\(fmt.string(from: plan.weekStart)) – \(fmt.string(from: plan.weekEnd))"
    }

    private func formattedHour(_ hour: Int) -> String {
        var components = DateComponents()
        components.hour = hour
        components.minute = 0
        let cal = Calendar.current
        if let date = cal.date(from: components) {
            let fmt = DateFormatter()
            fmt.timeStyle = .short
            fmt.dateStyle = .none
            return fmt.string(from: date)
        }
        return "\(hour):00"
    }

    private func trendMeta(
        _ direction: WeeklyReport.TrendDirection
    ) -> (icon: String, color: Color, label: String) {
        switch direction {
        case .up:   return ("arrow.up.right", .green, "Building Momentum")
        case .flat: return ("minus", .blue, "Holding Steady")
        case .down: return ("arrow.down.right", .orange, "Worth Watching")
        }
    }
}

// MARK: - Preview

#Preview("Weekly Report Detail") {
    let calendar = Calendar.current
    let weekEnd = calendar.startOfDay(for: Date())
    let weekStart = calendar.date(byAdding: .day, value: -6, to: weekEnd) ?? weekEnd

    let report = WeeklyReport(
        weekStart: weekStart,
        weekEnd: weekEnd,
        avgCardioScore: 72,
        trendDirection: .up,
        topInsight: "Your step count correlates strongly with improved HRV this week.",
        nudgeCompletionRate: 0.71
    )

    let items: [WeeklyActionItem] = [
        WeeklyActionItem(
            category: .sleep,
            title: "Go to Bed Earlier",
            detail: "Your average sleep this week was 6.1 hrs. Try going to bed 84 minutes earlier.",
            icon: "moon.stars.fill",
            colorName: "nudgeRest",
            supportsReminder: true,
            suggestedReminderHour: 21
        ),
        WeeklyActionItem(
            category: .breathe,
            title: "Daily Breathing Reset",
            detail: "Elevated load detected on 4 of 7 days. A 5-minute mid-afternoon session helps.",
            icon: "wind",
            colorName: "nudgeBreathe",
            supportsReminder: true,
            suggestedReminderHour: 15
        ),
        WeeklyActionItem(
            category: .activity,
            title: "Walk 12 More Minutes Today",
            detail: "You averaged 18 active minutes daily. Adding 12 minutes reaches the 30-min goal.",
            icon: "figure.walk",
            colorName: "nudgeWalk",
            supportsReminder: true,
            suggestedReminderHour: 9
        ),
        WeeklyActionItem(
            category: .sunlight,
            title: "One Sunlight Window Found",
            detail: "You have one regular movement window that could include outdoor light. Two more are waiting.",
            icon: "sun.max.fill",
            colorName: "nudgeCelebrate",
            supportsReminder: true,
            suggestedReminderHour: 7,
            sunlightWindows: [
                SunlightWindow(slot: .morning, reminderHour: 7, hasObservedMovement: true),
                SunlightWindow(slot: .lunch, reminderHour: 12, hasObservedMovement: false),
                SunlightWindow(slot: .evening, reminderHour: 17, hasObservedMovement: false)
            ]
        )
    ]

    let plan = WeeklyActionPlan(items: items, weekStart: weekStart, weekEnd: weekEnd)

    WeeklyReportDetailView(report: report, plan: plan)
}
