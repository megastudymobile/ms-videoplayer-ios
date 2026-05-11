// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "KollusSDK",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "KollusSDK", type: .static, targets: ["KollusSDK"])
    ],
    targets: [
        .target(
            name: "KollusSDK",
            path: "Sources/KollusSDK",
            publicHeadersPath: "include/KollusSDK",
            linkerSettings: [
                .linkedFramework("AVFoundation", .when(platforms: [.iOS])),
                .linkedFramework("AVKit", .when(platforms: [.iOS])),
                .linkedFramework("UIKit", .when(platforms: [.iOS]))
            ]
        )
    ]
)
