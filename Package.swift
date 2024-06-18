// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let lint = false

var extraDependencies: [Package.Dependency] = []
var extraPlugins: [Target.PluginUsage] = []
if lint {
    extraDependencies = [.package(url: "https://github.com/realm/SwiftLint.git", from: "0.55.1")]
    extraPlugins = [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLint")]
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
    dependencies: [] + extraDependencies,
    targets: [
        .target(
            name: "SwiftRetrier",
            dependencies: [],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency=complete")
            ],
            plugins: [] + extraPlugins
        ),
        .testTarget(
            name: "SwiftRetrierTests",
            dependencies: ["SwiftRetrier"],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency=complete")
            ],
            plugins: [] + extraPlugins
        )
    ],
    swiftLanguageVersions: [.version("5")]
)
