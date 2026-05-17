//
//  HighPlayerShellViewController.swift
//  VideoPlayerExample
//
//  Created by 모바일팀_정준영 on 2026/05/17.
//

import UIKit
import VideoPlayerCore
import VideoPlayerShellSupport

@MainActor
public final class HighPlayerShellViewController: UIViewController {
    private let playerModule: PlayerModule
    private let playbackSource: PlaybackSource
    private let featurePolicy: PlayerFeaturePolicy
    private let dismissalConditionOverride: (() -> Bool)?
    private let binder = PlayerStateBinder()

    private lazy var lifecycleCoordinator = PlayerLifecycleCoordinator(
        controlUseCase: playerModule.controlPlaybackUseCase,
        policy: featurePolicy,
        engineCapabilities: playerModule.engineCapabilities,
        onEvent: { [weak self] event in
            self?.handle(event: event)
        }
    )

    private let surfaceView = HighPlayerRenderSurfaceView()
    private let controlsView = HighPlayerControlsView()
    private let eventLabel = UILabel()
    private var hasStartedPlayback = false
    private var latestState = PlaybackState.idle

    public init(
        playerModule: PlayerModule,
        playbackSource: PlaybackSource,
        featurePolicy: PlayerFeaturePolicy = .default,
        dismissalConditionOverride: (() -> Bool)? = nil
    ) {
        self.playerModule = playerModule
        self.playbackSource = playbackSource
        self.featurePolicy = featurePolicy
        self.dismissalConditionOverride = dismissalConditionOverride
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
        bindState()
        bindRenderSurface()
        lifecycleCoordinator.start()
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        guard hasStartedPlayback == false else {
            return
        }

        hasStartedPlayback = true
        Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            do {
                try await self.playerModule.startPlaybackUseCase.execute(
                    source: self.playbackSource,
                    policy: self.featurePolicy
                )
            } catch {
                self.eventLabel.text = "시작 실패: \((error as NSError).localizedDescription)"
            }
        }
    }

    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        if shouldCleanupOnDisappear {
            lifecycleCoordinator.stop()
            binder.unbind()

            Task {
                await playerModule.engine.unbindRenderSurface()
                await playerModule.core.dispose()
            }
        }
    }

    private var shouldCleanupOnDisappear: Bool {
        dismissalConditionOverride?() ?? (isBeingDismissed || isMovingFromParent)
    }

    private func configureUI() {
        view.backgroundColor = .systemBackground
        title = "High Player"

        controlsView.delegate = self

        eventLabel.font = .systemFont(ofSize: 13, weight: .regular)
        eventLabel.textColor = .secondaryLabel
        eventLabel.numberOfLines = 0
        eventLabel.text = "이벤트 없음"

        let contentStack = UIStackView(arrangedSubviews: [surfaceView, controlsView, eventLabel])
        contentStack.axis = .vertical
        contentStack.spacing = 16

        view.addSubview(contentStack)
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        surfaceView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            contentStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            surfaceView.heightAnchor.constraint(equalTo: surfaceView.widthAnchor, multiplier: 9.0 / 16.0)
        ])
    }

    private func bindState() {
        binder.bind(
            observeUseCase: playerModule.observePlaybackStateUseCase,
            onState: { [weak self] state in
                self?.latestState = state
                self?.controlsView.render(state: state)
            },
            onEvent: { [weak self] event in
                self?.handle(event: event)
            }
        )
    }

    private func bindRenderSurface() {
        Task {
            await playerModule.engine.bind(renderSurface: surfaceView)
        }
    }

    private func handle(event: PlayerEvent) {
        switch event {
        case .didFinish:
            eventLabel.text = "재생 완료"
        case .didFail(let error):
            eventLabel.text = "오류: \(error.localizedDescription)"
        case .policyDowngraded(let reason):
            eventLabel.text = "정책 감축: \(describe(reason: reason))"
        case .stateDidChange(let state):
            eventLabel.text = "상태 변경: \(describe(status: state.status))"
        case .bufferingDidChange(let isBuffering):
            eventLabel.text = isBuffering ? "버퍼링 시작" : "버퍼링 해제"
        case .timeDidChange,
             .captionDidUpdate,
             .bookmarksDidLoad,
             .bitrateDidChange,
             .heightDidChange,
             .externalOutputDidChange,
             .naturalSizeDidResolve,
             .framerateDidResolve,
             .deviceLockPolicyChanged,
             .nextEpisodeAvailable:
            break
        }
    }

    private func describe(status: PlaybackState.Status) -> String {
        switch status {
        case .idle:
            return "idle"
        case .preparing:
            return "preparing"
        case .readyToPlay:
            return "readyToPlay"
        case .playing:
            return "playing"
        case .paused:
            return "paused"
        case .buffering:
            return "buffering"
        case .finished:
            return "finished"
        case .failed:
            return "failed"
        }
    }

    private func describe(reason: PolicyDowngradeReason) -> String {
        switch reason {
        case .missingContinuesWithoutSurface:
            return "background playback 미지원"
        case .custom(let value):
            return value
        }
    }
}

extension HighPlayerShellViewController: HighPlayerControlsViewDelegate {
    func highPlayerControlsViewDidTapPlayPause(_ view: HighPlayerControlsView) {
        Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            let command: PlaybackCommand = self.controlsView.isPlaying ? .pause : .play
            try? await self.playerModule.controlPlaybackUseCase.execute(command: command)
        }
    }

    func highPlayerControlsViewDidTapStop(_ view: HighPlayerControlsView) {
        Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            try? await self.playerModule.controlPlaybackUseCase.execute(command: .stop)
        }
    }
}
