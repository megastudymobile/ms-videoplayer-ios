//
//  PlayerModuleWiring.swift
//  VideoPlayerModule
//
//  Created by 모바일팀_정준영 on 2026/04/17.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import Foundation
import VideoPlayerCore

public struct PlayerModule {
    public let core: PlayerCore
    public let engine: PlayerEngineAdapter
    public let engineCapabilities: EngineCapabilities

    /// 엔진 가용 기능 — host/Skin이 init 직후 버튼 노출을 사전 결정한다.
    public var availableFeatures: PlayerFeatureAvailability {
        core.availableFeatures
    }

    public init(
        core: PlayerCore,
        engine: PlayerEngineAdapter,
        engineCapabilities: EngineCapabilities
    ) {
        self.core = core
        self.engine = engine
        self.engineCapabilities = engineCapabilities
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

        return PlayerModule(
            core: core,
            engine: engine,
            engineCapabilities: engineCapabilities
        )
    }
}
