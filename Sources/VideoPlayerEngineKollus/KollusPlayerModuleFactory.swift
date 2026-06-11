//
//  KollusPlayerModuleFactory.swift
//  VideoPlayerModule
//
//  Created by 모바일팀_정준영 on 2026/05/15.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import Foundation
import VideoPlayerCore
import VideoPlayerShellSupport

public struct KollusPlayerModuleFactory {
    private let engineFactory: () -> PlayerEngineAdapter
    private let engineRuntimeTraits: EngineRuntimeTraits
    /// 모든 makeModule() 호출과 공유되는 단일 KollusDownloadCenter.
    /// init(environment:) path에서만 사용 가능. test-only init에서는 nil.
    public let downloads: KollusDownloadCenter?

    /// 신규 권장 진입점.
    /// 단일 `KollusSessionBootstrapper` + 단일 `KollusDownloadCenter`를 만들어 모든 `makeModule()`이 공유한다.
    public init(
        environment: KollusEnvironment,
        observer: KollusObserver? = nil,
        diagnostics: KollusDiagnosticsSink? = nil
    ) {
        let bootstrapper = KollusSessionBootstrapper(environment: environment)
        self.engineFactory = {
            KollusPlayerAdapter(
                bootstrapper: bootstrapper,
                environment: environment,
                observer: observer,
                diagnostics: diagnostics
            )
        }
        var caps = KollusPlayerAdapter.runtimeTraits
        if environment.audioBackgroundPlayPolicy {
            caps.insert(.continuesWithoutSurface)
        }
        self.engineRuntimeTraits = caps
        self.downloads = KollusDownloadCenter(
            bootstrapper: bootstrapper,
            environment: environment
        )
    }

    /// Test-only initializer. `@testable import`만 접근 가능. downloads는 nil.
    internal init(
        engineFactory: @escaping () -> PlayerEngineAdapter,
        engineRuntimeTraits: EngineRuntimeTraits = KollusPlayerAdapter.runtimeTraits
    ) {
        self.engineFactory = engineFactory
        self.engineRuntimeTraits = engineRuntimeTraits
        self.downloads = nil
    }

    public func makeModule(
        configuration: PlayerModuleConfiguration = .default
    ) async -> PlayerModule {
        let engine = engineFactory()
        return await PlayerModuleWiring.makeModule(
            descriptor: PlayerEngineDescriptor(engine: engine, runtimeTraits: engineRuntimeTraits),
            configuration: configuration
        )
    }
}
