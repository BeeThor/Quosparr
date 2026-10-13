// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Quosparr",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v12),
    ],
    products: [
        .executable(name: "Quosparr", targets: ["Quosparr"]),
        .executable(name: "QuosparrCostBenchmark", targets: ["QuosparrCostBenchmark"]),
        .library(name: "QuosparrCore", targets: ["QuosparrCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.9.3"),
    ],
    targets: [
        .target(
            name: "QuosparrCore",
            linkerSettings: [
                .linkedLibrary("sqlite3"),
            ]),
        .target(
            name: "QuosparrWidget",
            dependencies: ["QuosparrCore"],
            resources: [.process("Resources")]),
        .executableTarget(
            name: "Quosparr",
            dependencies: [
                "QuosparrCore",
                .product(name: "Sparkle", package: "Sparkle"),
            ]),
        .executableTarget(
            name: "QuosparrCostBenchmark",
            dependencies: ["QuosparrCore"]),
        .testTarget(
            name: "QuosparrCoreTests",
            dependencies: ["QuosparrCore"]),
        .testTarget(
            name: "QuosparrTests",
            dependencies: ["Quosparr", "QuosparrCore", "QuosparrWidget"]),
    ])
