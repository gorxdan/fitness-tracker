// swift-tools-version: 6.0
import PackageDescription

/// Platform-free core: pure Foundation only. Builds on Linux and macOS,
/// so domain logic is compile- and test-verified without Xcode.
/// The app target compiles these same sources (see project.yml).
let package = Package(
    name: "PulseCore",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
    ],
    targets: [
        .target(name: "PulseCore", path: "Sources/PulseCore"),
        .testTarget(name: "PulseCoreTests", dependencies: ["PulseCore"], path: "Tests/PulseCoreTests"),
    ]
)
