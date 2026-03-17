// RealUserDataLoader+iOS.swift
// Thump iOS
//
// iOS-specific extension adding MockHealthDataProvider integration.
// Kept separate from the Shared loader because MockHealthDataProvider
// is an iOS-only type.
//
// Platforms: iOS 17+

import Foundation

extension RealUserDataLoader {

    /// Create a `MockHealthDataProvider` loaded with real user data.
    /// Drop-in replacement for `HealthKitService` in simulator builds.
    ///
    /// Usage in `ThumpiOSApp.swift`:
    /// ```swift
    /// #if targetEnvironment(simulator)
    /// let provider = RealUserDataLoader.makeProvider(days: 30)
    /// // Pass to DashboardViewModel instead of HealthKitService
    /// #endif
    /// ```
    ///
    /// - Parameter days: Number of historical days to include.
    /// - Returns: A configured `MockHealthDataProvider` with real data
    ///   including all nil fields and gaps from the actual Apple Watch export.
    public static func makeProvider(days: Int = 30) -> MockHealthDataProvider {
        let anchored = loadAnchored(days: days)
        let today = anchored.last ?? HeartSnapshot(date: Date())
        let history = Array(anchored.dropLast())

        return MockHealthDataProvider(
            todaySnapshot: today,
            history: history,
            shouldAuthorize: true
        )
    }
}
