// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let lint = false

var dependencies: [Package.Dependency] = []
var plugins: [Target.PluginUsage] = []
if lint {
    dependencies = [.package(url: "https://github.com/realm/SwiftLint", exact: "0.52.4")]
    plugins = [.plugin(name: "SwiftLintPlugin", package: "SwiftLint")]
}

let package = Package(
    name: "SwiftRetrier",
    platforms: [
        .iOS(.v14),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "SwiftRetrier",
            targets: ["SwiftRetrier"])
    ],
    dependencies: dependencies,
    targets: [
        .target(
            name: "SwiftRetrier",
            dependencies: [],
            plugins: plugins
        ),
        .testTarget(
            name: "SwiftRetrierTests",
            dependencies: ["SwiftRetrier"],
            plugins: plugins
        )
    ]
)
