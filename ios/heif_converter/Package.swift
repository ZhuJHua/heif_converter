// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "heif_converter",
    platforms: [
        .iOS("12.0"),
    ],
    products: [
        .library(name: "heif-converter", targets: ["heif_converter"]),
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
    ],
    targets: [
        .target(
            name: "heif_converter",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
            ],
            path: "Sources/heif_converter"
        ),
    ]
)
