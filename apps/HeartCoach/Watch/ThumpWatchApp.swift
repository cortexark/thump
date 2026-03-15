// ThumpWatchApp.swift
// Thump Watch
//
// Watch app entry point. Opens into the insight flow where the
// living face (screen 0) is the hook and data screens are the proof.
// Platforms: watchOS 10+

import SwiftUI

// MARK: - App Entry Point

/// The main entry point for the Thump watchOS application.
///
/// Opens into `WatchInsightFlowView` — the living buddy face is
/// screen 0 (the billboard), followed by data screens that show
/// the engine output backing the buddy's mood.
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
