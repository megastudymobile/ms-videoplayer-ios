// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "videoplayer-ios-ms",
    platforms: [
        .iOS(.v15)
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
        )
    ],
    targets: [
        .target(
            name: "VideoPlayerCore",
            path: "Sources/VideoPlayerModule",
            sources: [
                "Core/Domain/PlaybackCommand.swift",
                "Core/Domain/PlaybackSource.swift",
                "Core/Domain/PlaybackState.swift",
                "Core/Domain/PlayerError.swift",
                "Core/Domain/PlayerEvent.swift",
                "Core/Domain/PlayerFeaturePolicy.swift",
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
                "Module/PlayerModuleConfiguration.swift",
                "Module/PlayerModuleWiring.swift",
                "ShellSupport/PlayerAudioSessionManager.swift",
                "ShellSupport/PlayerError+NSError.swift",
                "ShellSupport/PlayerLifecycleCoordinator.swift",
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
                "Engine/Kollus/KollusPlayerAdapter.swift",
                "Engine/Kollus/KollusPlayerModuleFactory.swift"
            ],
            linkerSettings: [
                .linkedFramework("UIKit", .when(platforms: [.iOS]))
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
                "VideoPlayerModule",
                "VideoPlayerCore",
                "VideoPlayerShellSupport",
                "VideoPlayerEngineNative",
                "VideoPlayerEngineKollus"
            ],
            path: "Tests/VideoPlayerModuleTests"
        )
    ]
)
