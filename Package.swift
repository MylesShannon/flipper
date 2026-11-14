// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Flipper",
    platforms: [.macOS(.v15)],
    targets: [
        .target(name: "FlipperCore"),
        .executableTarget(name: "Flipper", dependencies: ["FlipperCore"]),
        .testTarget(name: "FlipperCoreTests", dependencies: ["FlipperCore"]),
    ],
    swiftLanguageModes: [.v5]
)
