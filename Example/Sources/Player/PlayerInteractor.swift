//
//  PlayerInteractor.swift
//  VideoPlayerExample
//
//  Created by JunyoungJung on 2026/06/05.
//
//  모듈 수명(setUp/start/tearDown) + 사용자 액션 → PlaybackCommand 변환.
//  PlaybackCommand 밖 기능은 예외 capability protocol로만 접근한다.
//

import UIKit
import VideoPlayerCore
import VideoPlayerShellSupport
import VideoPlayerSkin

@MainActor
final class PlayerInteractor {
    private enum Metric {
        static let seekScrubPauseDelayNanoseconds: UInt64 = 50_000_000
    }

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
    private(set) var availableFeatures: Set<PlayerFeature> = []

    /// 엔진 가용성 ∩ 앱 정책 — UI 노출 결정은 이 값 하나만 본다.
    /// 정책으로 꺼진 기능은 엔진이 지원해도 노출 대상에서 제거된다.
    var resolvedFeatures: Set<PlayerFeature> {
        availableFeatures.filter { featurePolicy.allows($0) }
    }

    private var playerModule: PlayerModule?
    private let binder = PlayerStateBinder()
    private var lifecycleCoordinator: PlayerLifecycleCoordinator?
    private var nowPlayingCoordinator: PlayerNowPlayingCoordinator?
    /// tearDown 이 setUp(async) 완료 전에 호출된 경우 — 뒤늦게 만들어진 모듈이
    /// 미해제로 누수되지 않도록 차단한다 (push 후 즉시 back 레이스).
    private var isDisposed = false

    // capability protocol 캐스트 — 시뮬레이터(UnsupportedEnvironmentEngine)에서는 nil.
    private var zoomEngine: EngineSynchronousZoomAbility?
    private var seekPreviewEngine: (any EngineSeekPreviewAbility)?
    private var pendingScrollDistance = CGPoint.zero
    private var shouldStopScroll = false
    private var scrollTask: Task<Void, Never>?
    private var scrollTaskGeneration = 0
    private(set) var isZoomedIn = false
    private var latestPlaybackState: PlaybackState = .idle
    private var shouldResumePlaybackAfterScrub = false
    private var seekScrubPauseTask: Task<Void, Never>?

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
            allowedPlaybackRates: [0.5, 0.8, 1.0, 1.2, 1.5, 2.0],
            allowsAutoplay: true,
            skipInterval: TimeInterval(PreferenceManager.seekRangeSeconds),
            allowsSeekPreview: PreferenceManager.useSeekPreview
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
        zoomEngine = module.engine as? EngineSynchronousZoomAbility
        seekPreviewEngine = module.engine as? any EngineSeekPreviewAbility

        let coordinator = PlayerLifecycleCoordinator(
            core: module.core,
            policy: featurePolicy,
            engineRuntimeTraits: module.engineRuntimeTraits,
            onEvent: { [weak self] event in self?.consume(event: event) }
        )
        lifecycleCoordinator = coordinator
        coordinator.start()

        // 백그라운드 재생 정책이 켜진 경우에만 잠금화면/제어센터 플레이어를 노출한다.
        if featurePolicy.allowsBackgroundPlayback {
            let nowPlaying = PlayerNowPlayingCoordinator(
                core: module.core,
                skipInterval: featurePolicy.skipInterval,
                fallbackTitle: "VideoPlayer Example"
            )
            nowPlaying.start()
            nowPlayingCoordinator = nowPlaying
        }

        binder.bind(
            core: module.core,
            nowPlaying: nowPlayingCoordinator,
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
        nowPlayingCoordinator?.stop()
        nowPlayingCoordinator = nil
        binder.unbind()
        zoomEngine = nil
        seekPreviewEngine = nil
        pendingScrollDistance = .zero
        shouldStopScroll = false
        scrollTaskGeneration += 1
        scrollTask?.cancel()
        scrollTask = nil
        isZoomedIn = false
        shouldResumePlaybackAfterScrub = false
        seekScrubPauseTask?.cancel()
        seekScrubPauseTask = nil
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
            let isPlaying = self.latestPlaybackState.status == .playing
            await self.execute(isPlaying ? .pause : .play, on: module)
        }
    }

    func seekBy(_ delta: TimeInterval) {
        Task { @MainActor [weak self] in
            guard let self, let module = self.playerModule else { return }
            let snapshot = self.latestPlaybackState
            let target = min(max(0, snapshot.currentTime + delta), max(0, snapshot.duration))
            await self.execute(.seek(to: target), on: module)
        }
    }

    func beginSeekScrub() {
        guard let module = playerModule else { return }
        seekScrubPauseTask?.cancel()
        shouldResumePlaybackAfterScrub = latestPlaybackState.status == .playing
        guard shouldResumePlaybackAfterScrub else {
            seekScrubPauseTask = nil
            return
        }
        onRender(viewModel.setPlaybackIntent(isPlaying: false))
        seekScrubPauseTask = Task { @MainActor [weak self] in
            guard let self, self.isDisposed == false else { return }
            try? await Task.sleep(nanoseconds: Metric.seekScrubPauseDelayNanoseconds)
            guard Task.isCancelled == false, self.isDisposed == false else { return }
            await self.execute(.pause, on: module)
        }
    }

    func endSeekScrub(at time: TimeInterval) {
        guard let module = playerModule else { return }
        let pauseTask = seekScrubPauseTask
        seekScrubPauseTask = nil
        let shouldResume = shouldResumePlaybackAfterScrub
        shouldResumePlaybackAfterScrub = false

        Task { @MainActor [weak self] in
            guard let self, self.isDisposed == false else { return }
            await pauseTask?.value

            await self.execute(.seek(to: time), on: module)
            guard shouldResume else { return }
            self.onRender(self.viewModel.setPlaybackIntent(isPlaying: true))
            await self.execute(.play, on: module)
        }
    }

    /// 시킹 프리뷰 썸네일 조회 — 실패/미지원/정책 비활성은 nil (skin이 라벨-only로 폴백).
    func seekPreviewImage(at time: TimeInterval) async -> UIImage? {
        guard isDisposed == false, featurePolicy.allowsSeekPreview else { return nil }
        return await seekPreviewEngine?.seekPreviewImage(at: time)
    }

    /// 명령 실행 단일 경로 — 실패를 삼키지 않고 onCommandError로 surfacing한다.
    private func execute(_ command: PlaybackCommand, on module: PlayerModule) async {
        do {
            try await module.core.execute(command: command)
            // PlayerEvent에 배속 이벤트가 없어 명령 경로에서 NowPlaying 진행 속도를 맞춘다.
            if case .setPlaybackRate(let rate) = command {
                nowPlayingCoordinator?.setPlaybackRate(rate)
            }
        } catch {
            guard isDisposed == false else { return }
            onCommandError(error as? PlayerError ?? .unknown(error.localizedDescription))
        }
    }

    /// 핀치줌 — nonisolated 동기 경로. Task hop 없이 매 제스처 이벤트 즉시 적용.
    func applyZoom(_ recognizer: UIPinchGestureRecognizer) {
        zoomEngine?.applyZoomGesture(recognizer)
    }

    func refreshZoomState() {
        // zoom 상태는 엔진 이벤트(`zoomDidChange`)로 갱신된다.
    }

    func scroll(by distance: CGPoint) {
        guard playerModule != nil else { return }
        shouldStopScroll = false
        pendingScrollDistance.x += distance.x
        pendingScrollDistance.y += distance.y
        drainScrollQueue()
    }

    func stopScroll() {
        guard playerModule != nil else { return }
        pendingScrollDistance = .zero
        shouldStopScroll = true
        drainScrollQueue()
    }

    private func drainScrollQueue() {
        guard scrollTask == nil else { return }
        scrollTaskGeneration += 1
        let taskGeneration = scrollTaskGeneration
        scrollTask = Task { @MainActor [weak self] in
            defer {
                if self?.scrollTaskGeneration == taskGeneration {
                    self?.scrollTask = nil
                }
            }
            guard let self else { return }

            while Task.isCancelled == false {
                guard let module = self.playerModule else { return }

                if self.hasPendingScrollDistance {
                    let distance = self.pendingScrollDistance
                    self.pendingScrollDistance = .zero
                    try? await module.core.execute(command: .scroll(by: distance))
                    continue
                }

                if self.shouldStopScroll {
                    self.shouldStopScroll = false
                    try? await module.core.execute(command: .stopScroll)
                    continue
                }

                break
            }
        }
    }

    private var hasPendingScrollDistance: Bool {
        pendingScrollDistance.x != 0 || pendingScrollDistance.y != 0
    }

    // MARK: - 구간 반복 (shell 레벨 — 어댑터 API 없음, 문서 §6 갭)

    func handleSectionRepeat(_ action: PlayerSkinAction) {
        Task { @MainActor [weak self] in
            guard let self, self.playerModule != nil else { return }
            let now = self.latestPlaybackState.currentTime

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
        latestPlaybackState = playbackState
        enforceSectionRepeatIfNeeded(currentTime: playbackState.currentTime)
        onRender(viewModel.apply(playbackState: playbackState))
    }

    private func consume(event: PlayerEvent) {
        updateLatestPlaybackState(from: event)
        if let next = viewModel.apply(event: event) {
            onRender(next)
        }
        onEvent(event)
    }

    private func updateLatestPlaybackState(from event: PlayerEvent) {
        switch event {
        case .stateDidChange(let playbackState):
            latestPlaybackState = playbackState
        case .timeDidChange(let currentTime, let duration):
            latestPlaybackState = latestPlaybackState.updating(currentTime: currentTime, duration: duration)
        case .bufferingDidChange(let isBuffering):
            latestPlaybackState = latestPlaybackState.updating(isBuffering: isBuffering)
        case .zoomDidChange(let value):
            isZoomedIn = value > 1
        default:
            break
        }
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
