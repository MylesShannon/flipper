// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Flipper",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.10.1"),
    ],
    targets: [
        .target(name: "FlipperCore"),
        .executableTarget(
            name: "Flipper",
            dependencies: ["FlipperCore", .product(name: "Sparkle", package: "Sparkle")]
        ),
        .testTarget(name: "FlipperCoreTests", dependencies: ["FlipperCore"]),
    ],
    swiftLanguageModes: [.v5]
)
