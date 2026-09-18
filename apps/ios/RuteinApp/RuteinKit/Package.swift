// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "RuteinKit",
    defaultLocalization: "en",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "RuteinKit", targets: ["RuteinKit"]),
    ],
    targets: [
        .target(
            name: "RuteinKit",
            resources: [.process("Resources"), .process("DesignSystem/Resources")],
            swiftSettings: [.enableUpcomingFeature("NonisolatedNonsendingByDefault")],
        ),
        .testTarget(
            name: "RuteinKitTests",
            dependencies: ["RuteinKit"],
            resources: [.process("Fixtures")],
            swiftSettings: [.enableUpcomingFeature("NonisolatedNonsendingByDefault")],
        ),
    ],
)
