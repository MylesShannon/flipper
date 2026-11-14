// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Flipper",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "FlipperCore"),
        .executableTarget(name: "Flipper", dependencies: ["FlipperCore"]),
        .testTarget(name: "FlipperCoreTests", dependencies: ["FlipperCore"]),
    ]
)
