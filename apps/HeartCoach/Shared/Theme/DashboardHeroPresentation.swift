import Foundation

enum DashboardHeroPresentation {
    static func greetingPrefix(for hour: Int) -> String {
        switch hour {
        case 5..<12:
            return "Good morning"
        case 12..<17:
            return "Good afternoon"
        case 17..<21:
            return "Good evening"
        default:
            return "Good night"
        }
    }

    static func mood(
        assessment: HeartAssessment?,
        readinessScore: Int?,
        hour: Int
    ) -> BuddyMood {
        guard let assessment else {
            return isQuietHours(hour) ? .tired : .content
        }

        let baseMood = BuddyMood.from(
            assessment: assessment,
            readinessScore: readinessScore,
            currentHour: hour
        )

        guard isQuietHours(hour) else {
            return baseMood
        }

        switch baseMood {
        case .stressed:
            return .stressed
        case .tired:
            return .tired
        default:
            return .tired
        }
    }

    static func isQuietHours(_ hour: Int) -> Bool {
        hour >= 21 || hour < 5
    }
}

enum DashboardUITestOverrides {
    static var readinessScore: Int? {
        value(for: "-UITestReadinessScore").flatMap(Int.init)
    }

    static var hour: Int? {
        guard let parsed = value(for: "-UITestHour").flatMap(Int.init),
              (0..<24).contains(parsed) else {
            return nil
        }
        return parsed
    }

    static var useDesignB: Bool {
        CommandLine.arguments.contains("-UITest_UseDesignB")
    }

    private static func value(for flag: String) -> String? {
        guard let index = CommandLine.arguments.firstIndex(of: flag),
              index + 1 < CommandLine.arguments.count else {
            return nil
        }
        return CommandLine.arguments[index + 1]
    }
}
