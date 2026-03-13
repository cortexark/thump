// MetricTileView.swift
// Thump iOS
//
// A warm, modern metric tile for the dashboard grid. Each tile has
// a subtle gradient accent, rounded corners, and friendly typography.
// Supports trend direction, confidence indicator, and locked state.

import SwiftUI

struct MetricTileView: View {
    let label: String
    let value: String
    let unit: String
    let trend: TrendDirection?
    let confidence: ConfidenceLevel?
    let isLocked: Bool
    let lowerIsBetter: Bool

    enum TrendDirection {
        case up, down, flat

        var icon: String {
            switch self {
            case .up:   return "arrow.up.right"
            case .down: return "arrow.down.right"
            case .flat: return "minus"
            }
        }

        /// Default color (higher is better).
        var color: Color {
            switch self {
            case .up:   return Color(hex: 0x22C55E)
            case .down: return Color(hex: 0xEF4444)
            case .flat: return .secondary
            }
        }

        /// Inverted color for metrics where lower is better (e.g. RHR).
        var invertedColor: Color {
            switch self {
            case .up:   return Color(hex: 0xEF4444)
            case .down: return Color(hex: 0x22C55E)
            case .flat: return .secondary
            }
        }
    }

    init(
        label: String,
        value: String,
        unit: String,
        trend: TrendDirection? = nil,
        confidence: ConfidenceLevel? = nil,
        isLocked: Bool = false,
        lowerIsBetter: Bool = false
    ) {
        self.label = label
        self.value = value
        self.unit = unit
        self.trend = trend
        self.confidence = confidence
        self.isLocked = isLocked
        self.lowerIsBetter = lowerIsBetter
    }

    // MARK: - Metric Color

    private var accentColor: Color {
        switch label {
        case "Resting Heart Rate": return Color(hex: 0xEF4444)
        case "HRV":                return Color(hex: 0x3B82F6)
        case "Recovery":           return Color(hex: 0x22C55E)
        case "Cardio Fitness":     return Color(hex: 0x8B5CF6)
        case "Active Minutes":     return Color(hex: 0xF59E0B)
        case "Sleep":              return Color(hex: 0x6366F1)
        case "Weight":             return Color(hex: 0x0D9488)
        default:                   return Color(hex: 0x3B82F6)
        }
    }

    private var metricIcon: String {
        switch label {
        case "Resting Heart Rate": return "heart.fill"
        case "HRV":                return "waveform.path.ecg"
        case "Recovery":           return "arrow.uturn.up"
        case "Cardio Fitness":     return "lungs.fill"
        case "Active Minutes":     return "figure.run"
        case "Sleep":              return "moon.zzz.fill"
        case "Weight":             return "scalemass.fill"
        default:                   return "heart.fill"
        }
    }

    // MARK: - Accessibility

    private var trendText: String {
        guard let trend else { return "" }
        if lowerIsBetter {
            switch trend {
            case .up:   return "moving up lately, which may need attention"
            case .down: return "easing down lately, which is a good sign"
            case .flat: return "holding steady"
            }
        }
        switch trend {
        case .up:   return "moving up lately"
        case .down: return "easing down lately"
        case .flat: return "holding steady"
        }
    }

    private var confidenceText: String {
        guard let confidence else { return "" }
        return "pattern strength \(confidence.displayName)"
    }

    private var accessibilityDescription: String {
        if isLocked {
            return "\(label), locked. Upgrade to Pro to view."
        }
        var parts = [label, value, unit]
        if !trendText.isEmpty { parts.append(trendText) }
        if !confidenceText.isEmpty { parts.append(confidenceText) }
        return parts.joined(separator: ", ")
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            tileContent
                .blur(radius: isLocked ? 6 : 0)

            if isLocked {
                lockedOverlay
            }
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(accentColor.opacity(0.08), lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityValue(isLocked ? "locked" : trendText)
    }

    // MARK: - Tile Content

    private var tileContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: metricIcon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(accentColor)

                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                if let confidence {
                    confidenceDot(for: confidence)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text(unit)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)

                Spacer()

                if let trend {
                    let trendColor = lowerIsBetter ? trend.invertedColor : trend.color
                    Image(systemName: trend.icon)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(trendColor)
                        .padding(4)
                        .background(
                            Circle().fill(trendColor.opacity(0.1))
                        )
                }
            }
        }
        .padding(14)
    }

    // MARK: - Locked Overlay

    private var lockedOverlay: some View {
        VStack(spacing: 6) {
            Image(systemName: "lock.fill")
                .font(.title3)
                .foregroundStyle(.secondary)

            Text("Upgrade to Pro")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Confidence Dot

    private func confidenceDot(for level: ConfidenceLevel) -> some View {
        let color: Color = switch level {
        case .high:   Color(hex: 0x22C55E)
        case .medium: Color(hex: 0xF59E0B)
        case .low:    Color(hex: 0xF97316)
        }
        return Circle()
            .fill(color)
            .frame(width: 7, height: 7)
    }
}

// MARK: - Convenience Initializer from Optional Values

extension MetricTileView {
    init(
        label: String,
        optionalValue: Double?,
        unit: String,
        decimals: Int = 0,
        trend: TrendDirection? = nil,
        confidence: ConfidenceLevel? = nil,
        isLocked: Bool = false,
        lowerIsBetter: Bool = false
    ) {
        self.label = label
        if let val = optionalValue {
            if decimals == 0 {
                self.value = "\(Int(val))"
            } else {
                self.value = String(format: "%.\(decimals)f", val)
            }
        } else {
            self.value = "--"
        }
        self.unit = unit
        self.trend = trend
        self.confidence = confidence
        self.isLocked = isLocked
        self.lowerIsBetter = lowerIsBetter
    }
}

#Preview("Unlocked") {
    MetricTileView(
        label: "Resting Heart Rate",
        value: "62",
        unit: "bpm",
        trend: .down,
        confidence: .high,
        isLocked: false
    )
    .padding()
}

#Preview("Locked") {
    MetricTileView(
        label: "HRV",
        value: "48",
        unit: "ms",
        trend: .up,
        confidence: .medium,
        isLocked: true
    )
    .padding()
}
