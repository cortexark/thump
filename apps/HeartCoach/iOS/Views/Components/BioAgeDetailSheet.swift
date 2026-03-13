// BioAgeDetailSheet.swift
// Thump iOS
//
// A detail sheet presenting the full Bio Age breakdown with per-metric
// contributions, expected vs. actual values, and actionable tips.
//
// Platforms: iOS 17+

import SwiftUI

// MARK: - BioAgeDetailSheet

/// Modal sheet that expands the dashboard Bio Age card into a full
/// breakdown showing each metric's contribution and practical tips.
struct BioAgeDetailSheet: View {

    let result: BioAgeResult

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    heroSection
                    breakdownSection
                    tipsSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Bio Age")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 16) {
            // Large bio age display
            ZStack {
                Circle()
                    .stroke(categoryColor.opacity(0.15), lineWidth: 12)
                    .frame(width: 140, height: 140)

                Circle()
                    .trim(from: 0, to: ringProgress)
                    .stroke(
                        categoryColor,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("\(result.bioAge)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(categoryColor)

                    Text("Bio Age")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Difference badge
            HStack(spacing: 8) {
                Image(systemName: result.category.icon)
                    .font(.headline)
                    .foregroundStyle(categoryColor)

                if result.difference < 0 {
                    Text("\(abs(result.difference)) years younger than calendar age")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                } else if result.difference > 0 {
                    Text("\(result.difference) years older than calendar age")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                } else {
                    Text("Right on track with calendar age")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }
            .foregroundStyle(categoryColor)

            // Category + explanation
            Text(result.category.displayLabel)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(categoryColor, in: Capsule())

            Text(result.explanation)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            Text("Bio Age is an estimate based on fitness metrics, not a medical assessment.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            // Metrics used
            Text("\(result.metricsUsed) of 6 metrics used")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Per-Metric Breakdown

    private var breakdownSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Metric Breakdown", systemImage: "chart.bar.fill")
                .font(.headline)
                .foregroundStyle(.primary)

            ForEach(result.breakdown, id: \.metric) { contribution in
                metricRow(contribution)
            }
        }
    }

    private func metricRow(_ contribution: BioAgeMetricContribution) -> some View {
        let dirColor = directionColor(contribution.direction)

        return HStack(spacing: 14) {
            // Metric icon
            Image(systemName: contribution.metric.icon)
                .font(.title3)
                .foregroundStyle(dirColor)
                .frame(width: 36, height: 36)
                .background(dirColor.opacity(0.1), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(contribution.metric.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                HStack(spacing: 8) {
                    Text("You: \(formattedValue(contribution.value, metric: contribution.metric))")
                        .font(.caption)
                        .foregroundStyle(.primary)

                    Text("Typical for age: \(formattedValue(contribution.expectedValue, metric: contribution.metric))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Age offset
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 3) {
                    Image(systemName: directionIcon(contribution.direction))
                        .font(.caption2)
                    Text(offsetLabel(contribution.ageOffset))
                        .font(.caption)
                        .fontWeight(.bold)
                }
                .foregroundStyle(dirColor)

                Text(contribution.direction.rawValue.capitalized)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(contribution.metric.displayName): \(contribution.direction.rawValue). "
            + "Your value \(formattedValue(contribution.value, metric: contribution.metric)), "
            + "typical for age \(formattedValue(contribution.expectedValue, metric: contribution.metric))"
        )
    }

    // MARK: - Tips

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("How to Improve", systemImage: "lightbulb.fill")
                .font(.headline)
                .foregroundStyle(.primary)

            ForEach(tips, id: \.self) { tip in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.caption)
                        .foregroundStyle(Color(hex: 0x3B82F6))
                        .padding(.top, 2)

                    Text(tip)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: 0x3B82F6).opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color(hex: 0x3B82F6).opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private var categoryColor: Color {
        switch result.category {
        case .excellent:  return Color(hex: 0x22C55E)
        case .good:       return Color(hex: 0x0D9488)
        case .onTrack:    return Color(hex: 0x3B82F6)
        case .watchful:   return Color(hex: 0xF59E0B)
        case .needsWork:  return Color(hex: 0xEF4444)
        }
    }

    /// Ring progress — maps difference to 0...1 visual fill.
    private var ringProgress: CGFloat {
        // Map difference from -10...+10 to 1.0...0.0
        let clamped = Double(max(-10, min(10, result.difference)))
        return CGFloat(1.0 - (clamped + 10) / 20.0)
    }

    private func directionColor(_ direction: BioAgeDirection) -> Color {
        switch direction {
        case .younger: return Color(hex: 0x22C55E)
        case .onTrack: return Color(hex: 0x3B82F6)
        case .older:   return Color(hex: 0xF59E0B)
        }
    }

    private func directionIcon(_ direction: BioAgeDirection) -> String {
        switch direction {
        case .younger: return "arrow.down"
        case .onTrack: return "equal"
        case .older:   return "arrow.up"
        }
    }

    private func offsetLabel(_ offset: Double) -> String {
        let abs = abs(offset)
        if abs < 0.5 { return "0 yr" }
        return String(format: "%.1f yr", abs)
    }

    private func formattedValue(_ value: Double, metric: BioAgeMetricType) -> String {
        switch metric {
        case .vo2Max:         return String(format: "%.1f", value)
        case .restingHR:      return "\(Int(value)) bpm"
        case .hrv:            return "\(Int(value)) ms"
        case .sleep:          return String(format: "%.1f hrs", value)
        case .activeMinutes:  return "\(Int(value)) min"
        case .bmi:            return String(format: "%.1f", value)
        }
    }

    /// Context-sensitive tips based on which metrics are pulling older.
    private var tips: [String] {
        var result: [String] = []

        let olderMetrics = self.result.breakdown.filter { $0.direction == .older }
        for contribution in olderMetrics {
            switch contribution.metric {
            case .vo2Max:
                result.append("Regular moderate-intensity cardio is commonly associated with improved fitness scores.")
            case .restingHR:
                result.append("Regular aerobic exercise and managing stress can help lower your resting heart rate over time.")
            case .hrv:
                result.append("Prioritize quality sleep and recovery days to support higher HRV.")
            case .sleep:
                result.append("Aim for 7-9 hours of consistent sleep. A regular bedtime can make a big difference.")
            case .activeMinutes:
                result.append("Try to get at least 150 minutes of moderate activity each week.")
            case .bmi:
                result.append("Small, consistent changes to nutrition and activity levels can improve body composition over time.")
            }
        }

        if result.isEmpty {
            result.append("You're doing great! Keep up your current routine to maintain these results.")
        }

        return result
    }
}

// MARK: - Preview

#Preview("Bio Age Detail") {
    BioAgeDetailSheet(
        result: BioAgeResult(
            bioAge: 28,
            chronologicalAge: 33,
            difference: -5,
            category: .good,
            metricsUsed: 5,
            breakdown: [
                BioAgeMetricContribution(metric: .vo2Max, value: 42.0, expectedValue: 38.0, ageOffset: -2.5, direction: .younger),
                BioAgeMetricContribution(metric: .restingHR, value: 58.0, expectedValue: 65.0, ageOffset: -1.5, direction: .younger),
                BioAgeMetricContribution(metric: .hrv, value: 52.0, expectedValue: 45.0, ageOffset: -1.0, direction: .younger),
                BioAgeMetricContribution(metric: .sleep, value: 6.5, expectedValue: 7.5, ageOffset: 0.8, direction: .older),
                BioAgeMetricContribution(metric: .activeMinutes, value: 45.0, expectedValue: 30.0, ageOffset: -0.8, direction: .younger),
            ],
            explanation: "Your cardio fitness and resting heart rate are pulling your bio age down. Great work!"
        )
    )
}
