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
                "EngineTimeSeries/TimeSeriesTestInfra.swift",
                "EngineTimeSeries/StressEngineTimeSeriesTests.swift",
                "EngineTimeSeries/HeartTrendEngineTimeSeriesTests.swift",
                "EngineTimeSeries/BioAgeEngineTimeSeriesTests.swift",
                "EngineTimeSeries/ZoneEngineTimeSeriesTests.swift",
                "EngineTimeSeries/CorrelationEngineTimeSeriesTests.swift",
                "EngineTimeSeries/ReadinessEngineTimeSeriesTests.swift",
                "EngineTimeSeries/NudgeGeneratorTimeSeriesTests.swift",
                "EngineTimeSeries/BuddyRecommendationTimeSeriesTests.swift",
                "EngineTimeSeries/CoachingEngineTimeSeriesTests.swift",
                "EndToEndBehavioralTests.swift",
                "UICoherenceTests.swift",
                "AlgorithmComparisonTests.swift",
                "Validation/Data/README.md",
                "Validation/FREE_DATASETS.md"
            ]
        )
    ]
)
