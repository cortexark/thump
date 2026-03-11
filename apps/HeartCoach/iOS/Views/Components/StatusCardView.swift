// StatusCardView.swift
// Thump iOS
//
// The hero card at the top of the dashboard. Shows the overall heart health
// status, confidence badge, cardio fitness score, and a brief explanation.
// Background tint color reflects the current status for immediate visual feedback.

import SwiftUI

struct StatusCardView: View {
    let status: TrendStatus
    let confidence: ConfidenceLevel
    let cardioScore: Double?
    let explanation: String

    private var statusText: String {
        switch status {
        case .improving:      return "Improving"
        case .stable:         return "Stable"
        case .needsAttention: return "Needs Attention"
        }
    }

    private var statusIcon: String {
        switch status {
        case .improving:      return "arrow.up.heart.fill"
        case .stable:         return "heart.fill"
        case .needsAttention: return "heart.text.square.fill"
        }
    }

    private var statusColor: Color {
        switch status {
        case .improving:      return .green
        case .stable:         return .blue
        case .needsAttention: return .orange
        }
    }

    // MARK: - Accessibility

    private var accessibilityDescription: String {
        var parts = ["Heart health status: \(statusText)"]
        parts.append("confidence \(confidence.displayName)")
        if let score = cardioScore {
            parts.append("cardio score \(Int(score)) out of 100")
        }
        if !explanation.isEmpty {
            parts.append(explanation)
        }
        return parts.joined(separator: ", ")
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Top row: status label and confidence badge
            HStack(alignment: .center) {
                Image(systemName: statusIcon)
                    .font(.title2)
                    .foregroundStyle(statusColor)

                Text(statusText)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(statusColor)

                Spacer()

                ConfidenceBadge(confidence: confidence)
            }

            // Cardio score display
            if let score = cardioScore {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(Int(score))")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(statusColor)

                    Text("/ 100")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            // Explanation text
            if !explanation.isEmpty {
                Text(explanation)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(statusColor.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(statusColor.opacity(0.2), lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityValue(statusText)
    }
}

#Preview("Improving with Score") {
    StatusCardView(
        status: .improving,
        confidence: .high,
        cardioScore: 78,
        explanation: "Your resting heart rate has decreased over the past 7 days, "
            + "and HRV is trending upward. Great progress."
    )
    .padding()
}

#Preview("Needs Attention") {
    StatusCardView(
        status: .needsAttention,
        confidence: .medium,
        cardioScore: 42,
        explanation: "We noticed elevated resting heart rate and reduced HRV over the past 3 days. Consider extra rest."
    )
    .padding()
}

#Preview("Stable, No Score") {
    StatusCardView(
        status: .stable,
        confidence: .low,
        cardioScore: nil,
        explanation: "Not enough data yet to compute a full score. Keep wearing your watch."
    )
    .padding()
}
