//
//  PlayerViewController.swift
//  VideoPlayerExample
//
//  Created by JunyoungJung on 2026/06/05.
//
//  플레이어 화면 — skin/캡션/HUD/렌더 서피스 조립 + PlayerSkinAction 라우팅만 담당.
//  재생 제어와 모듈 수명은 PlayerInteractor, 상태 변환은 PlayerStateViewModel 소관 (SRP).
//

import UIKit
import VideoPlayerCore
import VideoPlayerSkin

@MainActor
final class PlayerViewController: UIViewController {
    private let interactor: PlayerInteractor
    private let viewModel: PlayerStateViewModel
    private let deviceControl = DeviceControlService()

    // 전부 VideoPlayerSkin 기성품 — Example 자체 컨트롤 뷰 없음 (문서 §3).
    private let renderSurfaceView = PlayerRenderSurfaceView()
    private let skin = AssembledPlayerSkin(blueprint: .example)
    private let toastLabel = UILabel()

    private enum Metric {
        static let captionBottomInset: CGFloat = 5
        static let controlsAutoHideDelayNanoseconds: UInt64 = 3_000_000_000
        static let horizontalSeekPointsPerSecond: CGFloat = 15
    }

    private enum PanGestureMode {
        case none
        case move
        case horizontalSeek
        case verticalDeviceControl
    }

    private var hasResolvedInitialLayout = false
    private var bookmarks: [Bookmark] = []
    private var toastDismissTask: Task<Void, Never>?
    private var controlsAutoHideTask: Task<Void, Never>?
    /// 팬 제스처 시작 시점의 좌/우 — 도중 중심선 통과로 밝기↔음량이 바뀌지 않도록 고정.
    private var panIsLeftSide = false
    private var panGestureMode: PanGestureMode = .none
    private var panSeekStartTime: TimeInterval = 0
    private var panSeekTargetTime: TimeInterval = 0
    private weak var doubleTapRecognizer: UITapGestureRecognizer?

    // MARK: - Embed seam (split 컨테이너 호스팅용)

    /// split 컨테이너에 child 로 embed 될 때 true. 자체 회전 기반 skin 모드 resolve 를 끄고,
    /// 컨테이너가 applySkinLayoutMode(_:) 로 모드를 명시 주입한다 (16:9 프레임은 항상 가로라
    /// 자체 bounds 로 판단하면 fullScreen 로 오인됨).
    var isEmbeddedInSplit = false

    /// 닫기 동작 주입 — nil 이면 modal dismiss, push embed 시 컨테이너가 pop 으로 주입.
    var onClose: (() -> Void)?

    /// skin 상태 변경 fan-out — 콘솔 메타데이터/활성 pane 갱신용.
    var onSkinStateChanged: ((PlayerSkinState) -> Void)?

    /// skin 무관 이벤트 fan-out — 콘솔 북마크/자막 pane 갱신용 (handle(event:) 와 병행).
    var onPlayerEvent: ((PlayerEvent) -> Void)?

    // MARK: - Init

    init(source: PlaybackSource, moduleProvider: PlayerModuleProviding) {
        let viewModel = PlayerStateViewModel()
        self.viewModel = viewModel

        var renderSink: (PlayerSkinState) -> Void = { _ in }
        var eventSink: (PlayerEvent) -> Void = { _ in }
        var commandErrorSink: (PlayerError) -> Void = { _ in }
        self.interactor = PlayerInteractor(
            source: source,
            moduleProvider: moduleProvider,
            viewModel: viewModel,
            onRender: { renderSink($0) },
            onEvent: { eventSink($0) },
            onCommandError: { commandErrorSink($0) }
        )
        super.init(nibName: nil, bundle: nil)
        renderSink = { [weak self] state in self?.emitRender(state) }
        eventSink = { [weak self] event in self?.handle(event: event) }
        commandErrorSink = { [weak self] error in
            self?.showToast(PlayerErrorPresentation.toastText(for: error))
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureHierarchy()
        configureGestures()
        deviceControl.attach(to: view)

        skin.onAction = { [weak self] action in self?.route(action) }
        skin.configure(title: "VideoPlayer Example", maxPlaybackRate: interactor.featurePolicy.maxPlaybackRate)
        skin.setCaptionBottomInset(Metric.captionBottomInset)
        skin.setCaptionFontSize(PreferenceManager.captionFontSize)

        // setUp → start 연속 실행 — viewDidAppear 분리 시 setUp 완료 전
        // start가 nil 모듈에 걸려 조용히 무재생되는 경쟁 조건이 생긴다 (리뷰 HIGH).
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.interactor.setUp(renderSurface: self.renderSurfaceView)
                // 기능 게이팅 — 엔진이 지원하는 기능만 버튼 노출 (런타임 실패 대신 사전 숨김).
                self.applyFeatureGating(self.interactor.availableFeatures)
                try await self.interactor.start()
                // 세팅 반영 — 자막 크기는 재생 중 즉시 적용 가능 (문서 §6).
                self.interactor.send(.setCaptionFontSize(PreferenceManager.captionFontSize))
                // 기본 배속 반영 — 설정값을 재생 시작 시 1회 적용 (SL 화면/재생 설정 parity).
                self.applyPlaybackRate(PlaybackRate.clamped(PreferenceManager.playbackRate))
            } catch {
                self.presentErrorAndClose(error)
            }
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        cancelControlsAutoHideTimer()
        if isBeingDismissed || isMovingFromParent {
            interactor.tearDown()
        }
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        // embed 시 skin 모드는 컨테이너가 applySkinLayoutMode(_:) 로 주입한다 (16:9 프레임 오인 방지).
        guard isEmbeddedInSplit == false else { return }
        guard hasResolvedInitialLayout == false else { return }
        hasResolvedInitialLayout = true
        emitRender(viewModel.resolveLayoutMode(layoutMode(for: view.bounds.size)))
    }

    /// 세로/가로 — layoutMode resolve 후 skin이 슬롯 가시성 자동 전환 (문서 §2.2.1).
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        guard isEmbeddedInSplit == false else { return }
        emitRender(viewModel.resolveLayoutMode(layoutMode(for: size)))
    }

    private func layoutMode(for size: CGSize) -> PlayerSkinLayoutMode {
        PlayerStateViewModel.isLandscape(size) ? .fullScreen : .verticalSplit
    }

    /// 컨테이너가 split/fullscreen 레이아웃 전환 시 호출 — skin 모드 명시 주입.
    func applySkinLayoutMode(_ mode: PlayerSkinLayoutMode) {
        emitRender(viewModel.resolveLayoutMode(mode))
    }

    // MARK: - 기능 게이팅 (availableFeatures)

    /// setUp 완료 후 1회 — 엔진 미지원 기능의 진입점을 사전에 숨긴다.
    private func applyFeatureGating(_ features: PlayerFeatureAvailability) {
        var extraControls: [ExtraControl] = []
        if features.contains(.bookmarks) {
            extraControls.append(
                ExtraControl(id: ExtraControlID.bookmark, iconName: "bookmark", title: "북마크", placement: .topMenu)
            )
        }
        skin.setExtraControls(extraControls)
    }

    // MARK: - 렌더 fan-out

    /// skin 렌더 단일 통로 — skin 갱신 + 콘솔 fan-out 을 한곳에서 보장.
    private func emitRender(_ state: PlayerSkinState) {
        skin.render(state)
        onSkinStateChanged?(state)
        updateControlsAutoHideTimer(for: state)
    }

    // MARK: - 뷰 계층

    private func configureHierarchy() {
        // 아래→위: 렌더 서피스 → skin(컨트롤/자막/HUD 오버레이) → 토스트
        for subview in [renderSurfaceView, skin, toastLabel] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(subview)
        }

        toastLabel.textColor = .white
        toastLabel.font = .systemFont(ofSize: 14, weight: .medium)
        toastLabel.textAlignment = .center
        toastLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        toastLabel.layer.cornerRadius = 8
        toastLabel.clipsToBounds = true
        toastLabel.alpha = 0

        NSLayoutConstraint.activate([
            renderSurfaceView.topAnchor.constraint(equalTo: view.topAnchor),
            renderSurfaceView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            renderSurfaceView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            renderSurfaceView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            skin.topAnchor.constraint(equalTo: view.topAnchor),
            skin.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            skin.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            skin.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            toastLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toastLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -100),
            toastLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 200),
            toastLabel.heightAnchor.constraint(equalToConstant: 36)
        ])
    }

    // MARK: - 제스처 (컨트롤 토글 / 핀치줌 / 밝기·음량)

    private func configureGestures() {
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(didDoubleTapSurface))
        doubleTap.numberOfTapsRequired = 2
        doubleTap.cancelsTouchesInView = true
        doubleTap.delegate = self
        doubleTapRecognizer = doubleTap
        view.addGestureRecognizer(doubleTap)

        let tap = UITapGestureRecognizer(target: self, action: #selector(didTapSurface))
        tap.delegate = self
        tap.require(toFail: doubleTap)
        view.addGestureRecognizer(tap)

        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(didPinch))
        view.addGestureRecognizer(pinch)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(didPan))
        pan.delegate = self
        view.addGestureRecognizer(pan)
    }

    @objc private func didTapSurface() {
        emitRender(viewModel.toggleControlsVisible())
    }

    @objc private func didDoubleTapSurface(_ recognizer: UITapGestureRecognizer) {
        guard PreferenceManager.useGesture else { return }
        guard viewModel.state.isLocked == false else { return }
        resetControlsAutoHideTimer()

        if PreferenceManager.useDoubleTapSkip {
            let isForward = recognizer.location(in: view).x >= view.bounds.midX
            let interval = TimeInterval(PreferenceManager.seekRangeSeconds)
            interactor.seekBy(isForward ? interval : -interval)
            skin.showGestureHUD(
                icon: isForward ? "PlayerForwardGestureNormal" : "PlayerBackwardGestureNormal",
                title: "\(isForward ? "+" : "-")\(PreferenceManager.seekRangeSeconds)초"
            )
        } else {
            let willPause = viewModel.state.isPlaying
            interactor.togglePlayPause()
            skin.showGestureHUD(
                icon: willPause ? "pause.fill" : "play.fill",
                title: willPause ? "일시정지" : "재생"
            )
        }
    }

    @objc private func didPinch(_ recognizer: UIPinchGestureRecognizer) {
        guard PreferenceManager.useGesture else { return }
        resetControlsAutoHideTimer()
        interactor.applyZoom(recognizer)
        if recognizer.state == .ended || recognizer.state == .cancelled {
            interactor.refreshZoomState()
        }
    }

    /// 수평 팬 = 시킹, 수직 팬 = 좌측 밝기/우측 음량, 확대 상태 팬 = 화면 이동.
    @objc private func didPan(_ recognizer: UIPanGestureRecognizer) {
        guard PreferenceManager.useGesture else { return }
        guard viewModel.state.isLocked == false else { return }
        let translation = recognizer.translation(in: view)
        if recognizer.state == .began {
            resetControlsAutoHideTimer()
            configurePanMode(recognizer, initialTranslation: translation)
        }
        recognizer.setTranslation(.zero, in: view)

        switch panGestureMode {
        case .move:
            switch recognizer.state {
            case .changed:
                interactor.scroll(by: translation)
            case .ended, .cancelled, .failed:
                interactor.stopScroll()
                panGestureMode = .none
                resetControlsAutoHideTimer()
            default:
                break
            }
            return
        case .horizontalSeek:
            switch recognizer.state {
            case .changed:
                updateHorizontalSeekPreview(translation: translation)
            case .ended:
                updateHorizontalSeekPreview(translation: translation)
                interactor.send(.seek(to: panSeekTargetTime))
                panGestureMode = .none
                resetControlsAutoHideTimer()
            case .cancelled, .failed:
                skin.hideGestureHUD()
                panGestureMode = .none
                resetControlsAutoHideTimer()
            default:
                break
            }
        case .verticalDeviceControl:
            let delta = -translation.y / view.bounds.height
            switch recognizer.state {
            case .changed:
                if panIsLeftSide {
                    let value = deviceControl.adjustBrightness(by: delta)
                    skin.showGestureHUD(icon: "PlayerBrightnessNormal", title: "\(Int(value * 100))%")
                } else {
                    let value = deviceControl.adjustVolume(by: Float(delta))
                    skin.showGestureHUD(icon: "PlayerVolumeNormal", title: "\(Int(value * 100))%")
                }
            case .ended, .cancelled, .failed:
                skin.hideGestureHUD()
                panGestureMode = .none
                resetControlsAutoHideTimer()
            default:
                break
            }
        case .none:
            break
        }
    }

    // MARK: - PlayerSkinAction 라우팅 (유일한 컨트롤 입력 채널)

    private func route(_ action: PlayerSkinAction) {
        resetControlsAutoHideTimer()
        switch action {
        case .togglePlayPause:
            interactor.togglePlayPause()
        case .skipBackward:
            interactor.seekBy(-TimeInterval(PreferenceManager.seekRangeSeconds))
        case .skipForward:
            interactor.seekBy(TimeInterval(PreferenceManager.seekRangeSeconds))
        case .seekBegan:
            interactor.send(.pause)   // 스크럽 동안 freeze — 레거시 parity
        case .seekPreviewChanged:
            break
        case .seekEnded(let time):
            interactor.send(.seek(to: time))
            interactor.send(.play)
        case .rateSelected(let rate):
            applyPlaybackRate(rate)
        case .rateStepUp:
            applyPlaybackRate(min(viewModel.state.playbackRate + 0.1, interactor.featurePolicy.maxPlaybackRate))
        case .rateStepDown:
            applyPlaybackRate(max(viewModel.state.playbackRate - 0.1, 0.5))
        case .rateToggleCenter, .ratePanelRequested:
            presentRatePanel()
        case .toggleDisplayScaling:
            interactor.send(.toggleDisplayScaling)
        case .toggleScreenMode:
            toggleScreenMode()
        case .holdToggleRequested:
            emitRender(viewModel.toggleLock())
        case .sectionRepeatToggleRequested, .sectionRepeatStartRequested, .sectionRepeatEndRequested:
            interactor.handleSectionRepeat(action)
        case .extraControlTapped(let id):
            handleExtraControl(id)
        case .settingRequested, .moreRequested:
            showToast("데모 미구현 항목")
        case .closeRequested:
            // push embed 시 컨테이너 pop, modal 시 dismiss. 정리는 viewDidDisappear → interactor.tearDown()
            if let onClose {
                onClose()
            } else {
                dismiss(animated: false)
            }
        }
    }

    private func applyPlaybackRate(_ rate: Double) {
        interactor.send(.setPlaybackRate(rate))
        emitRender(viewModel.setPlaybackRate(rate))
    }

    /// 화면 모드 버튼 — 세로/가로 전환 요청 (iOS 16+: 지오메트리 요청, 이하: 시스템 회전 유도).
    private func toggleScreenMode() {
        let isFullScreen = viewModel.state.isFullScreenMode
        if #available(iOS 16.0, *) {
            let orientation: UIInterfaceOrientationMask = isFullScreen ? .portrait : .landscapeRight
            view.window?.windowScene?.requestGeometryUpdate(.iOS(interfaceOrientations: orientation))
        } else {
            let orientation: UIInterfaceOrientation = isFullScreen ? .portrait : .landscapeRight
            UIDevice.current.setValue(orientation.rawValue, forKey: "orientation")
        }
    }

    // MARK: - 배속 패널

    private func presentRatePanel() {
        emitRender(viewModel.setRatePanelPresented(true))
        let panel = PlayerPlaybackRatePanelViewController(
            initialRate: viewModel.state.playbackRate,
            mode: .standard,
            isFullScreenMode: viewModel.state.isFullScreenMode
        )
        panel.onSelectRate = { [weak self, weak panel] rate, shouldDismiss in
            guard let self else { return }
            self.applyPlaybackRate(rate)
            if shouldDismiss {
                panel?.dismiss(animated: true)
                self.emitRender(self.viewModel.setRatePanelPresented(false))
            }
        }
        panel.onDismiss = { [weak self, weak panel] in
            panel?.dismiss(animated: true)
            guard let self else { return }
            self.emitRender(self.viewModel.setRatePanelPresented(false))
        }
        present(panel, animated: true)
    }

    // MARK: - ExtraControl (북마크)

    private enum ExtraControlID {
        static let bookmark = "bookmark"
    }

    private func handleExtraControl(_ id: String) {
        guard id == ExtraControlID.bookmark else { return }
        presentBookmarkSheet()
    }

    private func presentBookmarkSheet() {
        let sheet = UIAlertController(title: "북마크", message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "현재 위치 추가", style: .default) { [weak self] _ in
            guard let self else { return }
            self.interactor.send(.addBookmark(at: self.viewModel.state.currentTime))
        })
        for bookmark in bookmarks {
            let title = PlayerSkinState.formatTime(bookmark.position)
            sheet.addAction(UIAlertAction(title: "이동 — \(title)", style: .default) { [weak self] _ in
                self?.interactor.send(.seek(to: bookmark.position))
            })
        }
        sheet.addAction(UIAlertAction(title: "닫기", style: .cancel))
        sheet.popoverPresentationController?.sourceView = view
        sheet.popoverPresentationController?.sourceRect = CGRect(
            x: view.bounds.midX, y: view.bounds.minY + 60, width: 1, height: 1
        )
        present(sheet, animated: true)
    }

    // MARK: - PlayerEvent (skin 상태 무관 이벤트)

    private func handle(event: PlayerEvent) {
        onPlayerEvent?(event)   // 콘솔 pane fan-out (북마크/자막) — VC 자체 처리와 병행.
        switch event {
        case .captionDidUpdate(let text, let isSecondary):
            skin.updateCaption(text: text, isSecondary: isSecondary)
        case .videoFrameDidChange(let frame):
            skin.updateCaptionVideoFrame(frame)
        case .bookmarksDidLoad(let loaded):
            bookmarks = loaded.sorted { $0.position < $1.position }
        case .didFail(let error):
            presentErrorAndClose(error)
        case .policyDowngraded(let reason):
            switch reason {
            case .missingContinuesWithoutSurface:
                showToast("백그라운드 재생 미지원 — 일시정지됩니다")
            case .custom(let message):
                showToast(message)
            }
        default:
            break
        }
    }

    // MARK: - 알림/토스트

    private func presentErrorAndClose(_ error: Error) {
        let message = PlayerErrorPresentation.message(for: error)
        let body = [message.body, message.recoverySuggestion]
            .compactMap { $0 }
            .joined(separator: "\n\n")
        let alert = UIAlertController(
            title: message.title,
            message: body,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "닫기", style: .default) { [weak self] _ in
            self?.dismiss(animated: false)
        })
        present(alert, animated: true)
    }

    private func showToast(_ message: String) {
        toastLabel.text = "  \(message)  "
        view.bringSubviewToFront(toastLabel)
        UIView.animate(withDuration: 0.2) { [weak self] in self?.toastLabel.alpha = 1 }
        // 연속 토스트 시 이전 dismiss 예약을 취소 — 새 메시지가 2초를 온전히 보장받는다.
        toastDismissTask?.cancel()
        toastDismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard Task.isCancelled == false else { return }
            UIView.animate(withDuration: 0.3) { self?.toastLabel.alpha = 0 }
        }
    }

    private func configurePanMode(_ recognizer: UIPanGestureRecognizer, initialTranslation: CGPoint) {
        if interactor.isZoomedIn {
            panGestureMode = .move
            return
        }

        let velocity = recognizer.velocity(in: view)
        let horizontal = max(abs(velocity.x), abs(initialTranslation.x))
        let vertical = max(abs(velocity.y), abs(initialTranslation.y))

        if horizontal > vertical {
            guard viewModel.state.isSeekEnabled else {
                panGestureMode = .none
                return
            }
            panGestureMode = .horizontalSeek
            panSeekStartTime = viewModel.state.currentTime
            panSeekTargetTime = viewModel.state.currentTime
        } else {
            panGestureMode = .verticalDeviceControl
            panIsLeftSide = recognizer.location(in: view).x < view.bounds.midX
        }
    }

    private func updateHorizontalSeekPreview(translation: CGPoint) {
        guard viewModel.state.duration > 0 else { return }
        let delta = TimeInterval(translation.x / Metric.horizontalSeekPointsPerSecond)
        guard delta != 0 else { return }

        panSeekTargetTime = min(max(0, panSeekTargetTime + delta), viewModel.state.duration)
        let accumulatedDelta = panSeekTargetTime - panSeekStartTime
        let isForward = accumulatedDelta >= 0
        let seconds = Int(abs(accumulatedDelta).rounded())
        skin.showGestureHUD(
            icon: isForward ? "PlayerForwardGestureNormal" : "PlayerBackwardGestureNormal",
            title: "\(isForward ? "+" : "-")\(seconds)초",
            detail: PlayerSkinState.formatTime(panSeekTargetTime)
        )
    }

    private func updateControlsAutoHideTimer(for state: PlayerSkinState) {
        if PlayerStateViewModel.shouldAutoHideControls(in: state) {
            scheduleControlsAutoHideTimerIfNeeded()
        } else {
            cancelControlsAutoHideTimer()
        }
    }

    private func resetControlsAutoHideTimer() {
        cancelControlsAutoHideTimer()
        updateControlsAutoHideTimer(for: viewModel.state)
    }

    private func scheduleControlsAutoHideTimerIfNeeded() {
        guard controlsAutoHideTask == nil else { return }
        controlsAutoHideTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: Metric.controlsAutoHideDelayNanoseconds)
            guard Task.isCancelled == false, let self else { return }
            self.controlsAutoHideTask = nil
            guard PlayerStateViewModel.shouldAutoHideControls(in: self.viewModel.state) else { return }
            self.emitRender(self.viewModel.setControlsVisible(false))
        }
    }

    private func cancelControlsAutoHideTimer() {
        controlsAutoHideTask?.cancel()
        controlsAutoHideTask = nil
    }
}

// MARK: - PlayerControlChannel (하단 콘솔 pane 제어 채널)

extension PlayerViewController: PlayerControlChannel {
    var currentSkinState: PlayerSkinState { viewModel.state }
    var loadedBookmarks: [Bookmark] { bookmarks }
    var availableFeatures: PlayerFeatureAvailability { interactor.availableFeatures }

    func togglePlayPause() {
        interactor.togglePlayPause()
    }

    func skip(by delta: TimeInterval) {
        interactor.seekBy(delta)
    }

    func seek(to time: TimeInterval) {
        interactor.send(.seek(to: time))
    }

    func setPlaybackRate(_ rate: Double) {
        applyPlaybackRate(rate)
    }

    func addBookmarkAtCurrentTime() {
        interactor.send(.addBookmark(at: viewModel.state.currentTime))
    }

    func removeBookmark(at position: TimeInterval) {
        interactor.send(.removeBookmark(at: position))
    }

    func setCaptionFontSize(_ size: Int) {
        interactor.send(.setCaptionFontSize(size))
        skin.setCaptionFontSize(size)
    }

    func setCaptionHidden(_ hidden: Bool) {
        skin.setCaptionVisible(hidden == false)
    }
}

// MARK: - UIGestureRecognizerDelegate

extension PlayerViewController: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer === doubleTapRecognizer {
            return PreferenceManager.useGesture && viewModel.state.isLocked == false
        }
        return true
    }

    /// 블록 버튼(UIControl) 터치는 토글/팬 제스처에서 제외 — 컨트롤 조작이 우선.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if gestureRecognizer === doubleTapRecognizer {
            return true
        }
        return (touch.view?.hasControlAncestor ?? false) == false
    }
}

private extension UIView {
    var hasControlAncestor: Bool {
        if self is UIControl { return true }
        return superview?.hasControlAncestor ?? false
    }
}
