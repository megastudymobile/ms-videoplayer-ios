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

    let featurePolicy: PlayerFeaturePolicy

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
        onEvent: @escaping (PlayerEvent) -> Void
    ) {
        self.source = source
        self.moduleProvider = moduleProvider
        self.viewModel = viewModel
        self.onRender = onRender
        self.onEvent = onEvent
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
        zoomEngine = module.engine as? PlayerSynchronousZoomEngine

        let coordinator = PlayerLifecycleCoordinator(
            controlUseCase: module.controlPlaybackUseCase,
            policy: featurePolicy,
            engineCapabilities: module.engineCapabilities,
            onEvent: { [weak self] event in self?.consume(event: event) }
        )
        lifecycleCoordinator = coordinator
        coordinator.start()

        binder.bind(
            observeUseCase: module.observePlaybackStateUseCase,
            onState: { [weak self] state in self?.consume(playbackState: state) },
            onEvent: { [weak self] event in self?.consume(event: event) }
        )

        await module.engine.bind(renderSurface: renderSurface)
    }

    func start() async throws {
        guard isDisposed == false, let module = playerModule else { return }
        try await module.startPlaybackUseCase.execute(source: source, policy: featurePolicy)
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
            guard let module = self?.playerModule else { return }
            try? await module.controlPlaybackUseCase.execute(command: command)
        }
    }

    func togglePlayPause() {
        Task { @MainActor [weak self] in
            guard let self, let module = self.playerModule else { return }
            let isPlaying = await module.engine.currentState.status == .playing
            try? await module.controlPlaybackUseCase.execute(command: isPlaying ? .pause : .play)
        }
    }

    func seekBy(_ delta: TimeInterval) {
        Task { @MainActor [weak self] in
            guard let self, let module = self.playerModule else { return }
            let snapshot = await module.engine.currentState
            let target = min(max(0, snapshot.currentTime + delta), max(0, snapshot.duration))
            try? await module.controlPlaybackUseCase.execute(command: .seek(to: target))
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
