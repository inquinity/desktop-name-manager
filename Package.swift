// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "desktop-name-manager",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "DesktopNameCore", targets: ["DesktopNameCore"]),
        .executable(name: "dnm", targets: ["dnm"]),
    ],
    dependencies: [
        // Exact version, with its revision recorded in Package.resolved; reviewed as part of every release.
        .package(url: "https://github.com/apple/swift-argument-parser", exact: "1.8.2"),
    ],
    targets: [
        .target(name: "DesktopNameCore"),
        .executableTarget(name: "dnm", dependencies: [
            "DesktopNameCore",
            .product(name: "ArgumentParser", package: "swift-argument-parser"),
        ]),
        // Shared by the unit tests and the local snapshot sweep; never shipped.
        .target(name: "DNMTestSupport", dependencies: ["DesktopNameCore"], path: "Tests/DNMTestSupport"),
        .testTarget(name: "DesktopNameCoreTests", dependencies: ["DesktopNameCore", "DNMTestSupport"]),
        .testTarget(name: "SnapshotTests", dependencies: ["DesktopNameCore", "DNMTestSupport"]),
        .testTarget(name: "dnmTests", dependencies: ["dnm"]),
    ]
)
