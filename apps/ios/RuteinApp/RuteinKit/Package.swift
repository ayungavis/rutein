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
        .target(name: "RuteinKit"),
        .testTarget(name: "RuteinKitTests", dependencies: ["RuteinKit"]),
    ],
)
