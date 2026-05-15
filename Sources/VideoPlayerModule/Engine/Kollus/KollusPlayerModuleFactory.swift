//
//  KollusPlayerModuleFactory.swift
//  VideoPlayerModule
//
//  Updated by 모바일개발팀_정준영 on 2026/05/15 (Phase 3 T026).
//

import Foundation
import VideoPlayerCore
import VideoPlayerShellSupport

public struct KollusPlayerModuleFactory {
    private let engineFactory: () -> PlayerEngineAdapter
    private let engineCapabilities: EngineCapabilities
    /// Phase 6: 모든 makeModule() 호출과 공유되는 단일 KollusDownloadCenter.
    /// 신규 init(environment:) path에서만 사용 가능. legacy init에서는 nil.
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
        self.engineCapabilities = KollusPlayerAdapter.capabilities
        self.downloads = KollusDownloadCenter(
            bootstrapper: bootstrapper,
            environment: environment
        )
    }

    /// Legacy zero-arg/engine-injection init: 게이트 0.3.0에서 제거된다. downloads는 nil.
    @available(*, deprecated, message: "Use init(environment:observer:diagnostics:). Gate 0.3.0에서 제거.")
    public init(
        engineFactory: @escaping () -> PlayerEngineAdapter = { KollusPlayerAdapter() },
        engineCapabilities: EngineCapabilities = KollusPlayerAdapter.capabilities
    ) {
        self.engineFactory = engineFactory
        self.engineCapabilities = engineCapabilities
        self.downloads = nil
    }

    public func makeModule(
        configuration: PlayerModuleConfiguration = .default
    ) async -> PlayerModule {
        let engine = engineFactory()
        return await PlayerModuleWiring.makeModule(
            engine: engine,
            engineCapabilities: engineCapabilities,
            configuration: configuration
        )
    }
}
