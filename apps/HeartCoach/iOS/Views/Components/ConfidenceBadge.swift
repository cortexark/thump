// ConfidenceBadge.swift
// Thump iOS
//
// A compact capsule badge that displays the confidence level of an assessment.
// Uses color coding and SF Symbol icons to communicate data reliability at a glance.

import SwiftUI

struct ConfidenceBadge: View {
    let confidence: ConfidenceLevel

    private var icon: String {
        switch confidence {
        case .high:   return "checkmark.circle.fill"
        case .medium: return "questionmark.circle.fill"
        case .low:    return "exclamationmark.circle.fill"
        }
    }

    private var tintColor: Color {
        switch confidence {
        case .high:   return .green
        case .medium: return .yellow
        case .low:    return .orange
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)

            Text(confidence.displayName)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundStyle(tintColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tintColor.opacity(0.15), in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Data confidence: \(confidence.displayName)")
        .accessibilityValue(confidence.displayName)
    }
}

#Preview("High Confidence") {
    ConfidenceBadge(confidence: .high)
        .padding()
}

#Preview("Medium Confidence") {
    ConfidenceBadge(confidence: .medium)
        .padding()
}

#Preview("Low Confidence") {
    ConfidenceBadge(confidence: .low)
        .padding()
}
