// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "JsonSchemaEditor",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "JsonSchemaEditor",
            targets: ["JsonSchemaEditor"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/nalexn/ViewInspector.git", from: "0.10.0"),
        .package(url: "https://github.com/sirily11/swift-json-schema.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "JsonSchemaEditor",
            dependencies: [
                .product(name: "JSONSchema", package: "swift-json-schema"),
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "JsonSchemaEditorTests",
            dependencies: [
                "JsonSchemaEditor",
                "ViewInspector",
            ],
            path: "Tests"
        ),
    ]
)
