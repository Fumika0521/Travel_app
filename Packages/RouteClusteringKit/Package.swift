// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "RouteClusteringKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "RouteClusteringKit", targets: ["RouteClusteringKit"])
    ],
    targets: [
        .target(name: "RouteClusteringKit"),
        .testTarget(name: "RouteClusteringKitTests", dependencies: ["RouteClusteringKit"])
    ]
)
