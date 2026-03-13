// ThumpiOSApp.swift
// Thump iOS
//
// App entry point for the Thump iOS application. Initializes all
// core services as @StateObject dependencies, injects them into the
// environment, and routes between onboarding and the main tab view
// based on the user's profile state.
// Platforms: iOS 17+

import SwiftUI

// MARK: - App Entry Point

/// The main entry point for the Thump iOS application.
///
/// Creates and owns all top-level service objects as `@StateObject`
/// instances, ensuring they persist for the lifetime of the app.
/// Injects services into the SwiftUI environment for access by
/// child views and view models.
///
/// Routing logic:
/// - If the user has not completed onboarding, `OnboardingView` is shown.
/// - Otherwise, `MainTabView` is presented as the root navigation.
@main
struct ThumpiOSApp: App {

    // MARK: - Service Dependencies

    /// HealthKit data access and metric query service.
    @StateObject var healthKitService = HealthKitService()

    /// StoreKit 2 subscription management service.
    @StateObject var subscriptionService = SubscriptionService()

    /// iOS-side WatchConnectivity service for watch communication.
    @StateObject var connectivityService = ConnectivityService()

    /// UserDefaults-backed local persistence for profile, history, and settings.
    @StateObject var localStore: LocalStore

    /// Local notification service for anomaly alerts and nudge reminders (CR-001).
    /// Shares the root `localStore` so alert-budget state is owned by one persistence object.
    @StateObject var notificationService: NotificationService

    // MARK: - Initialization

    init() {
        let store = LocalStore()
        _localStore = StateObject(wrappedValue: store)
        _notificationService = StateObject(wrappedValue: NotificationService(localStore: store))
    }

    // MARK: - Scene

    var body: some Scene {
        WindowGroup {
            rootView
                .environmentObject(healthKitService)
                .environmentObject(subscriptionService)
                .environmentObject(connectivityService)
                .environmentObject(localStore)
                .environmentObject(notificationService)
                .task {
                    await performStartupTasks()
                }
        }
    }

    // MARK: - Legal Acceptance State

    /// Tracks whether the user has accepted the Terms of Service and Privacy Policy.
    @AppStorage("thump_legal_accepted_v1") private var legalAccepted: Bool = false

    // MARK: - Root View Routing

    /// Routes to legal gate, onboarding, or main tab view based on
    /// the user's acceptance and onboarding state.
    /// Whether the app is running in UI test mode (launched with `-UITestMode`).
    private var isUITestMode: Bool {
        CommandLine.arguments.contains("-UITestMode")
    }

    @ViewBuilder
    private var rootView: some View {
        if isUITestMode {
            // Skip legal gate and onboarding for UI tests
            MainTabView()
        } else if !legalAccepted {
            LegalGateView {
                legalAccepted = true
            }
        } else if localStore.profile.onboardingComplete {
            MainTabView()
        } else {
            OnboardingView()
        }
    }

    // MARK: - Startup Tasks

    /// Performs asynchronous initialization tasks when the app launches.
    ///
    /// - Loads available subscription products from the App Store.
    /// - Updates the current subscription status from StoreKit.
    /// - Syncs the subscription tier to the local store.
    private func performStartupTasks() async {
        let startTime = CFAbsoluteTimeGetCurrent()
        AppLogger.info("App launch — starting startup tasks")

        connectivityService.bind(localStore: localStore)

        // Request notification authorization (CR-001)
        do {
            try await notificationService.requestAuthorization()
        } catch {
            AppLogger.info("Notification authorization request failed: \(error.localizedDescription)")
        }

        // Start MetricKit crash reporting and performance monitoring
        MetricKitService.shared.start()

        // Load subscription products and status
        await subscriptionService.loadProducts()
        await subscriptionService.updateSubscriptionStatus()

        // Sync subscription tier to local store
        await MainActor.run {
            #if targetEnvironment(simulator)
            // Force Coach tier in the simulator for full feature access during development
            subscriptionService.currentTier = .coach
            localStore.tier = .coach
            localStore.saveTier()
            #else
            if subscriptionService.currentTier != localStore.tier {
                localStore.tier = subscriptionService.currentTier
                localStore.saveTier()
            }
            #endif
        }

        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        AppLogger.info("Startup tasks completed in \(String(format: "%.0f", elapsed))ms")
    }
}
