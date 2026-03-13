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
                "DashboardViewModelTests.swift",
                "HealthDataProviderTests.swift",
                "WatchConnectivityProviderTests.swift",
                "CustomerJourneyTests.swift",
                "DashboardBuddyIntegrationTests.swift",
                "DashboardReadinessIntegrationTests.swift",
                "EngineKPIValidationTests.swift",
                "LegalGateTests.swift",
                "StressViewActionTests.swift",
                "MockProfiles/MockUserProfiles.swift",
                "MockProfiles/MockProfilePipelineTests.swift",
                "Validation/DatasetValidationTests.swift",
                "Validation/Data",
                "Validation/FREE_DATASETS.md",
                "Validation/STRESS_ENGINE_VALIDATION_REPORT.md",
                "EngineTimeSeries",
                "EndToEndBehavioralTests.swift",
                "UICoherenceTests.swift",
                "AlgorithmComparisonTests.swift"
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
