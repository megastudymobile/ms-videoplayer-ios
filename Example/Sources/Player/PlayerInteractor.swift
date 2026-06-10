//
//  PlayerInteractor.swift
//  VideoPlayerExample
//
//  Created by JunyoungJung on 2026/06/05.
//
//  모듈 수명(setUp/start/tearDown) + 사용자 액션 → PlaybackCommand 변환.
//  PlaybackCommand 밖 기능은 capability protocol 캐스트로만 접근한다 —
//  구체 어댑터 타입 다운캐스트 금지 (캐스트 실패 = 해당 기능 비활성).
//

import UIKit
import VideoPlayerCore
import VideoPlayerShellSupport
import VideoPlayerSkin

@MainActor
final class PlayerInteractor {
    private let source: PlaybackSource
    private let moduleProvider: PlayerModuleProviding
    private let viewModel: PlayerStateViewModel
    private let onRender: (PlayerSkinState) -> Void
    /// skin 상태와 무관한 이벤트(자막/북마크/실패/정책 강등)를 화면으로 전달.
    private let onEvent: (PlayerEvent) -> Void
    /// 명령 실행 실패 전달 — 무음 삼킴 금지. 화면이 토스트로 surfacing한다.
    private let onCommandError: (PlayerError) -> Void

    let featurePolicy: PlayerFeaturePolicy
    /// 엔진 가용 기능 — setUp 완료 후 확정. UI 버튼 사전 게이트용.
    private(set) var availableFeatures: PlayerFeatureAvailability = []

    private var playerModule: PlayerModule?
    private let binder = PlayerStateBinder()
    private var lifecycleCoordinator: PlayerLifecycleCoordinator?
    /// tearDown 이 setUp(async) 완료 전에 호출된 경우 — 뒤늦게 만들어진 모듈이
    /// 미해제로 누수되지 않도록 차단한다 (push 후 즉시 back 레이스).
    private var isDisposed = false

    // capability protocol 캐스트 — 시뮬레이터(UnsupportedEnvironmentEngine)에서는 nil.
    private var zoomEngine: PlayerSynchronousZoomEngine?

    init(
        source: PlaybackSource,
        moduleProvider: PlayerModuleProviding,
        viewModel: PlayerStateViewModel,
        onRender: @escaping (PlayerSkinState) -> Void,
        onEvent: @escaping (PlayerEvent) -> Void,
        onCommandError: @escaping (PlayerError) -> Void = { _ in }
    ) {
        self.source = source
        self.moduleProvider = moduleProvider
        self.viewModel = viewModel
        self.onRender = onRender
        self.onEvent = onEvent
        self.onCommandError = onCommandError
        self.featurePolicy = PlayerFeaturePolicy(
            allowsBackgroundPlayback: PreferenceManager.isBackgroundAudioPlay,
            maxPlaybackRate: 2.0,
            allowsAutoplay: true,
            skipInterval: TimeInterval(PreferenceManager.seekRangeSeconds)
        )
    }

    // MARK: - 모듈 수명

    func setUp(renderSurface: PlayerRenderSurface) async throws {
        let module = try await moduleProvider.makeModule()
        // makeModule await 동안 tearDown 이 선행됐으면 — 이 모듈은 즉시 폐기하고 중단.
        guard isDisposed == false else {
            await module.core.dispose()
            return
        }
        playerModule = module
        availableFeatures = module.availableFeatures
        zoomEngine = module.engine as? PlayerSynchronousZoomEngine

        let coordinator = PlayerLifecycleCoordinator(
            core: module.core,
            policy: featurePolicy,
            engineCapabilities: module.engineCapabilities,
            onEvent: { [weak self] event in self?.consume(event: event) }
        )
        lifecycleCoordinator = coordinator
        coordinator.start()

        binder.bind(
            core: module.core,
            onState: { [weak self] state in self?.consume(playbackState: state) },
            onEvent: { [weak self] event in self?.consume(event: event) }
        )

        await module.engine.bind(renderSurface: renderSurface)
    }

    func start() async throws {
        guard isDisposed == false, let module = playerModule else { return }
        try await module.core.start(source: source, policy: featurePolicy)
    }

    func tearDown() {
        isDisposed = true
        lifecycleCoordinator?.stop()
        lifecycleCoordinator = nil
        binder.unbind()
        zoomEngine = nil
        let module = playerModule
        playerModule = nil
        Task { @MainActor in
            await module?.engine.unbindRenderSurface()
            await module?.core.dispose()
        }
    }

    // MARK: - 명령

    func send(_ command: PlaybackCommand) {
        Task { @MainActor [weak self] in
            guard let self, let module = self.playerModule else { return }
            await self.execute(command, on: module)
        }
    }

    func togglePlayPause() {
        Task { @MainActor [weak self] in
            guard let self, let module = self.playerModule else { return }
            let isPlaying = await module.engine.currentState.status == .playing
            await self.execute(isPlaying ? .pause : .play, on: module)
        }
    }

    func seekBy(_ delta: TimeInterval) {
        Task { @MainActor [weak self] in
            guard let self, let module = self.playerModule else { return }
            let snapshot = await module.engine.currentState
            let target = min(max(0, snapshot.currentTime + delta), max(0, snapshot.duration))
            await self.execute(.seek(to: target), on: module)
        }
    }

    /// 명령 실행 단일 경로 — 실패를 삼키지 않고 onCommandError로 surfacing한다.
    private func execute(_ command: PlaybackCommand, on module: PlayerModule) async {
        do {
            try await module.core.execute(command: command)
        } catch {
            guard isDisposed == false else { return }
            onCommandError(error as? PlayerError ?? .unknown(error.localizedDescription))
        }
    }

    /// 핀치줌 — nonisolated 동기 경로. Task hop 없이 매 제스처 이벤트 즉시 적용.
    func applyZoom(_ recognizer: UIPinchGestureRecognizer) {
        zoomEngine?.applyZoomGesture(recognizer)
    }

    // MARK: - 구간 반복 (shell 레벨 — 어댑터 API 없음, 문서 §6 갭)

    func handleSectionRepeat(_ action: PlayerSkinAction) {
        Task { @MainActor [weak self] in
            guard let self, let module = self.playerModule else { return }
            let now = await module.engine.currentState.currentTime

            switch (action, self.viewModel.state.sectionRepeat) {
            case (.sectionRepeatToggleRequested, .idle):
                self.onRender(self.viewModel.setSectionRepeat(.started(now)))
            case (.sectionRepeatToggleRequested, _):
                self.onRender(self.viewModel.setSectionRepeat(.idle))
            case (.sectionRepeatStartRequested, _):
                self.onRender(self.viewModel.setSectionRepeat(.started(now)))
            case (.sectionRepeatEndRequested, .started(let start)) where now > start:
                self.onRender(self.viewModel.setSectionRepeat(.looping(start: start, end: now)))
            default:
                break
            }
        }
    }

    // MARK: - 스트림 소비

    private func consume(playbackState: PlaybackState) {
        enforceSectionRepeatIfNeeded(currentTime: playbackState.currentTime)
        onRender(viewModel.apply(playbackState: playbackState))
    }

    private func consume(event: PlayerEvent) {
        if let next = viewModel.apply(event: event) {
            onRender(next)
        }
        onEvent(event)
    }

    /// 구간 끝 도달 시 시작점으로 재시크.
    private func enforceSectionRepeatIfNeeded(currentTime: TimeInterval) {
        guard case .looping(let start, let end) = viewModel.state.sectionRepeat,
              currentTime >= end else {
            return
        }
        send(.seek(to: start))
    }
}
