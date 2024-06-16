// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let lint = false

var extraDependencies: [Package.Dependency] = []
var extraPlugins: [Target.PluginUsage] = []
if lint {
    extraDependencies = [.package(url: "https://github.com/realm/SwiftLint", exact: "0.52.4")]
    extraPlugins = [.plugin(name: "SwiftLintPlugin", package: "SwiftLint")]
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
            plugins: [] + extraPlugins
        ),
        .testTarget(
            name: "SwiftRetrierTests",
            dependencies: ["SwiftRetrier"],
            plugins: [] + extraPlugins
        )
    ],
    swiftLanguageVersions: [.version("6")]
)
