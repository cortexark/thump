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
            path: "Shared"
        ),
        .testTarget(
            name: "ThumpCoreTests",
            dependencies: ["ThumpCore"],
            path: "Tests"
        )
    ]
)
