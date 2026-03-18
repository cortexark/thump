// DashboardView+Goals.swift
// Thump iOS
//
// Daily Goals section — extracted from DashboardView for readability.

import SwiftUI

extension DashboardView {

    // MARK: - Daily Goals Section

    /// Gamified daily wellness goals with progress rings and celebrations.
    @ViewBuilder
    var dailyGoalsSection: some View {
        if let snapshot = viewModel.todaySnapshot {
            let goals = dailyGoals(from: snapshot)
            let completedCount = goals.filter(\.isComplete).count
            let allComplete = completedCount == goals.count

            VStack(alignment: .leading, spacing: 14) {
                // Header with completion counter
                HStack {
                    Label("Daily Goals", systemImage: "target")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Spacer()

                    HStack(spacing: 4) {
                        Text("\(completedCount)/\(goals.count)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .fontDesign(.rounded)
                            .foregroundStyle(allComplete ? Color(hex: 0x22C55E) : .secondary)

                        if allComplete {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundStyle(Color(hex: 0xF59E0B))
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(
                            allComplete
                                ? Color(hex: 0x22C55E).opacity(0.12)
                                : Color(.systemGray5)
                        )
                    )
                }

                // All-complete celebration banner
                if allComplete {
                    HStack(spacing: 8) {
                        Image(systemName: "party.popper.fill")
                            .font(.subheadline)
                        Text("All goals hit today! Well done.")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(Color(hex: 0x22C55E))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(hex: 0x22C55E).opacity(0.08))
                    )
                }

                // Goal rings row
                HStack(spacing: 0) {
                    ForEach(goals, id: \.label) { goal in
                        goalRingView(goal)
                            .frame(maxWidth: .infinity)
                    }
                }

                // Motivational footer
                if !allComplete {
                    let nextGoal = goals.first(where: { !$0.isComplete })
                    if let next = nextGoal {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.caption)
                                .foregroundStyle(next.color)
                            Text(next.nudgeText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(next.color.opacity(0.06))
                        )
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(
                        allComplete
                            ? Color(hex: 0x22C55E).opacity(0.2)
                            : Color.clear,
                        lineWidth: 1.5
                    )
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "Daily goals: \(completedCount) of \(goals.count) complete. "
                + goals.map { "\($0.label): \($0.isComplete ? "done" : "\(Int($0.progress * 100)) percent")" }.joined(separator: ". ")
            )
            .accessibilityIdentifier("dashboard_daily_goals")
        }
    }

    // MARK: - Goal Ring View

    func goalRingView(_ goal: DailyGoal) -> some View {
        VStack(spacing: 8) {
            ZStack {
                // Background ring
                Circle()
                    .stroke(goal.color.opacity(0.12), lineWidth: 7)
                    .frame(width: 64, height: 64)

                // Progress ring
                Circle()
                    .trim(from: 0, to: min(goal.progress, 1.0))
                    .stroke(
                        goal.isComplete
                            ? goal.color
                            : goal.color.opacity(0.7),
                        style: StrokeStyle(lineWidth: 7, lineCap: .round)
                    )
                    .frame(width: 64, height: 64)
                    .rotationEffect(.degrees(-90))

                // Center content
                if goal.isComplete {
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(goal.color)
                } else {
                    VStack(spacing: 0) {
                        Text(goal.currentFormatted)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                        Text(goal.unit)
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Label + target
            VStack(spacing: 2) {
                Image(systemName: goal.icon)
                    .font(.caption2)
                    .foregroundStyle(goal.color)

                Text(goal.label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.primary)

                Text(goal.targetLabel)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Daily Goal Model

    struct DailyGoal {
        let label: String
        let icon: String
        let current: Double
        let target: Double
        let unit: String
        let color: Color
        let nudgeText: String

        var progress: CGFloat {
            guard target > 0 else { return 0 }
            return CGFloat(current / target)
        }

        var isComplete: Bool { current >= target }

        var currentFormatted: String {
            if current == 0 { return "–" }  // no data yet — show dash instead of "0.0k"
            if target >= 1000 {
                return String(format: "%.1fk", current / 1000)
            }
            return current >= 10 ? "\(Int(current))" : String(format: "%.1f", current)
        }

        var targetLabel: String {
            if target >= 1000 {
                return "\(Int(target / 1000))k goal"
            }
            return "\(Int(target)) \(unit)"
        }
    }

    /// Builds daily goals from today's snapshot data, dynamically adjusted
    /// by readiness, stress, and buddy engine signals.
    /// When coordinator is active, maps GoalSpec from AdviceState.
    func dailyGoals(from snapshot: HeartSnapshot) -> [DailyGoal] {
        // Coordinator path: map GoalSpec → DailyGoal via AdvicePresenter
        if ConfigService.enableCoordinator,
           let adviceState = coordinator.bundle?.adviceState {
            return adviceState.goals.map { spec in
                let (icon, color, unit) = goalVisuals(for: spec.category)
                let current: Double
                switch spec.category {
                case .steps:         current = snapshot.steps ?? 0
                case .activeMinutes: current = (snapshot.walkMinutes ?? 0) + (snapshot.workoutMinutes ?? 0)
                case .sleep:         current = snapshot.sleepHours ?? 0
                case .zone:
                    current = viewModel.zoneAnalysis?.pillars.first { $0.zone == .fatBurn }?.actualMinutes ?? 0
                }
                let goalWithCurrent = GoalSpec(
                    category: spec.category, target: spec.target,
                    current: current, nudgeTextID: spec.nudgeTextID, label: spec.label
                )
                return DailyGoal(
                    label: spec.label,
                    icon: icon,
                    current: current,
                    target: spec.target,
                    unit: unit,
                    color: color,
                    nudgeText: AdvicePresenter.goalNudgeText(for: goalWithCurrent)
                )
            }
        }

        // Legacy path
        var goals: [DailyGoal] = []
        let policy = ConfigService.activePolicy
        let readiness = viewModel.readinessResult
        let stress = viewModel.stressResult

        let baseSteps: Double = 7000
        let stepTarget: Double
        if let r = readiness {
            if r.score >= 80 { stepTarget = Double(policy.goals.stepsPrimed) }
            else if r.score >= 65 { stepTarget = Double(policy.goals.stepsReady) }
            else if r.score >= 45 { stepTarget = Double(policy.goals.stepsModerate) }
            else { stepTarget = Double(policy.goals.stepsRecovering) }
        } else {
            stepTarget = baseSteps
        }

        let steps = snapshot.steps ?? 0
        let stepsRemaining = Int(max(0, stepTarget - steps))
        goals.append(DailyGoal(
            label: "Steps",
            icon: "figure.walk",
            current: steps,
            target: stepTarget,
            unit: "steps",
            color: Color(hex: 0x3B82F6),
            nudgeText: steps >= stepTarget
                ? "Steps goal hit!"
                : (stepsRemaining > Int(stepTarget / 2)
                    ? "A short walk gets you started"
                    : "Just \(stepsRemaining) more steps to go!")
        ))

        let baseActive: Double = 30
        let activeTarget: Double
        if let r = readiness {
            if r.score >= 80 && stress?.level != .elevated { activeTarget = Double(policy.goals.activeMinPrimed) }
            else if r.score >= 65 { activeTarget = Double(policy.goals.activeMinReady) }
            else if r.score >= 45 { activeTarget = Double(policy.goals.activeMinModerate) }
            else { activeTarget = Double(policy.goals.activeMinRecovering) }
        } else {
            activeTarget = baseActive
        }

        let activeMin = (snapshot.walkMinutes ?? 0) + (snapshot.workoutMinutes ?? 0)
        goals.append(DailyGoal(
            label: "Active",
            icon: "flame.fill",
            current: activeMin,
            target: activeTarget,
            unit: "min",
            color: Color(hex: 0xEF4444),
            nudgeText: activeMin >= activeTarget
                ? "Active minutes done!"
                : (activeMin < activeTarget / 2
                    ? "Even 10 minutes of movement counts"
                    : "Almost there — keep moving!")
        ))

        if let sleep = snapshot.sleepHours, sleep > 0 {
            let sleepTarget: Double
            if let r = readiness {
                if r.score < 45 { sleepTarget = policy.goals.sleepTargetRecovering }
                else if r.score < 65 { sleepTarget = policy.goals.sleepTargetModerate }
                else { sleepTarget = policy.goals.sleepTargetReady }
            } else {
                sleepTarget = 7
            }

            let sleepNudge: String
            if let ctx = viewModel.assessment?.recoveryContext {
                sleepNudge = ctx.bedtimeTarget.map { "Bed by \($0) tonight — \(ctx.driver) needs it" }
                    ?? ctx.tonightAction
            } else if sleep < sleepTarget - 1 {
                sleepNudge = "Try winding down 30 min earlier tonight"
            } else if sleep >= sleepTarget {
                sleepNudge = "Great rest! Sleep goal met"
            } else {
                sleepNudge = "Almost there — aim for \(String(format: "%.0f", sleepTarget)) hrs tonight"
            }
            goals.append(DailyGoal(
                label: "Sleep",
                icon: "moon.fill",
                current: sleep,
                target: sleepTarget,
                unit: "hrs",
                color: Color(hex: 0x8B5CF6),
                nudgeText: sleepNudge
            ))
        }

        if let zones = viewModel.zoneAnalysis {
            let zoneTarget: Double
            let zoneName: String
            if let r = readiness, r.score >= 80, stress?.level != .elevated {
                let cardio = zones.pillars.first { $0.zone == .aerobic }
                zoneTarget = cardio?.targetMinutes ?? 22
                zoneName = "Cardio"
            } else if let r = readiness, r.score < 45 {
                let easy = zones.pillars.first { $0.zone == .recovery }
                zoneTarget = easy?.targetMinutes ?? 20
                zoneName = "Easy"
            } else {
                let fatBurn = zones.pillars.first { $0.zone == .fatBurn }
                zoneTarget = fatBurn?.targetMinutes ?? 15
                zoneName = "Fat Burn"
            }

            let zoneActual = zones.pillars
                .first { $0.zone == (readiness?.score ?? 60 >= 80 ? .aerobic : (readiness?.score ?? 60 < 45 ? .recovery : .fatBurn)) }?
                .actualMinutes ?? 0

            goals.append(DailyGoal(
                label: zoneName,
                icon: "heart.circle",
                current: zoneActual,
                target: zoneTarget,
                unit: "min",
                color: Color(hex: 0x0D9488),
                nudgeText: zoneActual >= zoneTarget
                    ? "Zone goal reached!"
                    : "\(Int(max(0, zoneTarget - zoneActual))) min of \(zoneName.lowercased()) to go"
            ))
        }

        return goals
    }

    /// Returns (icon, color, unit) for a goal category.
    private func goalVisuals(for category: GoalSpec.GoalCategory) -> (String, Color, String) {
        switch category {
        case .steps:         return ("figure.walk", Color(hex: 0x3B82F6), "steps")
        case .activeMinutes: return ("flame.fill", Color(hex: 0xEF4444), "min")
        case .sleep:         return ("moon.fill", Color(hex: 0x8B5CF6), "hrs")
        case .zone:          return ("heart.circle", Color(hex: 0x0D9488), "min")
        }
    }
}
