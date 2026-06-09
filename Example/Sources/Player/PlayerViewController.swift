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
    private let captionView = PlayerCaptionView()
    private let gestureHUD = PlayerGestureHUDView()
    private let toastLabel = UILabel()

    private var hasResolvedInitialLayout = false
    private var bookmarks: [Bookmark] = []
    /// 팬 제스처 시작 시점의 좌/우 — 도중 중심선 통과로 밝기↔음량이 바뀌지 않도록 고정.
    private var panIsLeftSide = false

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
        self.interactor = PlayerInteractor(
            source: source,
            moduleProvider: moduleProvider,
            viewModel: viewModel,
            onRender: { renderSink($0) },
            onEvent: { eventSink($0) }
        )
        super.init(nibName: nil, bundle: nil)
        renderSink = { [weak self] state in self?.emitRender(state) }
        eventSink = { [weak self] event in self?.handle(event: event) }
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
        skin.setExtraControls([
            ExtraControl(id: ExtraControlID.bookmark, iconName: "bookmark", title: "북마크", placement: .topMenu)
        ])
        captionView.applyFontSize(PreferenceManager.captionFontSize)

        // setUp → start 연속 실행 — viewDidAppear 분리 시 setUp 완료 전
        // start가 nil 모듈에 걸려 조용히 무재생되는 경쟁 조건이 생긴다 (리뷰 HIGH).
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.interactor.setUp(renderSurface: self.renderSurfaceView)
                try await self.interactor.start()
                // 세팅 반영 — 자막 크기는 재생 중 즉시 적용 가능 (문서 §6).
                self.interactor.send(.setCaptionFontSize(PreferenceManager.captionFontSize))
            } catch {
                self.presentErrorAndClose(error)
            }
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
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
        size.width > size.height ? .fullScreen : .verticalSplit
    }

    /// 컨테이너가 split/fullscreen 레이아웃 전환 시 호출 — skin 모드 명시 주입.
    func applySkinLayoutMode(_ mode: PlayerSkinLayoutMode) {
        emitRender(viewModel.resolveLayoutMode(mode))
    }

    // MARK: - 렌더 fan-out

    /// skin 렌더 단일 통로 — skin 갱신 + 콘솔 fan-out 을 한곳에서 보장.
    private func emitRender(_ state: PlayerSkinState) {
        skin.render(state)
        onSkinStateChanged?(state)
    }

    // MARK: - 뷰 계층

    private func configureHierarchy() {
        // 아래→위: 렌더 서피스 → 자막 → skin(컨트롤 오버레이) → 제스처 HUD → 토스트
        for subview in [renderSurfaceView, captionView, skin, gestureHUD, toastLabel] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(subview)
        }
        captionView.isUserInteractionEnabled = false
        gestureHUD.isUserInteractionEnabled = false
        gestureHUD.isHidden = true

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

            captionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            captionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            captionView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -60),

            skin.topAnchor.constraint(equalTo: view.topAnchor),
            skin.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            skin.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            skin.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            gestureHUD.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            gestureHUD.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            toastLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toastLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -100),
            toastLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 200),
            toastLabel.heightAnchor.constraint(equalToConstant: 36)
        ])
    }

    // MARK: - 제스처 (컨트롤 토글 / 핀치줌 / 밝기·음량)

    private func configureGestures() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(didTapSurface))
        tap.delegate = self
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

    @objc private func didPinch(_ recognizer: UIPinchGestureRecognizer) {
        interactor.applyZoom(recognizer)
    }

    /// 좌측 팬 = 밝기, 우측 팬 = 음량 (샘플 제스처 parity).
    @objc private func didPan(_ recognizer: UIPanGestureRecognizer) {
        guard viewModel.state.isLocked == false else { return }
        let translation = recognizer.translation(in: view)
        recognizer.setTranslation(.zero, in: view)
        if recognizer.state == .began {
            panIsLeftSide = recognizer.location(in: view).x < view.bounds.midX
        }
        let delta = -translation.y / view.bounds.height

        switch recognizer.state {
        case .changed:
            if panIsLeftSide {
                let value = deviceControl.adjustBrightness(by: delta)
                gestureHUD.isHidden = false
                gestureHUD.show(icon: "sun.max", title: "\(Int(value * 100))%")
            } else {
                let value = deviceControl.adjustVolume(by: Float(delta))
                gestureHUD.isHidden = false
                gestureHUD.show(icon: "speaker.wave.2", title: "\(Int(value * 100))%")
            }
        case .ended, .cancelled, .failed:
            gestureHUD.hide()
        default:
            break
        }
    }

    // MARK: - PlayerSkinAction 라우팅 (유일한 컨트롤 입력 채널)

    private func route(_ action: PlayerSkinAction) {
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
                self.skin.render(self.viewModel.setRatePanelPresented(false))
            }
        }
        panel.onDismiss = { [weak self, weak panel] in
            panel?.dismiss(animated: true)
            guard let self else { return }
            self.skin.render(self.viewModel.setRatePanelPresented(false))
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
            captionView.update(text: text, isSecondary: isSecondary)
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
        let alert = UIAlertController(
            title: "재생 오류",
            message: error.localizedDescription,
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            UIView.animate(withDuration: 0.3) { self?.toastLabel.alpha = 0 }
        }
    }
}

// MARK: - PlayerControlChannel (하단 콘솔 pane 제어 채널)

extension PlayerViewController: PlayerControlChannel {
    var currentSkinState: PlayerSkinState { viewModel.state }
    var loadedBookmarks: [Bookmark] { bookmarks }

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
        captionView.applyFontSize(size)
    }

    func setCaptionHidden(_ hidden: Bool) {
        captionView.setVisible(hidden == false)
    }
}

// MARK: - UIGestureRecognizerDelegate

extension PlayerViewController: UIGestureRecognizerDelegate {
    /// 블록 버튼(UIControl) 터치는 토글/팬 제스처에서 제외 — 컨트롤 조작이 우선.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        (touch.view is UIControl) == false
    }
}
