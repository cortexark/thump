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

/// A card displaying a connection between an activity factor and a wellness trend.
///
/// The visual centerpiece is a capsule-shaped strength indicator that fills
/// proportionally to the absolute connection value, colored to indicate
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

    /// Whether the raw correlation coefficient is positive (used for bar direction).
    private var isPositive: Bool {
        correlation.correlationStrength >= 0
    }

    /// Whether the correlation is considered weak (below 0.3 absolute).
    private var isWeak: Bool {
        absoluteStrength < 0.3
    }

    /// The accent color based on whether the correlation is beneficial, not just its sign.
    ///
    /// For example, steps vs RHR has a negative r (more steps → lower RHR) which is
    /// cardiovascularly beneficial, so it should show green, not red.
    private var strengthColor: Color {
        if isWeak { return .gray }
        return correlation.isBeneficial ? .green : .red
    }

    /// A descriptive word for the connection magnitude.
    private var magnitudeLabel: String {
        switch absoluteStrength {
        case 0..<0.1:  return "Too Early to Tell"
        case 0.1..<0.3: return "Slight Connection"
        case 0.3..<0.5: return "Noticeable Connection"
        case 0.5..<0.7: return "Clear Connection"
        default:         return "Strong Connection"
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

    /// A capsule-shaped bar showing connection strength from -1 to +1.
    private var strengthIndicator: some View {
        VStack(spacing: 6) {
            // Connection strength label
            HStack {
                Text("Weak")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(magnitudeLabel)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(strengthColor)

                Spacer()

                Text("Strong")
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

#Preview("Clear Positive Connection") {
    CorrelationCardView(
        correlation: CorrelationResult(
            factorName: "Daily Steps",
            correlationStrength: 0.72,
            interpretation: "On days you walk more, your HRV tends to look "
                + "a bit better the next day. Keep it up!",
            confidence: .high
        )
    )
    .padding()
}

#Preview("Noticeable Negative Connection") {
    CorrelationCardView(
        correlation: CorrelationResult(
            factorName: "Alcohol Consumption",
            correlationStrength: -0.45,
            interpretation: "On days with alcohol, your resting heart rate tends "
                + "to run a bit higher and HRV a bit lower. Worth noticing!",
            confidence: .medium
        )
    )
    .padding()
}

#Preview("Slight Connection") {
    CorrelationCardView(
        correlation: CorrelationResult(
            factorName: "Caffeine Intake",
            correlationStrength: 0.12,
            interpretation: "We haven't spotted a clear connection between caffeine and your heart rate patterns yet.",
            confidence: .low
        )
    )
    .padding()
}

#Preview("Strong Negative Connection") {
    CorrelationCardView(
        correlation: CorrelationResult(
            factorName: "Late-Night Screen Time",
            correlationStrength: -0.68,
            interpretation: "More screen time before bed seems to go along with "
                + "lighter sleep and a slightly higher resting heart rate "
                + "the next day. Something to keep in mind!",
            confidence: .high
        )
    )
    .padding()
}
