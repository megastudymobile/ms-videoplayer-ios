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
            name: "VideoPlayerModule",
            targets: ["VideoPlayerModule"]
        ),
        .library(
            name: "VideoPlayerSkin",
            targets: ["VideoPlayerSkin"]
        )
    ],
    targets: [
        .target(
            name: "VideoPlayerCore",
            path: "Sources/VideoPlayerModule",
            sources: [
                "Core/Domain/Bookmark.swift",
                "Core/Domain/NextEpisodeInfo.swift",
                "Core/Domain/PlaybackCommand.swift",
                "Core/Domain/PlaybackSource.swift",
                "Core/Domain/PlaybackState.swift",
                "Core/Domain/PlayerCaption.swift",
                "Core/Domain/PlayerError.swift",
                "Core/Domain/PlayerEvent.swift",
                "Core/Domain/PlayerFeaturePolicy.swift",
                "Core/Domain/PlayerCapabilities.swift",
                "Core/Domain/PlayerFeatureSet.swift",
                "Core/Domain/PlayerIdentity.swift",
                "Core/Domain/PlayerStateSnapshot.swift",
                "Core/Domain/StreamInfo.swift",
                "Core/Internal/PlayerCore.swift",
                "Core/UseCase/ControlPlaybackUseCase.swift",
                "Core/UseCase/ObservePlaybackStateUseCase.swift",
                "Core/UseCase/StartPlaybackUseCase.swift",
                "Engine/PlayerEngineAdapter.swift"
            ]
        ),
        .target(
            name: "VideoPlayerShellSupport",
            dependencies: ["VideoPlayerCore"],
            path: "Sources/VideoPlayerModule",
            sources: [
                "ShellSupport/PlayerAudioSessionManager.swift",
                "ShellSupport/PlayerError+NSError.swift",
                "ShellSupport/PlayerLifecycleCoordinator.swift",
                "ShellSupport/PlayerModuleConfiguration.swift",
                "ShellSupport/PlayerModuleWiring.swift",
                "ShellSupport/PlayerRenderBindingEngine.swift",
                "ShellSupport/PlayerRenderSurface.swift",
                "ShellSupport/PlayerStateBinder.swift"
            ],
            linkerSettings: [
                .linkedFramework("AVFoundation", .when(platforms: [.iOS])),
                .linkedFramework("UIKit", .when(platforms: [.iOS]))
            ]
        ),
        .target(
            name: "VideoPlayerEngineNative",
            dependencies: ["VideoPlayerShellSupport"],
            path: "Sources/VideoPlayerModule",
            sources: [
                "Engine/Native/AVPlayerAdapter.swift"
            ],
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
            path: "Sources/VideoPlayerModule",
            sources: [
                "Engine/Kollus/KollusDRMConfiguration.swift",
                "Engine/Kollus/KollusDelegateBridge.swift",
                "Engine/Kollus/KollusDiagnosticsSink.swift",
                "Engine/Kollus/KollusEngineSignal.swift",
                "Engine/Kollus/KollusEnvironment.swift",
                "Engine/Kollus/KollusLiveChatProfile.swift",
                "Engine/Kollus/KollusObserver.swift",
                "Engine/Kollus/KollusPlayerAdapter.swift",
                "Engine/Kollus/KollusPlayerModuleFactory.swift",
                "Engine/Kollus/KollusSessionBootstrapper.swift",
                "Engine/Kollus/KollusStorageAdapter.swift",
                "Engine/Kollus/KollusStorageProtocol.swift",
                "Engine/Kollus/Downloads/KollusContentSnapshot.swift",
                "Engine/Kollus/Downloads/KollusDownloadCenter.swift",
                "Engine/Kollus/Downloads/KollusStorageBridge.swift"
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
        .target(
            name: "VideoPlayerModule",
            dependencies: [
                "VideoPlayerCore",
                "VideoPlayerShellSupport",
                "VideoPlayerEngineNative",
                "VideoPlayerEngineKollus"
            ],
            path: "Sources/VideoPlayerModuleExports"
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
                .target(name: "VideoPlayerModule", condition: .when(platforms: [.iOS])),
                .target(name: "VideoPlayerSkin", condition: .when(platforms: [.iOS]))
            ],
            path: "Tests/VideoPlayerModuleTests"
        )
    ]
)
