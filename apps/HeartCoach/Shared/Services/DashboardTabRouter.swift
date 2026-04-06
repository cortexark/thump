// DashboardTabRouter.swift
// ThumpCore
//
// Centralizes dashboard navigation intents so layout changes do not break
// dashboard card taps or deep links.

import Foundation

public enum DashboardTabDestination: Equatable, Sendable {
    case insights
    case stress
    case trends
    case settings
}

public enum DashboardTabRouter {

    public static func tabIndex(
        for destination: DashboardTabDestination,
        useNewTabLayout: Bool
    ) -> Int {
        if useNewTabLayout {
            switch destination {
            case .insights, .stress, .trends:
                return 1
            case .settings:
                return 2
            }
        }

        switch destination {
        case .insights:
            return 1
        case .stress:
            return 2
        case .trends:
            return 3
        case .settings:
            return 4
        }
    }

    public static func destination(for category: NudgeCategory) -> DashboardTabDestination {
        switch category {
        case .rest, .breathe, .seekGuidance:
            return .stress
        case .walk, .moderate, .intensity:
            return .trends
        case .hydrate, .sunlight, .celebrate:
            return .insights
        }
    }
}
