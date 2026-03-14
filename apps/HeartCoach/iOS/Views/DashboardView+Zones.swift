// DashboardView+Zones.swift
// Thump iOS
//
// Heart Rate Zone Distribution section — extracted from DashboardView for readability.

import SwiftUI

extension DashboardView {

    // MARK: - Zone Distribution (Dynamic Targets)

    static let zoneColors: [Color] = [
        Color(hex: 0x94A3B8), // Zone 1 - Easy (gray-blue)
        Color(hex: 0x22C55E), // Zone 2 - Fat Burn (green)
        Color(hex: 0x3B82F6), // Zone 3 - Cardio (blue)
        Color(hex: 0xF59E0B), // Zone 4 - Threshold (amber)
        Color(hex: 0xEF4444)  // Zone 5 - Peak (red)
    ]
    static let zoneNames = ["Easy", "Fat Burn", "Cardio", "Threshold", "Peak"]

    @ViewBuilder
    var zoneDistributionSection: some View {
        if let zoneAnalysis = viewModel.zoneAnalysis,
           let snapshot = viewModel.todaySnapshot {
            let pillars = zoneAnalysis.pillars
            let totalMin = snapshot.zoneMinutes.reduce(0, +)
            let metCount = pillars.filter { $0.completion >= 1.0 }.count

            VStack(alignment: .leading, spacing: 14) {
                // Header with targets-met counter
                HStack {
                    Label("Heart Rate Zones", systemImage: "chart.bar.fill")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    HStack(spacing: 4) {
                        Text("\(metCount)/\(pillars.count) targets")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .fontDesign(.rounded)
                        if metCount == pillars.count && !pillars.isEmpty {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundStyle(Color(hex: 0xF59E0B))
                        }
                    }
                    .foregroundStyle(metCount == pillars.count && !pillars.isEmpty
                                     ? Color(hex: 0x22C55E) : .secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(
                            metCount == pillars.count && !pillars.isEmpty
                                ? Color(hex: 0x22C55E).opacity(0.12)
                                : Color(.systemGray5)
                        )
                    )
                }

                // Per-zone rows with progress bars
                ForEach(Array(pillars.enumerated()), id: \.offset) { index, pillar in
                    let color = index < Self.zoneColors.count ? Self.zoneColors[index] : .gray
                    let name = index < Self.zoneNames.count ? Self.zoneNames[index] : "Zone \(index + 1)"
                    let met = pillar.completion >= 1.0
                    let progress = min(pillar.completion, 1.0)

                    VStack(spacing: 6) {
                        HStack {
                            // Zone name + icon
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(color)
                                    .frame(width: 8, height: 8)
                                Text(name)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.primary)
                            }

                            Spacer()

                            // Actual / Target
                            HStack(spacing: 2) {
                                Text("\(Int(pillar.actualMinutes))")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .fontDesign(.rounded)
                                    .foregroundStyle(met ? color : .primary)
                                Text("/")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                Text("\(Int(pillar.targetMinutes)) min")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            // Checkmark or remaining
                            if met {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(color)
                            }
                        }

                        // Progress bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(color.opacity(0.12))
                                    .frame(height: 6)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(color)
                                    .frame(width: max(0, geo.size.width * CGFloat(progress)), height: 6)
                            }
                        }
                        .frame(height: 6)
                    }
                    .accessibilityLabel(
                        "\(name): \(Int(pillar.actualMinutes)) of \(Int(pillar.targetMinutes)) minutes\(met ? ", target met" : "")"
                    )
                }

                // Coaching nudge per zone (show the most important one)
                if let rec = zoneAnalysis.recommendation {
                    HStack(spacing: 6) {
                        Image(systemName: rec.icon)
                            .font(.caption)
                            .foregroundStyle(rec == .perfectBalance ? Color(hex: 0x22C55E) : Color(hex: 0x3B82F6))
                        Text(zoneCoachingNudge(rec, pillars: pillars))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill((rec == .perfectBalance ? Color(hex: 0x22C55E) : Color(hex: 0x3B82F6)).opacity(0.06))
                    )
                }

                // Weekly activity target (AHA 150 min guideline)
                let moderateMin = snapshot.zoneMinutes.count >= 4 ? snapshot.zoneMinutes[2] + snapshot.zoneMinutes[3] : 0
                let vigorousMin = snapshot.zoneMinutes.count >= 5 ? snapshot.zoneMinutes[4] : 0
                let weeklyEstimate = (moderateMin + vigorousMin * 2) * 7
                let ahaPercent = min(weeklyEstimate / 150.0 * 100, 100)
                HStack(spacing: 6) {
                    Image(systemName: ahaPercent >= 100 ? "checkmark.circle.fill" : "circle.dashed")
                        .font(.caption)
                        .foregroundStyle(ahaPercent >= 100 ? Color(hex: 0x22C55E) : Color(hex: 0xF59E0B))
                    Text(ahaPercent >= 100
                         ? "On pace for 150 min weekly activity goal"
                         : "\(Int(max(0, 150 - weeklyEstimate))) min to your weekly activity target")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .accessibilityIdentifier("dashboard_zone_card")
        }
    }

    /// Context-aware coaching nudge based on zone recommendation.
    func zoneCoachingNudge(_ rec: ZoneRecommendation, pillars: [ZonePillar]) -> String {
        switch rec {
        case .perfectBalance:
            return "Great balance today! You're hitting all zone targets."
        case .needsMoreActivity:
            return "A 15-minute walk gets you into your fat-burn and cardio zones."
        case .needsMoreAerobic:
            let cardio = pillars.first { $0.zone == .aerobic }
            let remaining = Int(max(0, (cardio?.targetMinutes ?? 22) - (cardio?.actualMinutes ?? 0)))
            return "\(remaining) more min of cardio (brisk walk or jog) to hit your target."
        case .needsMoreThreshold:
            let threshold = pillars.first { $0.zone == .threshold }
            let remaining = Int(max(0, (threshold?.targetMinutes ?? 7) - (threshold?.actualMinutes ?? 0)))
            return "\(remaining) more min of tempo effort to reach your threshold target."
        case .tooMuchIntensity:
            return "You've pushed hard. Try easy zone only for the rest of today."
        }
    }
}
