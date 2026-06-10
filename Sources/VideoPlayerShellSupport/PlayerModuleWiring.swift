//
//  PlayerModuleWiring.swift
//  VideoPlayerModule
//
//  Created by 모바일개발팀_정준영 on 2026/04/17.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

import Foundation
import VideoPlayerCore

public struct PlayerModule {
    public let core: PlayerCore
    public let engine: PlayerEngineAdapter
    public let engineCapabilities: EngineCapabilities
    public let startPlaybackUseCase: StartPlaybackUseCaseProtocol
    public let controlPlaybackUseCase: ControlPlaybackUseCaseProtocol
    public let observePlaybackStateUseCase: ObservePlaybackStateUseCaseProtocol

    /// 엔진 가용 기능 — host/Skin이 init 직후 버튼 노출을 사전 결정한다.
    public var availableFeatures: PlayerFeatureAvailability {
        core.availableFeatures
    }

    public init(
        core: PlayerCore,
        engine: PlayerEngineAdapter,
        engineCapabilities: EngineCapabilities,
        startPlaybackUseCase: StartPlaybackUseCaseProtocol,
        controlPlaybackUseCase: ControlPlaybackUseCaseProtocol,
        observePlaybackStateUseCase: ObservePlaybackStateUseCaseProtocol
    ) {
        self.core = core
        self.engine = engine
        self.engineCapabilities = engineCapabilities
        self.startPlaybackUseCase = startPlaybackUseCase
        self.controlPlaybackUseCase = controlPlaybackUseCase
        self.observePlaybackStateUseCase = observePlaybackStateUseCase
    }
}

public enum PlayerModuleWiring {
    public static func makeModule(
        engine: PlayerEngineAdapter,
        engineCapabilities: EngineCapabilities,
        configuration: PlayerModuleConfiguration = .default
    ) async -> PlayerModule {
        let core = PlayerCore(
            engine: engine,
            engineCapabilities: engineCapabilities,
            initialPolicy: configuration.initialPolicy
        )

        if configuration.autoActivateCore {
            await core.activate()
        }

        let useCases = await MainActor.run {
            (
                DefaultStartPlaybackUseCase(core: core),
                DefaultControlPlaybackUseCase(core: core),
                DefaultObservePlaybackStateUseCase(core: core)
            )
        }

        return PlayerModule(
            core: core,
            engine: engine,
            engineCapabilities: engineCapabilities,
            startPlaybackUseCase: useCases.0,
            controlPlaybackUseCase: useCases.1,
            observePlaybackStateUseCase: useCases.2
        )
    }
}
