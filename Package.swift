// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OwnSpace",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "ownspace", targets: ["OwnSpace"]),
    ],
    targets: [
        // Finding, sizing and removing junk. No UI, so it can be tested on its own.
        .target(name: "OwnSpaceCore"),
        .executableTarget(name: "OwnSpace", dependencies: ["OwnSpaceCore"]),
        .testTarget(name: "OwnSpaceCoreTests", dependencies: ["OwnSpaceCore"]),
    ]
)
