//
//  KollusPlayerShellViewController.swift
//  VideoPlayerExample
//
//  Created by 모바일팀_정준영 on 2026/05/17.
//
//  smartlearning LearningPlayerShellViewController 시각적 동일 +
//  KollusPlayerModuleFactory를 직접 사용해 라이브러리 API와 1:1 매핑.
//

import UIKit
import VideoPlayerCore
import VideoPlayerEngineKollus
import VideoPlayerShellSupport

@MainActor
final class KollusPlayerShellViewController: UIViewController {
    private let moduleFactory: KollusPlayerModuleFactory
    private let mediaContentKey: String
    private let featurePolicy: PlayerFeaturePolicy = .default

    private var playerModule: PlayerModule?
    private var kollusAdapter: KollusPlayerAdapter?
    private let binder = PlayerStateBinder()
    private let viewModel = KollusPlayerStateViewModel()

    private let surfaceView = KollusPlayerRenderSurfaceView()
    private let controlsView = KollusPlayerControlsView()

    private var lifecycleCoordinator: PlayerLifecycleCoordinator?
    private var hasStartedPlayback = false

    init(moduleFactory: KollusPlayerModuleFactory, mediaContentKey: String) {
        self.moduleFactory = moduleFactory
        self.mediaContentKey = mediaContentKey
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Kollus Player"
        view.backgroundColor = .systemBackground
        controlsView.delegate = self
        configureLayout()
        controlsView.render(state: viewModel.state)
        Task { @MainActor [weak self] in
            await self?.setupModule()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        guard hasStartedPlayback == false else {
            return
        }
        hasStartedPlayback = true

        Task { @MainActor [weak self] in
            guard let self else { return }
            guard let playerModule = self.playerModule else { return }

            do {
                try await playerModule.startPlaybackUseCase.execute(
                    source: .kollus(mediaContentKey: self.mediaContentKey),
                    policy: self.featurePolicy
                )
            } catch {
                self.controlsView.render(
                    state: self.viewModel.apply(event: .didFail(.engineError(error.localizedDescription))) ?? self.viewModel.state
                )
            }
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        if isBeingDismissed || isMovingFromParent {
            lifecycleCoordinator?.stop()
            binder.unbind()

            Task { [weak self] in
                guard let self else { return }
                await self.playerModule?.engine.unbindRenderSurface()
                await self.playerModule?.core.dispose()
            }
        }
    }

    private func configureLayout() {
        let contentStack = UIStackView(arrangedSubviews: [surfaceView, controlsView])
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

    private func setupModule() async {
        let module = await moduleFactory.makeModule()
        playerModule = module
        kollusAdapter = module.engine as? KollusPlayerAdapter

        let coordinator = PlayerLifecycleCoordinator(
            controlUseCase: module.controlPlaybackUseCase,
            policy: featurePolicy,
            engineCapabilities: module.engineCapabilities,
            onEvent: { [weak self] event in
                self?.handle(event: event)
            }
        )
        lifecycleCoordinator = coordinator
        coordinator.start()

        binder.bind(
            observeUseCase: module.observePlaybackStateUseCase,
            onState: { [weak self] state in
                guard let self else { return }
                self.controlsView.render(state: self.viewModel.apply(playbackState: state))
            },
            onEvent: { [weak self] event in
                self?.handle(event: event)
            }
        )

        await module.engine.bind(renderSurface: surfaceView)
    }

    private func handle(event: PlayerEvent) {
        if let next = viewModel.apply(event: event) {
            controlsView.render(state: next)
        }
    }
}

extension KollusPlayerShellViewController: KollusPlayerControlsViewDelegate {
    func kollusPlayerControlsViewDidTapPlayPause(_ view: KollusPlayerControlsView) {
        Task { @MainActor [weak self] in
            guard let self, let module = self.playerModule else { return }
            let command: PlaybackCommand = self.viewModel.state.playPauseTitle == "Pause" ? .pause : .play
            try? await module.controlPlaybackUseCase.execute(command: command)
        }
    }

    func kollusPlayerControlsView(_ view: KollusPlayerControlsView, didRequestSeekProgress progress: Double) {
        Task { [weak self] in
            guard let self, let adapter = self.kollusAdapter else { return }
            let snapshot = await adapter.currentState
            let target = snapshot.duration * progress
            try? await adapter.seek(to: target)
        }
    }

    func kollusPlayerControlsView(_ view: KollusPlayerControlsView, didSelectPlaybackRate rate: Double) {
        Task { @MainActor [weak self] in
            guard let self, let adapter = self.kollusAdapter else { return }
            try? await adapter.setPlaybackRate(rate)
            self.controlsView.render(state: self.viewModel.setPlaybackRate(rate))
        }
    }

    func kollusPlayerControlsView(_ view: KollusPlayerControlsView, didSetSubtitleVisible isVisible: Bool) {
        Task { @MainActor [weak self] in
            guard let self, let adapter = self.kollusAdapter else { return }
            try? await adapter.setSubtitleVisible(isVisible)
            self.controlsView.render(state: self.viewModel.setSubtitleVisible(isVisible))
        }
    }

    func kollusPlayerControlsView(_ view: KollusPlayerControlsView, didSetCaptionFontSize fontSize: Int) {
        Task { @MainActor [weak self] in
            guard let self, let adapter = self.kollusAdapter else { return }
            try? await adapter.setCaptionFontSize(fontSize)
            self.controlsView.render(state: self.viewModel.setCaptionFontSize(fontSize))
        }
    }

    func kollusPlayerControlsView(_ view: KollusPlayerControlsView, didSetDisplayLocked isLocked: Bool) {
        // Stage 1: 데모 목적 — viewModel 상태만 반영. 실 구현은 별도 LMS 채널.
        controlsView.render(state: viewModel.setDisplayLocked(isLocked))
    }

    func kollusPlayerControlsViewDidTapClose(_ view: KollusPlayerControlsView) {
        if let nav = navigationController, nav.viewControllers.first !== self {
            nav.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }
}
