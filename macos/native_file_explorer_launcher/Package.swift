// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "native_file_explorer_launcher",
    platforms: [
        .macOS("12.0")
    ],
    products: [
        .library(name: "native-file-explorer-launcher", targets: ["native_file_explorer_launcher"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "native_file_explorer_launcher",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ]
        )
    ]
)
