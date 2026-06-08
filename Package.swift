// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "videoplayer-ios-ms",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "VideoPlayerCore",
            targets: ["VideoPlayerCore"]
        ),
        .library(
            name: "VideoPlayerShellSupport",
            targets: ["VideoPlayerShellSupport"]
        ),
        .library(
            name: "VideoPlayerEngineNative",
            targets: ["VideoPlayerEngineNative"]
        ),
        .library(
            name: "VideoPlayerEngineKollus",
            targets: ["VideoPlayerEngineKollus"]
        ),
        .library(
            name: "VideoPlayerSkin",
            targets: ["VideoPlayerSkin"]
        )
    ],
    targets: [
        .target(
            name: "VideoPlayerCore",
            path: "Sources/VideoPlayerCore"
        ),
        .target(
            name: "VideoPlayerShellSupport",
            dependencies: ["VideoPlayerCore"],
            path: "Sources/VideoPlayerShellSupport",
            linkerSettings: [
                .linkedFramework("AVFoundation", .when(platforms: [.iOS])),
                .linkedFramework("UIKit", .when(platforms: [.iOS]))
            ]
        ),
        .target(
            name: "VideoPlayerEngineNative",
            dependencies: ["VideoPlayerShellSupport"],
            path: "Sources/VideoPlayerEngineNative",
            linkerSettings: [
                .linkedFramework("AVFoundation", .when(platforms: [.iOS])),
                .linkedFramework("UIKit", .when(platforms: [.iOS]))
            ]
        ),
        .target(
            name: "VideoPlayerEngineKollus",
            dependencies: [
                "VideoPlayerShellSupport",
                "VideoPlayerKollusBinary",
                "VideoPlayerPallyConBinary"
            ],
            path: "Sources/VideoPlayerEngineKollus",
            // KollusSDK(정적 lib xcframework)는 리소스를 실을 수 없어 SDK의 개인정보
            // 매니페스트를 이 타겟 리소스로 동봉한다 → 앱 번들에 PrivacyInfo.xcprivacy 포함
            // → Apple App Store 개인정보 보고서 집계 대상이 된다.
            resources: [
                .process("Resources/PrivacyInfo.xcprivacy")
            ],
            linkerSettings: [
                .linkedFramework("UIKit",               .when(platforms: [.iOS])),
                .linkedFramework("AVFoundation",        .when(platforms: [.iOS])),
                .linkedFramework("CoreMedia",           .when(platforms: [.iOS])),
                .linkedFramework("QuartzCore",          .when(platforms: [.iOS])),
                .linkedFramework("AudioToolbox",        .when(platforms: [.iOS])),
                .linkedFramework("MediaPlayer",         .when(platforms: [.iOS])),
                .linkedFramework("Security",            .when(platforms: [.iOS])),
                .linkedFramework("SystemConfiguration", .when(platforms: [.iOS])),
                .linkedFramework("CoreGraphics",        .when(platforms: [.iOS])),
                .linkedLibrary("sqlite3",               .when(platforms: [.iOS])),
                .linkedLibrary("iconv",                 .when(platforms: [.iOS])),
                .linkedLibrary("z",                     .when(platforms: [.iOS])),
                .linkedLibrary("c++",                   .when(platforms: [.iOS]))
            ]
        ),
        // spec-064 — 재사용 가능한 재생기 skin (Rx/ReactorKit/SnapKit 의존 없음).
        // 엔진은 host 가 조립한 PlayerModule 을 주입 → EngineNative/Kollus 의존 불필요.
        .target(
            name: "VideoPlayerSkin",
            dependencies: [
                "VideoPlayerCore",
                "VideoPlayerShellSupport"
            ],
            path: "Sources/VideoPlayerSkin",
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .linkedFramework("UIKit", .when(platforms: [.iOS])),
                .linkedFramework("AVFoundation", .when(platforms: [.iOS])),
                .linkedFramework("MediaPlayer", .when(platforms: [.iOS]))
            ]
        ),
        .binaryTarget(
            name: "VideoPlayerKollusBinary",
            path: "Binaries/KollusSDK.xcframework"
        ),
        .binaryTarget(
            name: "VideoPlayerPallyConBinary",
            path: "Binaries/PallyConFPSSDK.xcframework"
        ),
        .testTarget(
            name: "VideoPlayerModuleTests",
            dependencies: [
                "VideoPlayerCore",
                .target(name: "VideoPlayerShellSupport", condition: .when(platforms: [.iOS])),
                .target(name: "VideoPlayerEngineNative", condition: .when(platforms: [.iOS])),
                .target(name: "VideoPlayerEngineKollus", condition: .when(platforms: [.iOS])),
                .target(name: "VideoPlayerSkin", condition: .when(platforms: [.iOS]))
            ],
            path: "Tests/VideoPlayerModuleTests"
        )
    ]
)
