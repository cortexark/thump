// ThumpiOSApp.swift
// Thump iOS
//
// App entry point for the Thump iOS application. Initializes all
// core services as @StateObject dependencies, injects them into the
// environment, and routes between onboarding and the main tab view
// based on the user's profile state.
// Platforms: iOS 17+

import SwiftUI
import FirebaseCore

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

    /// Centralized engine coordinator shared by all view models (Phase 2).
    @StateObject var coordinator = DailyEngineCoordinator()

    // MARK: - Initialization

    init() {
        Self.configureFirebase()

        let store = LocalStore()
        _localStore = StateObject(wrappedValue: store)
        _notificationService = StateObject(wrappedValue: NotificationService(localStore: store))
    }

    private static func configureFirebase() {
        guard let options = FirebaseOptions.defaultOptions() else {
            FirebaseApp.configure()
            return
        }

        if let bundleID = Bundle.main.bundleIdentifier,
           options.bundleID != bundleID {
            options.bundleID = bundleID
        }

        FirebaseApp.configure(options: options)
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
                .environmentObject(coordinator)
                .task {
                    guard !isRunningTests else { return }
                    await performStartupTasks()
                }
        }
    }

    // MARK: - Authentication & Legal State

    /// Tracks whether the user has signed in with Apple.
    @AppStorage("thump_signed_in") private var isSignedIn: Bool = false

    /// Tracks whether the user has accepted the Terms of Service and Privacy Policy.
    @AppStorage("thump_legal_accepted_v1") private var legalAccepted: Bool = false

    /// Whether to show the launch congratulations screen after first sign-in.
    @AppStorage("thump_launch_congrats_shown") private var launchCongratsShown: Bool = false

    // MARK: - Root View Routing

    /// Routes through: Sign In → Legal Gate → Onboarding → Main Tab View.
    /// Whether the app is running in UI test mode (launched with `-UITestMode`).
    /// Phase 3: Granular UI test flags replace the binary -UITestMode bypass.
    /// Tests can now selectively control each gate for proper funnel testing.
    private var isUITestMode: Bool {
        CommandLine.arguments.contains("-UITestMode")
    }

    private var uiTestSignedIn: Bool {
        CommandLine.arguments.contains("-UITest_SignedIn")
    }

    private var uiTestLegalAccepted: Bool {
        CommandLine.arguments.contains("-UITest_LegalAccepted")
    }

    private var uiTestOnboardingComplete: Bool {
        CommandLine.arguments.contains("-UITest_OnboardingComplete")
    }

    /// Whether the app is running under XCTest host execution.
    private var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    @ViewBuilder
    private var rootView: some View {
        if isUITestMode {
            // Legacy full bypass — use granular flags for new tests
            MainTabView()
        } else if uiTestSignedIn && uiTestLegalAccepted && uiTestOnboardingComplete {
            // Granular: all gates passed
            MainTabView()
        } else if uiTestSignedIn && uiTestLegalAccepted && !uiTestOnboardingComplete {
            // Granular: test onboarding flow
            OnboardingView()
        } else if uiTestSignedIn && !uiTestLegalAccepted {
            // Granular: test legal gate flow
            LegalGateView { legalAccepted = true }
        } else if !isSignedIn {
            AppleSignInView {
                // Record launch free year start date on first sign-in
                if localStore.profile.launchFreeStartDate == nil {
                    localStore.profile.launchFreeStartDate = Date()
                    localStore.saveProfile()
                }
                isSignedIn = true
            }
        } else if !launchCongratsShown && localStore.profile.isInLaunchFreeYear {
            LaunchCongratsView {
                launchCongratsShown = true
            }
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

        // P1 fix: Only request notification permission after onboarding completes.
        // Requesting at cold start before user context is a P2 UX issue —
        // users should understand the app's value before granting permissions.
        if localStore.profile.onboardingComplete {
            Task(priority: .utility) {
                do {
                    try await notificationService.requestAuthorization()
                } catch {
                    AppLogger.info("Notification authorization request failed: \(error.localizedDescription)")
                }
            }
        }

        #if !DEBUG
        // PERF: Run credential validity check in parallel with subscription sync.
        let credentialTask: Task<Bool, Never>? = isSignedIn
            ? Task(priority: .utility) { await AppleSignInService.isCredentialValid() }
            : nil
        #endif

        // Configure engine telemetry for quality baselining
        EngineTelemetryService.shared.configureUserId()
        Analytics.shared.register(provider: FirestoreAnalyticsProvider())

        // Start MetricKit crash reporting and performance monitoring
        MetricKitService.shared.start()

        // PERF-2: Product catalog loading deferred to PaywallView.
        // Only entitlement status is needed at launch to gate features.
        await subscriptionService.updateSubscriptionStatus()

        // Verify Apple Sign-In credential is still valid.
        #if !DEBUG
        if let credentialTask, await !credentialTask.value {
            await MainActor.run { isSignedIn = false }
            AppLogger.info("Apple Sign-In credential revoked — returning to sign-in")
        }
        #endif

        // Sync subscription tier to local store
        await MainActor.run {
            if localStore.profile.isInLaunchFreeYear {
                // Launch promotion: grant full Coach access for the first year
                subscriptionService.currentTier = .coach
                localStore.tier = .coach
                localStore.saveTier()
                AppLogger.info("Launch free year active — Coach tier granted (\(localStore.profile.launchFreeDaysRemaining) days remaining)")
            } else {
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
        }

        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        AppLogger.info("Startup tasks completed in \(String(format: "%.0f", elapsed))ms")
    }
}
