// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "TwtVisitorSDK",
    platforms: [.iOS(.v15), .macOS(.v10_15)],
    products: [
        .library(name: "TwtVisitorSDK", targets: ["TwtVisitorSDK"]),
    ],
    targets: [
        .target(name: "TwtVisitorSDK"),
    ]
)
