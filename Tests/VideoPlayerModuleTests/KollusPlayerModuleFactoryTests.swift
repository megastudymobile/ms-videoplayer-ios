#if canImport(UIKit)

import Foundation
import Testing
@testable import VideoPlayerCore
@testable import VideoPlayerEngineKollus
@testable import VideoPlayerShellSupport

@Suite("Kollus player module factory 검증")
struct KollusPlayerModuleFactoryTests {
    @Test("Factory가 주입된 engine을 core에 연결")
    func makeModuleWiresInjectedEngineToCore() async throws {
        let engine = FactoryTestEngineAdapter()
        let factory = KollusPlayerModuleFactory(
            engineFactory: { engine },
            engineCapabilities: [.continuesWithoutSurface]
        )

        let module = await factory.makeModule(
            configuration: PlayerModuleConfiguration(autoActivateCore: false)
        )

        #expect(module.engineCapabilities == [.continuesWithoutSurface])

        try await module.core.execute(command: .stop)

        let stopCount = await engine.stopCount
        #expect(stopCount == 1)
    }

    @MainActor
    @Test("Adapter가 URL prepare를 bootstrapper 경로로 처리")
    func adapterPrepareWithURLUsesBootstrapperPath() async {
        let storage = FakeKollusStorage()
        storage.startStorageError = NSError(domain: "kollus.test", code: 7)
        let env = KollusEnvironment(
            applicationKey: "valid-key",
            applicationBundleID: "com.example.app",
            applicationExpireDate: Date().addingTimeInterval(60 * 60 * 24 * 30)
        )
        let bootstrapper = KollusSessionBootstrapper(environment: env) { storage }
        let adapter = KollusPlayerAdapter(bootstrapper: bootstrapper, environment: env)
        let source = PlaybackSource.url(URL(string: "https://example.com/video.mp4")!)

        await #expect {
            try await adapter.prepare(source: source)
        } throws: { error in
            guard case let PlayerError.engineError(message) = error else { return false }
            return message.contains("startStorage")
        }
    }
}

private actor FactoryTestEngineAdapter: PlayerEngineAdapter {
    nonisolated static let capabilities: EngineCapabilities = []

    var currentState: PlaybackState {
        .idle
    }

    let eventStream: AsyncStream<PlayerEvent>

    private let eventContinuation: AsyncStream<PlayerEvent>.Continuation
    private(set) var stopCount = 0

    init() {
        var continuation: AsyncStream<PlayerEvent>.Continuation?
        eventStream = AsyncStream(bufferingPolicy: .bufferingNewest(8)) {
            continuation = $0
        }
        eventContinuation = continuation!
    }

    deinit {
        eventContinuation.finish()
    }

    func prepare(source: PlaybackSource) async throws {}

    func play() async throws {}

    func pause() async throws {}

    func seek(to time: TimeInterval) async throws {}

    func stop(reason: PlayerStopReason) async throws {
        stopCount += 1
    }

    func bind(renderSurface: PlayerRenderSurface) {}

    func unbindRenderSurface() {}
}

#endif
