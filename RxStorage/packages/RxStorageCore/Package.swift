// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "RxStorageCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "RxStorageCore",
            targets: ["RxStorageCore"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.0"),
        .package(url: "https://github.com/apple/swift-testing.git", branch: "main"),
        // OpenAPI Generator
        .package(url: "https://github.com/apple/swift-openapi-generator.git", from: "1.4.0"),
        .package(url: "https://github.com/apple/swift-openapi-runtime.git", from: "1.6.0"),
        .package(url: "https://github.com/apple/swift-openapi-urlsession.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-http-types.git", from: "1.3.0"),
        // Swift Syntax for macros
        .package(url: "https://github.com/swiftlang/swift-syntax.git", exact: "604.0.0-prerelease-2026-01-20"),
    ],
    targets: [
        // Macro implementation (compiler plugin)
        .macro(
            name: "RxStorageCoreMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ],
            path: "Sources/RxStorageCoreMacros"
        ),
        .target(
            name: "RxStorageCore",
            dependencies: [
                "RxStorageCoreMacros",
                .product(name: "Logging", package: "swift-log"),
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "OpenAPIURLSession", package: "swift-openapi-urlsession"),
                .product(name: "HTTPTypes", package: "swift-http-types"),
            ],
            path: "Sources/RxStorageCore",
            plugins: [
                .plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator"),
            ]
        ),
        .testTarget(
            name: "RxStorageCoreTests",
            dependencies: [
                "RxStorageCore",
                "RxStorageCoreMacros",
                .product(name: "Testing", package: "swift-testing"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ],
            path: "Tests"
        ),
    ]
)
