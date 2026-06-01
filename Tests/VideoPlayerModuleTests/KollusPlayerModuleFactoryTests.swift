#if canImport(UIKit)

import Foundation
import Testing
@testable import VideoPlayerCore
@testable import VideoPlayerEngineKollus
@testable import VideoPlayerShellSupport

@Suite("Kollus player module factory 검증")
struct KollusPlayerModuleFactoryTests {
    @Test("Factory가 주입된 engine을 use case에 연결")
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

    @Test("Adapter가 legacy URL 차단 메시지를 surfacing하지 않음")
    /// spec 025 Phase 4 (T027) 이후 `.url` 진입은 허용된다.
    /// SDK가 시뮬레이터에서 stub일 수 있어 정확한 error는 환경 의존이지만,
    /// 적어도 "kollus(mediaContentKey:)만 지원" legacy 차단 메시지는 더 이상 surfacing되지 않아야 한다.
    func adapterDoesNotEmitLegacyURLRejectionMessage() async throws {
        let adapter = KollusPlayerAdapter()
        let source = PlaybackSource.url(URL(string: "https://example.com/video.mp4")!)

        do {
            try await adapter.prepare(source: source)
            // 시뮬레이터에서도 실 SDK 호출이 성공할 수 있다(SDK 환경에 의존). 회귀 여부만 보고 통과.
        } catch PlayerError.engineError(let message) {
            #expect(!message.contains("kollus(mediaContentKey:)만 지원"), "T027 회귀: legacy URL 차단 메시지 surfacing — \(message)")
        } catch {
            // 다른 error type(NSError 등 SDK stub)도 허용 — 본 phase의 핵심은 legacy 차단 제거 회귀 방어.
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
