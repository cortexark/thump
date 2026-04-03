// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Thump",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "Thump",
            targets: ["Thump"]
        )
    ],
    targets: [
        .target(
            name: "Thump",
            path: "Shared",
            exclude: ["Services/README.md"]
        ),
        .testTarget(
            name: "ThumpTests",
            dependencies: ["Thump"],
            path: "Tests",
            exclude: [
                // iOS-only tests (need DashboardViewModel, StressViewModel, etc.)
                "DashboardViewModelTests.swift",
                "HealthDataProviderTests.swift",
                "WatchConnectivityProviderTests.swift",
                "CustomerJourneyTests.swift",
                "DashboardBuddyIntegrationTests.swift",
                "DashboardReadinessIntegrationTests.swift",
                "StressViewActionTests.swift",
                "SimulatorFallbackAndActionBugTests.swift",
                // iOS-only (uses LegalDocument from iOS/Views)
                "LegalGateTests.swift",
                // Empty MockProfiles dir (files moved to EngineTimeSeries)
                "MockProfiles",
                // Dataset validation (needs external CSV files)
                "Validation/DatasetValidationTests.swift",
                "Validation/Data",
                "Validation/FREE_DATASETS.md",
                "Validation/STRESS_ENGINE_VALIDATION_REPORT.md",
                // SIGSEGV in testFullComparisonSummary (String(format: "%s") crash)
                "AlgorithmComparisonTests.swift",
                // EngineTimeSeries has its own target (ThumpTimeSeriesTests)
                "EngineTimeSeries",
                // Firebase integration tests (need Firestore SDK, not in SPM target)
                "BugReportFirestoreTests.swift",
                "FeedbackFirestoreTests.swift",
                "FirestoreTelemetryIntegrationTests.swift",
                // Super Reviewer (needs Claude CLI + judge infrastructure)
                "SuperReviewer",
                // Proactive notifications (needs UNUserNotificationCenter, iOS-only)
                "ProactiveNotificationTests.swift",
                // Advice presenter copy fit (needs iOS Views)
                "AdvicePresenterCopyFitTests.swift"
            ]
        ),
        // TEST-3: Engine time-series validation suite (280 checkpoints).
        // Run with: swift test --filter ThumpTimeSeriesTests
        .testTarget(
            name: "ThumpTimeSeriesTests",
            dependencies: ["Thump"],
            path: "Tests/EngineTimeSeries",
            exclude: [
                "Results"
            ]
        )
    ]
)
