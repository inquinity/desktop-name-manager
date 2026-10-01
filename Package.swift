// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "desktop-name-manager",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "DesktopNameCore", targets: ["DesktopNameCore"]),
        .executable(name: "dnm", targets: ["dnm"]),
    ],
    targets: [
        .target(name: "DesktopNameCore"),
        .executableTarget(name: "dnm", dependencies: ["DesktopNameCore"]),
        // Shared by the unit tests and the local snapshot sweep; never shipped.
        .target(name: "DNMTestSupport", dependencies: ["DesktopNameCore"], path: "Tests/DNMTestSupport"),
        .testTarget(name: "DesktopNameCoreTests", dependencies: ["DesktopNameCore", "DNMTestSupport"]),
        .testTarget(name: "SnapshotTests", dependencies: ["DesktopNameCore", "DNMTestSupport"]),
        .testTarget(name: "dnmTests", dependencies: ["dnm"]),
    ]
)
