// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "DiveCore",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .watchOS(.v10)
    ],
    products: [
        .library(
            name: "DiveCore",
            targets: ["DiveCore"]
        )
    ],
    targets: [
        .target(
            name: "DiveCore",
            path: "Sources/DiveCore"
        ),
        .testTarget(
            name: "DiveCoreTests",
            dependencies: ["DiveCore"],
            path: "Tests/DiveCoreTests"
        )
    ]
)
