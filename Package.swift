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
        .testTarget(name: "DesktopNameCoreTests", dependencies: ["DesktopNameCore"]),
        .testTarget(name: "SnapshotTests", dependencies: ["DesktopNameCore"]),
        .testTarget(name: "dnmTests", dependencies: ["dnm"]),
    ]
)
