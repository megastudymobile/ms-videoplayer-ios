//
//  PlayerInteractorTests.swift
//  VideoPlayerExampleTests
//
//  Created by JunyoungJung on 2026/06/10.
//

import Foundation
import Testing
import UIKit
import VideoPlayerCore
import VideoPlayerShellSupport
import VideoPlayerSkin
@testable import VideoPlayerExample

@MainActor
@Suite("PlayerInteractor 수명주기/에러 surfacing")
struct PlayerInteractorTests {

    private func makeInteractor(
        provider: PlayerModuleProviding,
        onRender: @escaping (PlayerSkinState) -> Void = { _ in },
        onCommandError: @escaping (PlayerError) -> Void = { _ in }
    ) -> PlayerInteractor {
        PlayerInteractor(
            source: .url(URL(string: "https://example.com/v.mp4")!),
            moduleProvider: provider,
            viewModel: PlayerStateViewModel(),
            onRender: onRender,
            onEvent: { _ in },
            onCommandError: onCommandError
        )
    }

    @Test("setUp 후 availableFeatures가 엔진 protocol 채택을 반영한다")
    func setUp_exposesAvailableFeatures() async throws {
        let provider = FakeModuleProvider()
        let interactor = makeInteractor(provider: provider)

        try await interactor.setUp(renderSurface: FakeRenderSurface())

        // BareTestEngine은 optional protocol 미채택 — 가용 기능 없음.
        #expect(interactor.availableFeatures == [])
        interactor.tearDown()
    }

    @Test("미지원 명령 실패가 onCommandError로 surfacing된다")
    func unsupportedCommand_surfacesError() async throws {
        let provider = FakeModuleProvider()
        var captured: [PlayerError] = []
        let interactor = makeInteractor(
            provider: provider,
            onCommandError: { captured.append($0) }
        )

        try await interactor.setUp(renderSurface: FakeRenderSurface())
        // BareTestEngine은 EnginePlaybackRateAbility 미채택 → Core가 engineError throw.
        interactor.send(.setPlaybackRate(2.0))

        try await waitUntil { captured.isEmpty == false }
        guard case .engineError = captured.first else {
            Issue.record("engineError가 아님: \(String(describing: captured.first))")
            return
        }
        interactor.tearDown()
    }

    @Test("tearDown이 setUp(async) 완료보다 선행하면 모듈을 폐기한다")
    func tearDownBeforeSetUpCompletes_discardsModule() async throws {
        let provider = FakeModuleProvider(makeDelayNanoseconds: 100_000_000)
        let interactor = makeInteractor(provider: provider)

        let setUpTask = Task { try await interactor.setUp(renderSurface: FakeRenderSurface()) }
        interactor.tearDown()   // setUp의 makeModule await 중 선행 호출
        try await setUpTask.value

        // 폐기됐으므로 이후 start는 무동작이어야 한다 (모듈 nil).
        try await interactor.start()
        #expect(provider.madeModules.count == 1)
        let engine = provider.madeModules[0].engine as? BareTestEngine
        let prepareCount = await engine?.prepareCount ?? -1
        #expect(prepareCount == 0)
    }

    @Test("새 scroll 입력은 보류된 stopScroll을 취소한다")
    func scrollAfterPendingStop_discardsStopScroll() async throws {
        let engine = ScrollTestEngine()
        let provider = FakeModuleProvider(engine: engine)
        let interactor = makeInteractor(provider: provider)

        try await interactor.setUp(renderSurface: FakeRenderSurface())
        interactor.scroll(by: CGPoint(x: 1, y: 0))
        interactor.stopScroll()
        interactor.scroll(by: CGPoint(x: 2, y: 0))

        try await waitUntilAsync { await engine.events.isEmpty == false }
        let events = await engine.events
        #expect(events == ["scroll:2.0:0.0"])
        interactor.tearDown()
    }

    @Test("재생 중 스크럽은 pause 후 seek하고 다시 play한다")
    func seekScrubWhilePlaying_pausesSeeksAndResumes() async throws {
        let engine = RecordingEngine()
        var renderedStates: [PlayerSkinState] = []
        let provider = FakeModuleProvider(engine: engine)
        let interactor = makeInteractor(
            provider: provider,
            onRender: { renderedStates.append($0) }
        )

        try await interactor.setUp(renderSurface: FakeRenderSurface())
        try await interactor.start()
        try await waitUntil { renderedStates.last?.isPlaying == true }
        await engine.resetCommands()

        interactor.beginSeekScrub()
        try await waitUntil { renderedStates.last?.isPlaying == false }
        interactor.endSeekScrub(at: 42)
        try await waitUntilAsync {
            await engine.commands == ["pause", "seek:42.0", "play"]
        }

        #expect(renderedStates.last?.isPlaying == true)
        interactor.tearDown()
    }

    @Test("일시정지 상태 스크럽은 seek 후 자동 재생하지 않는다")
    func seekScrubWhilePaused_doesNotAutoPlay() async throws {
        let engine = RecordingEngine()
        var renderedStates: [PlayerSkinState] = []
        let provider = FakeModuleProvider(engine: engine)
        let interactor = makeInteractor(
            provider: provider,
            onRender: { renderedStates.append($0) }
        )

        try await interactor.setUp(renderSurface: FakeRenderSurface())
        try await interactor.start()
        try await waitUntil { renderedStates.last?.isPlaying == true }
        interactor.send(.pause)
        try await waitUntil { renderedStates.last?.isPlaying == false }
        await engine.resetCommands()

        interactor.beginSeekScrub()
        interactor.endSeekScrub(at: 24)
        try await waitUntilAsync {
            await engine.commands == ["seek:24.0"]
        }

        #expect(renderedStates.last?.isPlaying == false)
        interactor.tearDown()
    }

    private func waitUntilAsync(
        timeout: TimeInterval = 1.0,
        sourceLocation: SourceLocation = #_sourceLocation,
        condition: @escaping () async -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if await condition() { return }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        Issue.record("조건을 만족하지 못했습니다.", sourceLocation: sourceLocation)
    }

    private func waitUntil(
        timeout: TimeInterval = 1.0,
        sourceLocation: SourceLocation = #_sourceLocation,
        condition: @escaping @MainActor () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        Issue.record("조건을 만족하지 못했습니다.", sourceLocation: sourceLocation)
    }
}

// MARK: - Fakes

@MainActor
private final class FakeModuleProvider: PlayerModuleProviding {
    private(set) var madeModules: [PlayerModule] = []
    private let engine: PlayerEngineAdapter
    private let makeDelayNanoseconds: UInt64

    init(
        engine: PlayerEngineAdapter = BareTestEngine(),
        makeDelayNanoseconds: UInt64 = 0
    ) {
        self.engine = engine
        self.makeDelayNanoseconds = makeDelayNanoseconds
    }

    func makeModule() async throws -> PlayerModule {
        if makeDelayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: makeDelayNanoseconds)
        }
        let module = await PlayerModuleWiring.makeModule(
            engine: engine,
            engineRuntimeTraits: []
        )
        madeModules.append(module)
        return module
    }
}

private actor BareTestEngine: PlayerEngineAdapter {
    nonisolated static let runtimeTraits: EngineRuntimeTraits = []
    let outputStream: AsyncStream<PlayerEngineOutput> = AsyncStream { $0.finish() }
    private(set) var prepareCount = 0

    func prepare(source: PlaybackSource) async throws { prepareCount += 1 }
    func play() async throws {}
    func pause() async throws {}
    func seek(to time: TimeInterval) async throws {}
    func stop(reason: PlayerStopReason) async throws {}
    func bind(renderSurface: PlayerRenderSurface) {}
    func unbindRenderSurface() {}
}

private actor RecordingEngine: PlayerEngineAdapter {
    nonisolated static let runtimeTraits: EngineRuntimeTraits = []
    let outputStream: AsyncStream<PlayerEngineOutput>
    private let outputContinuation: AsyncStream<PlayerEngineOutput>.Continuation
    private(set) var commands: [String] = []

    init() {
        var continuation: AsyncStream<PlayerEngineOutput>.Continuation!
        outputStream = AsyncStream(bufferingPolicy: .unbounded) { continuation = $0 }
        outputContinuation = continuation
    }

    func resetCommands() {
        commands.removeAll()
    }

    func prepare(source: PlaybackSource) async throws {
        commands.append("prepare")
        outputContinuation.yield(.stateInput(.prepared(.init(
            position: 0,
            duration: 120,
            isLive: false,
            liveDuration: nil
        ))))
    }

    func play() async throws {
        commands.append("play")
        outputContinuation.yield(.stateInput(.playStarted))
    }

    func pause() async throws {
        commands.append("pause")
        outputContinuation.yield(.stateInput(.pauseStarted))
    }

    func seek(to time: TimeInterval) async throws {
        commands.append("seek:\(time)")
        outputContinuation.yield(.stateInput(.positionChanged(time: time, duration: 120)))
    }

    func stop(reason: PlayerStopReason) async throws {
        commands.append("stop")
    }

    func bind(renderSurface: PlayerRenderSurface) {}
    func unbindRenderSurface() {}
}

private actor ScrollTestEngine: PlayerEngineAdapter, EngineScrollAbility {
    nonisolated static let runtimeTraits: EngineRuntimeTraits = []
    let outputStream: AsyncStream<PlayerEngineOutput> = AsyncStream { $0.finish() }
    private(set) var events: [String] = []

    func prepare(source: PlaybackSource) async throws {}
    func play() async throws {}
    func pause() async throws {}
    func seek(to time: TimeInterval) async throws {}
    func stop(reason: PlayerStopReason) async throws {}
    func bind(renderSurface: PlayerRenderSurface) {}
    func unbindRenderSurface() {}

    func scroll(by distance: CGPoint) async throws {
        events.append("scroll:\(distance.x):\(distance.y)")
    }

    func stopScroll() async throws {
        events.append("stop")
    }
}

private final class FakeRenderSurface: PlayerRenderSurface {
    let containerView: UIView

    @MainActor
    init() {
        self.containerView = UIView()
    }

    func engineDidAttach() {}
    func engineDidDetach() {}
    func showUnsupportedEnvironment(message: String) {}
}
