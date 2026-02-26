// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let name = "SwiftDependencyUpdater"
let targetDependencyUpdaterName = "DependencyUpdater"
let targetDependencyUpdaterExecutableName = "DependencyUpdaterExecutable"

let products: [Product] = [
    .plugin(
        name: targetDependencyUpdaterName,
        targets: [targetDependencyUpdaterName]
    ),
]

let dependencies: [Package.Dependency] = [
    .package(url: "https://github.com/jpsim/Yams.git", exact: "6.2.1")
]

let targetDependencyUpdaterCoreName = "DependencyUpdaterCore"

let targets: [Target] = [
    .target(
        name: targetDependencyUpdaterCoreName,
        dependencies: [.product(name: "Yams", package: "Yams")],
        path: "Sources/DependencyUpdaterCore"
    ),
    .executableTarget(
        name: targetDependencyUpdaterExecutableName,
        dependencies: [.target(name: targetDependencyUpdaterCoreName)],
        path: "Sources/DependencyUpdaterExecutable"
    ),
    .plugin(
        name: targetDependencyUpdaterName,
        capability: .command(
            intent: .custom(
                verb: "update-dependencies",
                description: "Update Package.swift & pbxproj from Dependencies/dependencies.yaml"
            ),
            permissions: [
                .writeToPackageDirectory(reason: "This command updates the Package.swift files")
            ]
        ),
        dependencies: [.target(name: targetDependencyUpdaterExecutableName)],
        path: "Sources/DependencyUpdater/Plugins"
    ),
    .testTarget(
        name: "DependencyUpdaterTests",
        dependencies: [.target(name: targetDependencyUpdaterCoreName)],
        path: "Tests/DependencyUpdaterTests"
    )
]

let package = Package(
    name: name,
    platforms: [.macOS(.v13)],
    products: products,
    dependencies: dependencies,
    targets: targets
)
