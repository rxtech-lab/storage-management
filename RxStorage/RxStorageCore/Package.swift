// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RxStorageCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "RxStorageCore",
            targets: ["RxStorageCore"])
    ],
    dependencies: [
        // No external dependencies - using Apple frameworks only
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        .target(
            name: "RxStorageCore",
            dependencies: [],
            path: "Sources"
        ),
        .testTarget(
            name: "RxStorageCoreTests",
            dependencies: ["RxStorageCore"],
            path: "Tests"
        ),
    ]
)
