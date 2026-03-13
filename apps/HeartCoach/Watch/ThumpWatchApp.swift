// ThumpWatchApp.swift
// Thump Watch
//
// Watch app entry point. Opens directly into the swipeable insight flow —
// the 5-screen story experience is the primary interaction.
// Platforms: watchOS 10+

import SwiftUI

// MARK: - App Entry Point

/// The main entry point for the Thump watchOS application.
///
/// Opens directly into `WatchInsightFlowView` — the swipeable story
/// cards are the primary watch experience. WatchHomeView is accessible
/// via navigation from the insight flow if needed.
@main
struct ThumpWatchApp: App {

    // MARK: - State Objects

    /// Manages the WCSession lifecycle and phone communication.
    @StateObject private var connectivityService = WatchConnectivityService()

    /// Drives the watch UI state, including assessment display and feedback submission.
    @StateObject private var viewModel = WatchViewModel()

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            WatchInsightFlowView()
                .environmentObject(connectivityService)
                .environmentObject(viewModel)
                .onAppear {
                    viewModel.bind(to: connectivityService)
                }
        }
    }
}
