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
        // The menu-bar app (spec 014): its logic and SwiftUI views in a library, so they can be tested with the fake
        // wallpaper system, and a thin executable. `dnm` links neither.
        .target(name: "DesktopNameApp", dependencies: ["DesktopNameCore"]),
        .executableTarget(name: "DesktopNameManager", dependencies: ["DesktopNameApp"]),
        // Development only: the editor over a fake wallpaper system and a temporary store (prototype stage 2). No
        // product, so it is never part of a release.
        .executableTarget(name: "EditorPrototype", dependencies: ["DesktopNameApp", "DNMTestSupport"], path: "prototype/editor"),
        // Shared by the unit tests and the local snapshot sweep; never shipped.
        .target(name: "DNMTestSupport", dependencies: ["DesktopNameCore"], path: "Tests/DNMTestSupport"),
        .testTarget(name: "DesktopNameCoreTests", dependencies: ["DesktopNameCore", "DNMTestSupport"]),
        .testTarget(name: "SnapshotTests", dependencies: ["DesktopNameCore", "DNMTestSupport"]),
        .testTarget(name: "dnmTests", dependencies: ["dnm", "DesktopNameCore"]),
        .testTarget(name: "DesktopNameAppTests", dependencies: ["DesktopNameApp", "DesktopNameCore", "DNMTestSupport"]),
    ]
)
