// ThumpComplications.swift
// Thump Watch
//
// Watch face complications — the #1 retention surface.
// Athlytic proves: if your app is on the watch face, users check it
// multiple times per day. If it's not, they forget you exist.
//
// Complication strategy:
//   Circular:    Score number in colored ring — the "what app is that?" moment
//   Rectangular: Score + status + nudge — the daily glanceable summary
//   Corner:      Score gauge arc — quick readiness indicator
//   Inline:      Score + mood label — minimal text
//
// Data flow:
//   Assessment arrives → WatchViewModel calls ThumpComplicationData.update()
//   → writes to shared UserDefaults → WidgetCenter reloads timelines
//   → ThumpComplicationProvider reads and returns new entry
//
// Platforms: watchOS 10+

import SwiftUI
import WidgetKit

// ThumpSharedKeys is defined in Shared/Services/ThumpSharedKeys.swift
// so both iOS and watchOS targets (including Siri intents) can access it.

// MARK: - Timeline Entry

struct ThumpComplicationEntry: TimelineEntry {
    let date: Date
    let mood: BuddyMood
    let cardioScore: Double?
    let nudgeTitle: String?
    let nudgeIcon: String?
    let stressFlag: Bool
    let status: String  // "improving", "stable", "needsAttention"
}

// MARK: - Timeline Provider

struct ThumpComplicationProvider: TimelineProvider {

    func placeholder(in context: Context) -> ThumpComplicationEntry {
        ThumpComplicationEntry(
            date: Date(),
            mood: .content,
            cardioScore: 74,
            nudgeTitle: "Midday Walk",
            nudgeIcon: "figure.walk",
            stressFlag: false,
            status: "stable"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (ThumpComplicationEntry) -> Void) {
        completion(readEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ThumpComplicationEntry>) -> Void) {
        let entry = readEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func readEntry() -> ThumpComplicationEntry {
        guard let defaults = UserDefaults(suiteName: ThumpSharedKeys.suiteName) else {
            return ThumpComplicationEntry(
                date: Date(), mood: .content, cardioScore: nil,
                nudgeTitle: nil, nudgeIcon: nil, stressFlag: false, status: "stable"
            )
        }

        let moodRaw = defaults.string(forKey: ThumpSharedKeys.moodKey) ?? "content"
        let mood = BuddyMood(rawValue: moodRaw) ?? .content
        let score: Double? = defaults.object(forKey: ThumpSharedKeys.cardioScoreKey) as? Double
        let nudgeTitle = defaults.string(forKey: ThumpSharedKeys.nudgeTitleKey)
        let nudgeIcon = defaults.string(forKey: ThumpSharedKeys.nudgeIconKey)
        let stressFlag = defaults.bool(forKey: ThumpSharedKeys.stressFlagKey)
        let status = defaults.string(forKey: ThumpSharedKeys.statusKey) ?? "stable"

        return ThumpComplicationEntry(
            date: Date(), mood: mood, cardioScore: score,
            nudgeTitle: nudgeTitle, nudgeIcon: nudgeIcon,
            stressFlag: stressFlag, status: status
        )
    }
}

// MARK: - Widget Definition

struct ThumpComplicationWidget: Widget {
    let kind = "ThumpBuddy"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ThumpComplicationProvider()) { entry in
            ThumpComplicationView(entry: entry)
        }
        .configurationDisplayName("Thump Readiness")
        .description("Your cardio readiness score at a glance")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryCorner,
            .accessoryInline,
        ])
    }
}

// MARK: - Complication View

struct ThumpComplicationView: View {
    let entry: ThumpComplicationEntry

    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCircular:  circularView
        case .accessoryRectangular: rectangularView
        case .accessoryCorner:    cornerView
        case .accessoryInline:    inlineView
        default:                  circularView
        }
    }

    // MARK: - Circular
    //
    // The billboard complication. Score number inside a colored gauge ring.
    // When someone sees "74" in green on a friend's wrist, they ask
    // "what app is that?" — that's how Athlytic grows.

    private var circularView: some View {
        ZStack {
            if let score = entry.cardioScore {
                // Score gauge — fills based on score (0-100 scale)
                Gauge(value: score, in: 0...100) {
                    EmptyView()
                } currentValueLabel: {
                    Text("\(Int(score))")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                }
                .gaugeStyle(.accessoryCircular)
                .tint(scoreGradient(score))
            } else {
                // No data yet — show buddy icon
                ThumpBuddy(mood: entry.mood, size: 24, showAura: false)
            }
        }
        .widgetAccentable()
    }

    // MARK: - Rectangular
    //
    // The information-rich complication. Score + trend + nudge.
    // This is the daily summary on the watch face.

    private var rectangularView: some View {
        HStack(spacing: 6) {
            // Left: score or buddy
            if let score = entry.cardioScore {
                ZStack {
                    Circle()
                        .stroke(scoreColor(score).opacity(0.3), lineWidth: 2)
                        .frame(width: 30, height: 30)
                    Text("\(Int(score))")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
            } else {
                ThumpBuddy(mood: entry.mood, size: 26, showAura: false)
            }

            VStack(alignment: .leading, spacing: 2) {
                // Line 1: status
                Text(statusLine)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                // Line 2: nudge or action
                HStack(spacing: 3) {
                    if let icon = entry.nudgeIcon {
                        Image(systemName: icon)
                            .font(.system(size: 8))
                    }
                    Text(actionLine)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                }
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .widgetAccentable()
    }

    // MARK: - Corner
    //
    // Score gauge in the corner position.

    private var cornerView: some View {
        ZStack {
            if let score = entry.cardioScore {
                Text("\(Int(score))")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
            } else {
                Image(systemName: entry.mood.badgeIcon)
                    .font(.system(size: 18, weight: .semibold))
            }
        }
        .widgetAccentable()
    }

    // MARK: - Inline

    private var inlineView: some View {
        HStack(spacing: 4) {
            if let score = entry.cardioScore {
                Image(systemName: "heart.fill")
                Text("\(Int(score))")
            } else {
                Image(systemName: entry.mood.badgeIcon)
            }
            Text("· \(entry.mood.label)")
            if entry.stressFlag {
                Text("· Stress")
            }
        }
        .widgetAccentable()
    }

    // MARK: - Content Helpers

    private var statusLine: String {
        if entry.stressFlag { return "Stress Detected" }
        switch entry.status {
        case "improving":      return "Improving"
        case "needsAttention": return "Recovery Needed"
        default:               return entry.mood.label
        }
    }

    private var actionLine: String {
        if entry.stressFlag { return "Open to breathe" }
        if let nudge = entry.nudgeTitle { return nudge }
        switch entry.mood {
        case .thriving:   return "Strong day"
        case .tired:      return "Rest tonight"
        case .conquering: return "Goal done"
        default:          return "Open for details"
        }
    }

    private func scoreColor(_ score: Double) -> Color {
        switch score {
        case 70...:   return .green
        case 40..<70: return .yellow
        default:      return .red
        }
    }

    private func scoreGradient(_ score: Double) -> Gradient {
        let color = scoreColor(score)
        return Gradient(colors: [color.opacity(0.6), color])
    }
}

// MARK: - Stress Heatmap Widget

/// Rectangular Smart Stack widget showing a 6-hour stress heatmap
/// with Activity and Breathe quick-action buttons.
/// This is the watch face complication users see without opening the app.
struct StressHeatmapWidget: Widget {
    let kind = "ThumpStressHeatmap"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StressHeatmapProvider()) { entry in
            StressHeatmapWidgetView(entry: entry)
        }
        .configurationDisplayName("Stress Heatmap")
        .description("Stress levels with quick actions")
        .supportedFamilies([.accessoryRectangular])
    }
}

// MARK: - Stress Heatmap Entry

struct StressHeatmapEntry: TimelineEntry {
    let date: Date
    /// 6 hourly stress levels (0=calm, 1=high). nil = no data.
    let hourlyStress: [Double?]
    let stressLabel: String
    let isStressed: Bool
}

// MARK: - Stress Heatmap Provider

struct StressHeatmapProvider: TimelineProvider {

    func placeholder(in context: Context) -> StressHeatmapEntry {
        StressHeatmapEntry(
            date: Date(),
            hourlyStress: [0.2, 0.3, 0.5, 0.4, 0.7, 0.3],
            stressLabel: "Calm",
            isStressed: false
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (StressHeatmapEntry) -> Void) {
        completion(readEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StressHeatmapEntry>) -> Void) {
        let entry = readEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func readEntry() -> StressHeatmapEntry {
        guard let defaults = UserDefaults(suiteName: ThumpSharedKeys.suiteName) else {
            return StressHeatmapEntry(
                date: Date(), hourlyStress: Array(repeating: nil, count: 6),
                stressLabel: "No data", isStressed: false
            )
        }

        let isStressed = defaults.bool(forKey: ThumpSharedKeys.stressFlagKey)
        let label = defaults.string(forKey: ThumpSharedKeys.stressLabelKey) ?? (isStressed ? "Stress is up" : "Calm")

        // Parse heatmap: "0.2,0.4,0.8,0.3,0.6,0.9"
        var hourlyStress: [Double?] = Array(repeating: nil, count: 6)
        if let raw = defaults.string(forKey: ThumpSharedKeys.stressHeatmapKey) {
            let parts = raw.split(separator: ",")
            for (i, part) in parts.prefix(6).enumerated() {
                hourlyStress[i] = Double(part)
            }
        }

        return StressHeatmapEntry(
            date: Date(), hourlyStress: hourlyStress,
            stressLabel: label, isStressed: isStressed
        )
    }
}

// MARK: - Stress Heatmap Widget View

struct StressHeatmapWidgetView: View {
    let entry: StressHeatmapEntry

    var body: some View {
        HStack(spacing: 6) {
            // Left: 6-hour mini heatmap
            VStack(alignment: .leading, spacing: 3) {
                // Label
                Text(entry.stressLabel)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(entry.isStressed ? Color.orange : .primary)
                    .lineLimit(1)

                // 6 dots — compact heatmap
                HStack(spacing: 4) {
                    ForEach(0..<6, id: \.self) { i in
                        stressDot(entry.hourlyStress[i], isLast: i == 5)
                    }
                }
            }

            Spacer(minLength: 2)

            // Right: Activity + Breathe stacked icons
            VStack(spacing: 4) {
                // Activity
                Link(destination: URL(string: "workout://startWorkout?activityType=52")!) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x22C55E))
                        .frame(width: 20, height: 20)
                        .background(
                            Circle().fill(Color(hex: 0x22C55E).opacity(0.2))
                        )
                }

                // Breathe
                Link(destination: URL(string: "mindfulness://")!) {
                    Image(systemName: "wind")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x0D9488))
                        .frame(width: 20, height: 20)
                        .background(
                            Circle().fill(Color(hex: 0x0D9488).opacity(0.2))
                        )
                }
            }
        }
        .widgetAccentable()
    }

    @ViewBuilder
    private func stressDot(_ level: Double?, isLast: Bool) -> some View {
        ZStack {
            if let level {
                Circle()
                    .fill(stressColor(level))
                    .frame(width: 10, height: 10)
                if isLast {
                    Circle()
                        .stroke(Color.white.opacity(0.8), lineWidth: 1)
                        .frame(width: 13, height: 13)
                }
            } else {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    .frame(width: 8, height: 8)
            }
        }
        .frame(width: 14, height: 14)
    }

    private func stressColor(_ level: Double) -> Color {
        switch level {
        case ..<0.3:    return Color(hex: 0x22C55E) // calm — green
        case 0.3..<0.6: return Color(hex: 0xF59E0B) // moderate — amber
        default:        return Color(hex: 0xEF4444) // high — red
        }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Readiness Gauge Widget (Circular)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// Circular gauge showing readiness score (0-100) with a color gradient.
/// The "at a glance" number that makes people ask "what app is that?"
struct ReadinessGaugeWidget: Widget {
    let kind = "ThumpReadiness"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ReadinessGaugeProvider()) { entry in
            ReadinessGaugeView(entry: entry)
        }
        .configurationDisplayName("Readiness")
        .description("Your body readiness score")
        .supportedFamilies([.accessoryCircular])
    }
}

struct ReadinessGaugeEntry: TimelineEntry {
    let date: Date
    let score: Double?
}

struct ReadinessGaugeProvider: TimelineProvider {
    func placeholder(in context: Context) -> ReadinessGaugeEntry {
        ReadinessGaugeEntry(date: Date(), score: 78)
    }

    func getSnapshot(in context: Context, completion: @escaping (ReadinessGaugeEntry) -> Void) {
        completion(readEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ReadinessGaugeEntry>) -> Void) {
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        completion(Timeline(entries: [readEntry()], policy: .after(nextUpdate)))
    }

    private func readEntry() -> ReadinessGaugeEntry {
        let defaults = UserDefaults(suiteName: ThumpSharedKeys.suiteName)
        let score = defaults?.object(forKey: ThumpSharedKeys.readinessScoreKey) as? Double
            ?? defaults?.object(forKey: ThumpSharedKeys.cardioScoreKey) as? Double
        return ReadinessGaugeEntry(date: Date(), score: score)
    }
}

struct ReadinessGaugeView: View {
    let entry: ReadinessGaugeEntry

    var body: some View {
        if let score = entry.score {
            Gauge(value: score, in: 0...100) {
                EmptyView()
            } currentValueLabel: {
                VStack(spacing: 0) {
                    Text("\(Int(score))")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Text("ready")
                        .font(.system(size: 7, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .gaugeStyle(.accessoryCircular)
            .tint(readinessGradient(score))
            .widgetAccentable()
        } else {
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 1) {
                    Image(systemName: "heart.circle")
                        .font(.system(size: 18))
                    Text("Ready")
                        .font(.system(size: 8, weight: .medium))
                }
            }
            .widgetAccentable()
        }
    }

    private func readinessGradient(_ score: Double) -> Gradient {
        switch score {
        case 75...:  return Gradient(colors: [Color(hex: 0x22C55E).opacity(0.6), Color(hex: 0x22C55E)])
        case 50..<75: return Gradient(colors: [Color(hex: 0xF59E0B).opacity(0.6), Color(hex: 0xF59E0B)])
        default:     return Gradient(colors: [Color(hex: 0xEF4444).opacity(0.6), Color(hex: 0xEF4444)])
        }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Quick Breathe Widget (Circular)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// One-tap complication to launch a breathing exercise.
/// Tapping opens Apple's Mindfulness app directly from the watch face.
struct BreatheLauncherWidget: Widget {
    let kind = "ThumpBreathe"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BreatheLauncherProvider()) { entry in
            BreatheLauncherView(entry: entry)
        }
        .configurationDisplayName("Quick Breathe")
        .description("One tap to start breathing")
        .supportedFamilies([.accessoryCircular])
    }
}

struct BreatheLauncherEntry: TimelineEntry {
    let date: Date
    let isStressed: Bool
}

struct BreatheLauncherProvider: TimelineProvider {
    func placeholder(in context: Context) -> BreatheLauncherEntry {
        BreatheLauncherEntry(date: Date(), isStressed: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (BreatheLauncherEntry) -> Void) {
        let stressed = UserDefaults(suiteName: ThumpSharedKeys.suiteName)?
            .bool(forKey: ThumpSharedKeys.stressFlagKey) ?? false
        completion(BreatheLauncherEntry(date: Date(), isStressed: stressed))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BreatheLauncherEntry>) -> Void) {
        let stressed = UserDefaults(suiteName: ThumpSharedKeys.suiteName)?
            .bool(forKey: ThumpSharedKeys.stressFlagKey) ?? false
        let entry = BreatheLauncherEntry(date: Date(), isStressed: stressed)
        // Static — only refresh when stress state changes (via WidgetCenter reload)
        completion(Timeline(entries: [entry], policy: .never))
    }
}

struct BreatheLauncherView: View {
    let entry: BreatheLauncherEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 2) {
                Image(systemName: "wind")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(entry.isStressed ? .orange : Color(hex: 0x0D9488))
                Text("Breathe")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
            }
        }
        .widgetAccentable()
        .widgetURL(URL(string: "mindfulness://"))
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - HRV Trend Widget (Rectangular)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// 7-day HRV sparkline showing recovery trend at a glance.
struct HRVTrendWidget: Widget {
    let kind = "ThumpHRVTrend"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HRVTrendProvider()) { entry in
            HRVTrendWidgetView(entry: entry)
        }
        .configurationDisplayName("HRV Trend")
        .description("7-day heart rate variability trend")
        .supportedFamilies([.accessoryRectangular])
    }
}

struct HRVTrendEntry: TimelineEntry {
    let date: Date
    let hrvValues: [Double?]  // last 7 days, nil = no data
    let latestHRV: Double?
}

struct HRVTrendProvider: TimelineProvider {
    func placeholder(in context: Context) -> HRVTrendEntry {
        HRVTrendEntry(date: Date(), hrvValues: [32, 35, 28, 40, 38, 42, 36], latestHRV: 36)
    }

    func getSnapshot(in context: Context, completion: @escaping (HRVTrendEntry) -> Void) {
        completion(readEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HRVTrendEntry>) -> Void) {
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        completion(Timeline(entries: [readEntry()], policy: .after(nextUpdate)))
    }

    private func readEntry() -> HRVTrendEntry {
        let defaults = UserDefaults(suiteName: ThumpSharedKeys.suiteName)
        var values: [Double?] = Array(repeating: nil, count: 7)
        if let raw = defaults?.string(forKey: ThumpSharedKeys.hrvTrendKey) {
            let parts = raw.split(separator: ",")
            for (i, part) in parts.prefix(7).enumerated() {
                values[i] = Double(part)
            }
        }
        let latest = values.last ?? nil
        return HRVTrendEntry(date: Date(), hrvValues: values, latestHRV: latest)
    }
}

struct HRVTrendWidgetView: View {
    let entry: HRVTrendEntry

    var body: some View {
        HStack(spacing: 6) {
            // Left: label + latest value
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 3) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 9, weight: .semibold))
                    Text("HRV")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                }

                if let latest = entry.latestHRV {
                    Text("\(Int(latest)) ms")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                    Text(trendLabel)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.secondary)
                } else {
                    Text("No data")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 2)

            // Right: sparkline
            HRVSparkline(values: entry.hrvValues)
                .frame(width: 60, height: 28)
        }
        .widgetAccentable()
    }

    private var trendLabel: String {
        let valid = entry.hrvValues.compactMap { $0 }
        guard valid.count >= 3 else { return "7-day trend" }
        let recent = valid.suffix(3).reduce(0, +) / Double(min(3, valid.suffix(3).count))
        let older = valid.prefix(3).reduce(0, +) / Double(min(3, valid.prefix(3).count))
        if recent > older * 1.05 { return "Improving ↑" }
        if recent < older * 0.95 { return "Declining ↓" }
        return "Stable →"
    }
}

/// Mini sparkline drawn with SwiftUI Path.
struct HRVSparkline: View {
    let values: [Double?]

    var body: some View {
        GeometryReader { geo in
            let valid = values.compactMap { $0 }
            if valid.count >= 2 {
                let minV = (valid.min() ?? 0) - 2
                let maxV = (valid.max() ?? 100) + 2
                let range = max(maxV - minV, 1)

                Path { path in
                    var started = false
                    for (i, val) in values.enumerated() {
                        guard let v = val else { continue }
                        let x = geo.size.width * CGFloat(i) / CGFloat(max(values.count - 1, 1))
                        let y = geo.size.height * (1 - CGFloat((v - minV) / range))
                        if !started {
                            path.move(to: CGPoint(x: x, y: y))
                            started = true
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(Color(hex: 0xA78BFA), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))

                // Latest value dot
                if let last = valid.last {
                    let lx = geo.size.width
                    let ly = geo.size.height * (1 - CGFloat((last - minV) / range))
                    Circle()
                        .fill(Color(hex: 0xA78BFA))
                        .frame(width: 4, height: 4)
                        .position(x: lx, y: ly)
                }
            } else {
                // Not enough data — placeholder dashes
                HStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.secondary.opacity(0.2))
                            .frame(width: 5, height: 2)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Coaching Nudge Widget (Inline)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// Inline text complication showing today's coaching nudge.
/// Appears as a single line on watch faces like Utility, Modular, Infograph.
struct CoachingNudgeWidget: Widget {
    let kind = "ThumpCoachingNudge"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CoachingNudgeProvider()) { entry in
            CoachingNudgeView(entry: entry)
        }
        .configurationDisplayName("Coaching Nudge")
        .description("Today's personalized coaching tip")
        .supportedFamilies([.accessoryInline])
    }
}

struct CoachingNudgeEntry: TimelineEntry {
    let date: Date
    let nudgeText: String
    let nudgeIcon: String
}

struct CoachingNudgeProvider: TimelineProvider {
    func placeholder(in context: Context) -> CoachingNudgeEntry {
        CoachingNudgeEntry(date: Date(), nudgeText: "Midday Walk · 15 min", nudgeIcon: "figure.walk")
    }

    func getSnapshot(in context: Context, completion: @escaping (CoachingNudgeEntry) -> Void) {
        completion(readEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CoachingNudgeEntry>) -> Void) {
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        completion(Timeline(entries: [readEntry()], policy: .after(nextUpdate)))
    }

    private func readEntry() -> CoachingNudgeEntry {
        let defaults = UserDefaults(suiteName: ThumpSharedKeys.suiteName)
        let text = defaults?.string(forKey: ThumpSharedKeys.coachingNudgeTextKey)
            ?? defaults?.string(forKey: ThumpSharedKeys.nudgeTitleKey)
            ?? "Open Thump"
        let icon = defaults?.string(forKey: ThumpSharedKeys.nudgeIconKey) ?? "heart.fill"
        return CoachingNudgeEntry(date: Date(), nudgeText: text, nudgeIcon: icon)
    }
}

struct CoachingNudgeView: View {
    let entry: CoachingNudgeEntry

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: entry.nudgeIcon)
            Text(entry.nudgeText)
        }
        .widgetAccentable()
    }
}

// MARK: - Widget Bundle

/// Registers all 6 Thump widgets.
/// Apply @main in the widget extension target entry point.
struct ThumpWidgetBundle: WidgetBundle {
    var body: some Widget {
        ThumpComplicationWidget()
        StressHeatmapWidget()
        ReadinessGaugeWidget()
        BreatheLauncherWidget()
        HRVTrendWidget()
        CoachingNudgeWidget()
    }
}

// MARK: - Write Helpers

/// Called from WatchViewModel when a new assessment arrives.
/// Pushes data to shared UserDefaults and triggers WidgetKit refresh.
enum ThumpComplicationData {

    static func update(
        mood: BuddyMood,
        cardioScore: Double?,
        nudgeTitle: String?,
        nudgeIcon: String?,
        stressFlag: Bool,
        status: TrendStatus = .stable
    ) {
        guard let defaults = UserDefaults(suiteName: ThumpSharedKeys.suiteName) else { return }
        defaults.set(mood.rawValue, forKey: ThumpSharedKeys.moodKey)
        if let score = cardioScore {
            defaults.set(score, forKey: ThumpSharedKeys.cardioScoreKey)
        }
        defaults.set(nudgeTitle, forKey: ThumpSharedKeys.nudgeTitleKey)
        defaults.set(nudgeIcon, forKey: ThumpSharedKeys.nudgeIconKey)
        defaults.set(stressFlag, forKey: ThumpSharedKeys.stressFlagKey)
        defaults.set(status.rawValue, forKey: ThumpSharedKeys.statusKey)

        reloadAllTimelines()
    }

    /// Updates the stress heatmap data for the widget.
    static func updateStressHeatmap(
        hourlyLevels: [Double],
        label: String,
        isStressed: Bool
    ) {
        guard let defaults = UserDefaults(suiteName: ThumpSharedKeys.suiteName) else { return }
        let csv = hourlyLevels.prefix(6).map { String(format: "%.2f", $0) }.joined(separator: ",")
        defaults.set(csv, forKey: ThumpSharedKeys.stressHeatmapKey)
        defaults.set(label, forKey: ThumpSharedKeys.stressLabelKey)
        defaults.set(isStressed, forKey: ThumpSharedKeys.stressFlagKey)

        WidgetCenter.shared.reloadTimelines(ofKind: "ThumpStressHeatmap")
        WidgetCenter.shared.reloadTimelines(ofKind: "ThumpBreathe")
    }

    /// Updates the readiness score for the readiness gauge widget.
    static func updateReadiness(score: Double) {
        guard let defaults = UserDefaults(suiteName: ThumpSharedKeys.suiteName) else { return }
        defaults.set(score, forKey: ThumpSharedKeys.readinessScoreKey)
        WidgetCenter.shared.reloadTimelines(ofKind: "ThumpReadiness")
    }

    /// Updates the HRV trend data (last 7 daily values in ms).
    static func updateHRVTrend(dailyValues: [Double]) {
        guard let defaults = UserDefaults(suiteName: ThumpSharedKeys.suiteName) else { return }
        let csv = dailyValues.prefix(7).map { String(format: "%.1f", $0) }.joined(separator: ",")
        defaults.set(csv, forKey: ThumpSharedKeys.hrvTrendKey)
        WidgetCenter.shared.reloadTimelines(ofKind: "ThumpHRVTrend")
    }

    /// Updates the coaching nudge text for the inline widget.
    static func updateCoachingNudge(text: String, icon: String) {
        guard let defaults = UserDefaults(suiteName: ThumpSharedKeys.suiteName) else { return }
        defaults.set(text, forKey: ThumpSharedKeys.coachingNudgeTextKey)
        defaults.set(icon, forKey: ThumpSharedKeys.nudgeIconKey)
        WidgetCenter.shared.reloadTimelines(ofKind: "ThumpCoachingNudge")
    }

    /// Reloads all widget timelines.
    private static func reloadAllTimelines() {
        let kinds = ["ThumpBuddy", "ThumpStressHeatmap", "ThumpReadiness",
                     "ThumpBreathe", "ThumpHRVTrend", "ThumpCoachingNudge"]
        for kind in kinds {
            WidgetCenter.shared.reloadTimelines(ofKind: kind)
        }
    }
}
