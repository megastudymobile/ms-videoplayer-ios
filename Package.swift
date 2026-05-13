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
                "Core/Domain/PlayerCapabilities.swift",
                "Core/Domain/PlayerFeatureSet.swift",
                "Core/Domain/PlayerIdentity.swift",
                "Core/Domain/PlayerStateSnapshot.swift",
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
                "VideoPlayerCore",
                .target(name: "VideoPlayerShellSupport", condition: .when(platforms: [.iOS])),
                .target(name: "VideoPlayerEngineNative", condition: .when(platforms: [.iOS])),
                .target(name: "VideoPlayerEngineKollus", condition: .when(platforms: [.iOS])),
                .target(name: "VideoPlayerModule", condition: .when(platforms: [.iOS]))
            ],
            path: "Tests/VideoPlayerModuleTests"
        )
    ]
)
