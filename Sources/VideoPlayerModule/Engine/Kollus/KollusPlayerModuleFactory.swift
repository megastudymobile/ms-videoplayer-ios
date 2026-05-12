import Foundation
import VideoPlayerCore
import VideoPlayerShellSupport

public struct KollusPlayerModuleFactory {
    public init() {}

    public func makeModule(
        configuration: PlayerModuleConfiguration = .default
    ) async -> PlayerModule {
        let engine = KollusPlayerAdapter()
        return await PlayerModuleWiring.makeModule(
            engine: engine,
            engineCapabilities: KollusPlayerAdapter.capabilities,
            configuration: configuration
        )
    }
}
