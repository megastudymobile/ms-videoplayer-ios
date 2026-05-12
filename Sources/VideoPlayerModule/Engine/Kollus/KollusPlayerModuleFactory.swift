import Foundation
import VideoPlayerCore
import VideoPlayerShellSupport

public struct KollusPlayerModuleFactory {
    private let engineFactory: () -> PlayerEngineAdapter
    private let engineCapabilities: EngineCapabilities

    public init(
        engineFactory: @escaping () -> PlayerEngineAdapter = { KollusPlayerAdapter() },
        engineCapabilities: EngineCapabilities = KollusPlayerAdapter.capabilities
    ) {
        self.engineFactory = engineFactory
        self.engineCapabilities = engineCapabilities
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
