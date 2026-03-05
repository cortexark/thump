// CorrelationCardView.swift
// Thump iOS
//
// Displays a single activity-trend correlation result. Shows the factor name,
// a capsule-shaped correlation strength indicator scaled from -1 to +1,
// the interpretation text, and a confidence badge. Color coding reflects
// the direction and strength: green for positive, red for negative, gray
// for weak correlations.
//
// Platforms: iOS 17+

import SwiftUI

// MARK: - CorrelationCardView

/// A card displaying a correlation between an activity factor and a heart metric.
///
/// The visual centerpiece is a capsule-shaped strength indicator that fills
/// proportionally to the absolute correlation value, colored to indicate
/// direction (positive = green, negative = red, weak = gray).
struct CorrelationCardView: View {

    // MARK: - Properties

    /// The correlation result to display.
    let correlation: CorrelationResult

    // MARK: - Computed Properties

    /// The absolute strength of the correlation (0.0 to 1.0).
    private var absoluteStrength: Double {
        min(abs(correlation.correlationStrength), 1.0)
    }

    /// Whether the correlation is positive.
    private var isPositive: Bool {
        correlation.correlationStrength >= 0
    }

    /// Whether the correlation is considered weak (below 0.3 absolute).
    private var isWeak: Bool {
        absoluteStrength < 0.3
    }

    /// The accent color based on correlation direction and strength.
    private var strengthColor: Color {
        if isWeak { return .gray }
        return isPositive ? .green : .red
    }

    /// A human-readable label for the correlation strength.
    private var strengthLabel: String {
        let value = correlation.correlationStrength
        let prefix = value >= 0 ? "+" : ""
        return "\(prefix)\(String(format: "%.2f", value))"
    }

    /// A descriptive word for the strength magnitude.
    private var magnitudeLabel: String {
        switch absoluteStrength {
        case 0..<0.1:  return "Negligible"
        case 0.1..<0.3: return "Weak"
        case 0.3..<0.5: return "Moderate"
        case 0.5..<0.7: return "Strong"
        default:         return "Very Strong"
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerRow
            strengthIndicator
            interpretationSection
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(strengthColor.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Header Row

    /// Factor name, magnitude label, and confidence badge.
    private var headerRow: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(correlation.factorName)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(magnitudeLabel)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(strengthColor)
            }

            Spacer()

            ConfidenceBadge(confidence: correlation.confidence)
        }
    }

    // MARK: - Strength Indicator

    /// A capsule-shaped bar showing correlation strength from -1 to +1.
    private var strengthIndicator: some View {
        VStack(spacing: 6) {
            // Correlation value label
            HStack {
                Text("-1")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(strengthLabel)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .fontDesign(.rounded)
                    .foregroundStyle(strengthColor)

                Spacer()

                Text("+1")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // The capsule bar
            GeometryReader { geometry in
                let totalWidth = geometry.size.width
                let midPoint = totalWidth / 2
                let barWidth = totalWidth * absoluteStrength / 2

                ZStack(alignment: .leading) {
                    // Background track
                    Capsule()
                        .fill(Color(.systemGray5))
                        .frame(height: 12)

                    // Center marker
                    Rectangle()
                        .fill(Color(.systemGray3))
                        .frame(width: 1.5, height: 16)
                        .position(x: midPoint, y: 6)

                    // Filled portion
                    if isPositive {
                        Capsule()
                            .fill(strengthColor.gradient)
                            .frame(width: barWidth, height: 12)
                            .offset(x: midPoint)
                    } else {
                        Capsule()
                            .fill(strengthColor.gradient)
                            .frame(width: barWidth, height: 12)
                            .offset(x: midPoint - barWidth)
                    }
                }
            }
            .frame(height: 16)
        }
    }

    // MARK: - Interpretation Section

    /// The human-readable interpretation text.
    private var interpretationSection: some View {
        Text(correlation.interpretation)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Previews

#Preview("Strong Positive") {
    CorrelationCardView(
        correlation: CorrelationResult(
            factorName: "Daily Steps",
            correlationStrength: 0.72,
            interpretation: "Higher daily step counts are strongly associated with improved HRV readings the following day.",
            confidence: .high
        )
    )
    .padding()
}

#Preview("Moderate Negative") {
    CorrelationCardView(
        correlation: CorrelationResult(
            factorName: "Alcohol Consumption",
            correlationStrength: -0.45,
            interpretation: "Days with reported alcohol consumption tend to show elevated resting heart rate and reduced HRV.",
            confidence: .medium
        )
    )
    .padding()
}

#Preview("Weak Correlation") {
    CorrelationCardView(
        correlation: CorrelationResult(
            factorName: "Caffeine Intake",
            correlationStrength: 0.12,
            interpretation: "No significant relationship detected between caffeine intake and heart rate metrics.",
            confidence: .low
        )
    )
    .padding()
}

#Preview("Strong Negative") {
    CorrelationCardView(
        correlation: CorrelationResult(
            factorName: "Late-Night Screen Time",
            correlationStrength: -0.68,
            interpretation: "Extended screen time before bed is strongly correlated with reduced sleep quality and elevated next-day resting heart rate.",
            confidence: .high
        )
    )
    .padding()
}
