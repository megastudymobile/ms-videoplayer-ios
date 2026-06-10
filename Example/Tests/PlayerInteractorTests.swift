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
@testable import VideoPlayerExample

@MainActor
@Suite("PlayerInteractor 수명주기/에러 surfacing")
struct PlayerInteractorTests {

    private func makeInteractor(
        provider: PlayerModuleProviding,
        onCommandError: @escaping (PlayerError) -> Void = { _ in }
    ) -> PlayerInteractor {
        PlayerInteractor(
            source: .url(URL(string: "https://example.com/v.mp4")!),
            moduleProvider: provider,
            viewModel: PlayerStateViewModel(),
            onRender: { _ in },
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
        let interactor = makeInteractor(provider: provider) { captured.append($0) }

        try await interactor.setUp(renderSurface: FakeRenderSurface())
        // BareTestEngine은 PlayerPlaybackRateEngine 미채택 → Core가 engineError throw.
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
    private let makeDelayNanoseconds: UInt64

    init(makeDelayNanoseconds: UInt64 = 0) {
        self.makeDelayNanoseconds = makeDelayNanoseconds
    }

    func makeModule() async throws -> PlayerModule {
        if makeDelayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: makeDelayNanoseconds)
        }
        let module = await PlayerModuleWiring.makeModule(
            engine: BareTestEngine(),
            engineCapabilities: []
        )
        madeModules.append(module)
        return module
    }
}

private actor BareTestEngine: PlayerEngineAdapter {
    nonisolated static let capabilities: EngineCapabilities = []
    var currentState: PlaybackState { .idle }
    let eventStream: AsyncStream<PlayerEvent> = AsyncStream { $0.finish() }
    private(set) var prepareCount = 0

    func prepare(source: PlaybackSource) async throws { prepareCount += 1 }
    func play() async throws {}
    func pause() async throws {}
    func seek(to time: TimeInterval) async throws {}
    func stop(reason: PlayerStopReason) async throws {}
    func bind(renderSurface: PlayerRenderSurface) {}
    func unbindRenderSurface() {}
}

@MainActor
private final class FakeRenderSurface: PlayerRenderSurface {
    let containerView = UIView()
    func engineDidAttach() {}
    func engineDidDetach() {}
    func showUnsupportedEnvironment(message: String) {}
}
