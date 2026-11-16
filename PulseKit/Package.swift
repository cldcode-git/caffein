// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PulseKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "PulseKit", targets: ["PulseKit"]),
        .library(name: "CaffeineKit", targets: ["CaffeineKit"]),
    ],
    targets: [
        .target(name: "PulseKit"),
        .target(name: "CaffeineKit"),
        .testTarget(name: "PulseKitTests", dependencies: ["PulseKit"]),
        .testTarget(name: "CaffeineKitTests", dependencies: ["CaffeineKit"]),
    ]
)
