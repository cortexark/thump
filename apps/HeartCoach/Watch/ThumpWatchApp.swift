// ThumpWatchApp.swift
// Thump Watch
//
// Watch app entry point. Initializes connectivity and view model services,
// then presents the main watch home view.
// Platforms: watchOS 10+

import SwiftUI

// MARK: - App Entry Point

/// The main entry point for the Thump watchOS application.
///
/// Instantiates the `WatchConnectivityService` for phone communication
/// and the `WatchViewModel` for UI state management, injecting both
/// into the SwiftUI environment for all child views.
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
            WatchHomeView()
                .environmentObject(connectivityService)
                .environmentObject(viewModel)
                .onAppear {
                    viewModel.bind(to: connectivityService)
                }
        }
    }
}
