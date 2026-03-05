// MetricTileView.swift
// Thump iOS
//
// A reusable metric tile for the dashboard grid. Displays a health metric's
// label, formatted value with unit, trend direction, and confidence indicator.
// Supports a locked state for gating behind subscription tiers.

import SwiftUI

struct MetricTileView: View {
    let label: String
    let value: String
    let unit: String
    let trend: TrendDirection?
    let confidence: ConfidenceLevel?
    let isLocked: Bool

    enum TrendDirection {
        case up, down, flat

        var icon: String {
            switch self {
            case .up:   return "arrow.up.right"
            case .down: return "arrow.down.right"
            case .flat: return "minus"
            }
        }

        var color: Color {
            switch self {
            case .up:   return .green
            case .down: return .red
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
        isLocked: Bool = false
    ) {
        self.label = label
        self.value = value
        self.unit = unit
        self.trend = trend
        self.confidence = confidence
        self.isLocked = isLocked
    }


    // MARK: - Accessibility Helpers

    private var trendText: String {
        guard let trend else { return "" }
        switch trend {
        case .up:   return "trending up"
        case .down: return "trending down"
        case .flat: return "no change"
        }
    }

    private var confidenceText: String {
        guard let confidence else { return "" }
        return "confidence \(confidence.displayName)"
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
    var body: some View {
        ZStack {
            tileContent
                .blur(radius: isLocked ? 6 : 0)

            if isLocked {
                lockedOverlay
            }
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityValue(isLocked ? "locked" : trendText)
    }

    // MARK: - Tile Content

    private var tileContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                if let confidence {
                    confidenceDot(for: confidence)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .fontDesign(.rounded)
                    .foregroundStyle(.primary)

                Text(unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if let trend {
                    Image(systemName: trend.icon)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(trend.color)
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
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Confidence Dot

    private func confidenceDot(for level: ConfidenceLevel) -> some View {
        let color: Color = switch level {
        case .high:   .green
        case .medium: .yellow
        case .low:    .orange
        }
        return Circle()
            .fill(color)
            .frame(width: 7, height: 7)
    }
}

// MARK: - Convenience Initializer from Optional Values

extension MetricTileView {
    /// Creates a tile from an optional Double, formatting it for display.
    init(
        label: String,
        optionalValue: Double?,
        unit: String,
        decimals: Int = 0,
        trend: TrendDirection? = nil,
        confidence: ConfidenceLevel? = nil,
        isLocked: Bool = false
    ) {
        self.label = label
        if let v = optionalValue {
            if decimals == 0 {
                self.value = "\(Int(v))"
            } else {
                self.value = String(format: "%.\(decimals)f", v)
            }
        } else {
            self.value = "--"
        }
        self.unit = unit
        self.trend = trend
        self.confidence = confidence
        self.isLocked = isLocked
    }
}

#Preview("Unlocked") {
    MetricTileView(
        label: "Resting HR",
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
