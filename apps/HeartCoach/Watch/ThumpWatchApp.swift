// ThumpWatchApp.swift
// Thump Watch
//
// Watch app entry point. Opens into the insight flow where the
// living face (screen 0) is the hook and data screens are the proof.
// Platforms: watchOS 10+

import SwiftUI
import HealthKit

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
                .task {
                    await requestWatchHealthKitAccess()
                }
        }
    }

    // MARK: - HealthKit Authorization

    /// Requests HealthKit read access for the types queried by the Watch screens.
    /// On watchOS, authorization can be granted independently of the iPhone app.
    /// If the iPhone already authorized these types, this is a no-op.
    private func requestWatchHealthKitAccess() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        // Reuse the shared store from WatchViewModel — Apple recommends
        // a single HKHealthStore instance per app.
        let store = WatchViewModel.sharedHealthStore
        var readTypes = Set<HKObjectType>()

        // Quantity types queried by Watch screens
        let quantityTypes: [HKQuantityTypeIdentifier] = [
            .stepCount,                    // WalkScreen
            .restingHeartRate,             // StressPulseScreen, TrendsScreen
            .heartRate,                    // StressPulseScreen (hourly heatmap)
            .heartRateVariabilitySDNN      // TrendsScreen, WatchViewModel HRV trend
        ]
        for id in quantityTypes {
            if let type = HKQuantityType.quantityType(forIdentifier: id) {
                readTypes.insert(type)
            }
        }

        // Category types
        if let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) {
            readTypes.insert(sleepType)    // SleepScreen
        }

        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
        } catch {
            AppLogger.healthKit.error("Watch HealthKit authorization failed: \(error.localizedDescription)")
        }
    }
}
