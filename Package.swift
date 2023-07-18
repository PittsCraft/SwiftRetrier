// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftRetrier",
    platforms: [
        .iOS(.v14),
        .macOS(.v11)
    ],
    products: [
        .library(
            name: "SwiftRetrier",
            targets: ["SwiftRetrier"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "SwiftRetrier",
            dependencies: []),
        .testTarget(
            name: "SwiftRetrierTests",
            dependencies: ["SwiftRetrier"]),
    ]
)
