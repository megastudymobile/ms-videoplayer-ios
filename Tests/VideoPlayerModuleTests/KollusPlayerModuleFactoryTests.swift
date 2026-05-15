#if canImport(UIKit)

import Foundation
import Testing
@testable import VideoPlayerModule

@Suite("Kollus player module factory")
struct KollusPlayerModuleFactoryTests {
    @Test("Factory wires injected engine to use cases")
    func makeModuleWiresInjectedEngineToUseCases() async throws {
        let engine = FactoryTestEngineAdapter()
        let factory = KollusPlayerModuleFactory(
            engineFactory: { engine },
            engineCapabilities: [.continuesWithoutSurface]
        )

        let module = await factory.makeModule(
            configuration: PlayerModuleConfiguration(autoActivateCore: false)
        )

        #expect(module.engineCapabilities == [.continuesWithoutSurface])

        try await module.controlPlaybackUseCase.execute(command: .stop)

        let stopCount = await engine.stopCount
        #expect(stopCount == 1)
    }

    @Test("Adapter rejects URL source before creating Kollus view")
    func adapterRejectsURLSourceBeforeCreatingKollusView() async throws {
        let adapter = KollusPlayerAdapter()
        let source = PlaybackSource.url(URL(string: "https://example.com/video.mp4")!)

        do {
            try await adapter.prepare(source: source)
            Issue.record("KollusPlayerAdapter는 URL source를 거부해야 합니다.")
        } catch PlayerError.engineError(let message) {
            #expect(message.contains("kollus(mediaContentKey:)만 지원"))
        } catch {
            Issue.record("예상하지 못한 error type: \(error)")
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

    func play() {}

    func pause() {}

    func seek(to time: TimeInterval) async {}

    func stop() {
        stopCount += 1
    }

    func bind(renderSurface: PlayerRenderSurface) {}

    func unbindRenderSurface() {}
}

#endif
