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
            name: "ThumpCore",
            targets: ["ThumpCore"]
        )
    ],
    targets: [
        .target(
            name: "ThumpCore",
            path: "Shared",
            exclude: ["Services/README.md"]
        ),
        .testTarget(
            name: "ThumpCoreTests",
            dependencies: ["ThumpCore"],
            path: "Tests",
            exclude: [
                "DashboardViewModelTests.swift",
                "HealthDataProviderTests.swift",
                "WatchConnectivityProviderTests.swift"
            ]
        )
    ]
)
