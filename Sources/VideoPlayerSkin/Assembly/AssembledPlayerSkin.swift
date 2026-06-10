//
//  AssembledPlayerSkin.swift
//  VideoPlayerSkin
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import UIKit

/// 블루프린트를 소비해 고정 스켈레톤 슬롯에 블럭을 조립하는 PlayerSkin.
/// 스켈레톤(슬롯 위치 + 반응형 + lock 게이트)은 패키지가 소유, 내용물은 blueprint 가 채운다.
public final class AssembledPlayerSkin: UIView, PlayerSkin {
    public var view: UIView { self }
    public var onAction: ((PlayerSkinAction) -> Void)?

    private let blueprint: PlayerSkinBlueprint
    private let theme: PlayerSkinTheme
    private let topBarBackground = UIView()
    private let bottomBarBackground = UIView()
    private let captionOverlay: PlayerSkinCaptionOverlay
    private let loadingOverlay: PlayerSkinLoadingOverlay
    private let gestureHUDOverlay: PlayerSkinGestureHUDOverlay
    private let seekPreviewPresenter = PlayerSeekPreviewPresenter()
    private let captureShield = PlayerScreenCaptureShieldView()
    private var captureMonitor: PlayerScreenCaptureMonitor?
    private var isCaptureProtectionEnabled = false
    private var slotContainers: [PlayerSkinSlot: UIStackView] = [:]
    private var blocks: [PlayerSkinBlock] = []
    private var latestState = PlayerSkinState.initial
    private var floatingBottomConstraint: NSLayoutConstraint?
    private var captionBottomInset: CGFloat = 5

    public init(blueprint: PlayerSkinBlueprint = .default,
                theme: PlayerSkinTheme = .default) {
        self.blueprint = blueprint
        self.theme = theme
        self.captionOverlay = blueprint.overlays.makeCaptionOverlay()
        self.loadingOverlay = blueprint.overlays.makeLoadingOverlay()
        self.gestureHUDOverlay = blueprint.overlays.makeGestureHUDOverlay()
        super.init(frame: .zero)
        buildSkeleton()
        assembleBlocks()
        configureCaptureMonitor()
        render(.initial)
    }
    @available(*, unavailable) public required init?(coder: NSCoder) { fatalError() }

    // MARK: PlayerSkin
    public func configure(title: String, maxPlaybackRate: Double) {
        blocks.compactMap { $0 as? TitleBlock }.forEach { $0.setTitle(title) }
    }
    public func updateSkipIntervalLabel(seconds: Int) {
        blocks.compactMap { $0 as? SkipButtonBlock }.forEach { $0.setInterval(seconds: seconds) }
        blocks.compactMap { $0 as? CenterPlaybackControlsBlock }.forEach { $0.setInterval(seconds: seconds) }
    }
    public func setExtraControls(_ controls: [ExtraControl]) {
        blocks.compactMap { $0 as? TopMenuExtraControlsBlock }.forEach { $0.setExtraControls(controls) }
        blocks.compactMap { $0 as? ExtraControlsRailBlock }.forEach { $0.setExtraControls(controls) }
        blocks.compactMap { $0 as? ExtraFloatingBlock }.forEach { $0.setExtraControls(controls) }
        render(latestState)
    }
    public func render(_ state: PlayerSkinState) {
        latestState = state
        // 드래그 도중 잠금되면 touchCancel을 기다리지 않고 모달을 닫는다.
        if state.isLocked { seekPreviewPresenter.end() }
        applyLegacyMetrics(state)
        applyVisibility(state)
        blocks.forEach { $0.render(state, theme: theme) }
        if state.isLoading {
            loadingOverlay.setLoading(true)
        } else {
            loadingOverlay.setLoading(false)
        }
    }
    public func showGestureHUD(
        icon: String,
        title: String,
        detail: String? = nil,
        emphasized: Bool = false
    ) {
        gestureHUDOverlay.show(icon: icon, title: title, detail: detail, emphasized: emphasized)
    }
    public func presentRateGestureHUD(_ rate: Double) {
        gestureHUDOverlay.presentRate(rate)
    }
    public func hideGestureHUD() {
        gestureHUDOverlay.hide()
    }
    /// host가 주입하는 시킹 프리뷰 썸네일 공급자. nil이면 시간 라벨만 표시된다.
    public var seekPreviewImageProvider: ((TimeInterval) async -> UIImage?)? {
        get { seekPreviewPresenter.imageProvider }
        set { seekPreviewPresenter.imageProvider = newValue }
    }

    /// 시킹 프리뷰 모달 on/off. off 전환 시 표시 중이면 즉시 닫는다.
    public func setSeekPreviewEnabled(_ enabled: Bool) {
        seekPreviewPresenter.isEnabled = enabled
        if enabled == false { seekPreviewPresenter.end() }
    }

    /// 화면 캡처(녹화) 상태 변경 콜백 — 차단막 사용 여부와 무관하게 발행된다.
    /// host가 일시정지 등 재생 정책을 결정할 수 있다.
    /// 주의: AirPlay 화면 미러링도 캡처로 판정된다(iOS 동작).
    public var onScreenCaptureChanged: ((Bool) -> Void)?

    /// 현재 화면이 캡처(녹화/미러링)되고 있는지.
    public var isScreenCaptured: Bool { captureMonitor?.isCaptured ?? false }

    /// 화면 캡처 차단막 on/off. 켜면 캡처 중 영상 영역을 차단막으로 가리고
    /// 시킹 프리뷰 모달을 닫는다. 컨트롤 터치는 막지 않는다.
    public func setScreenCaptureProtectionEnabled(_ enabled: Bool) {
        isCaptureProtectionEnabled = enabled
        captureMonitor?.refresh()
        applyCaptureShield()
    }

    public func updateCaption(text: String, isSecondary: Bool) {
        captionOverlay.update(text: text, isSecondary: isSecondary)
    }
    public func setCaptionFontSize(_ size: Int) {
        captionOverlay.applyFontSize(size)
    }
    public func setCaptionVisible(_ visible: Bool) {
        captionOverlay.setVisible(visible)
    }
    public func setCaptionBottomInset(_ inset: CGFloat) {
        captionBottomInset = inset
        applyCaptionBottomInset()
    }
    public func updateCaptionVideoFrame(_ frame: CGRect) {
        applyCaptionBottomInset()
    }

    // MARK: 스켈레톤
    private func buildSkeleton() {
        backgroundColor = .clear
        topBarBackground.translatesAutoresizingMaskIntoConstraints = false
        bottomBarBackground.translatesAutoresizingMaskIntoConstraints = false
        addSubview(topBarBackground); addSubview(bottomBarBackground)
        let captionView = captionOverlay.view
        captionView.translatesAutoresizingMaskIntoConstraints = false
        insertSubview(captionView, at: 0)
        // 로딩 ring 은 배경 위·슬롯(컨트롤) 아래 z-order. non-interactive 라 tap 에 영향 없음.
        let loadingView = loadingOverlay.view
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        loadingOverlay.configure(theme: theme)
        addSubview(loadingView)
        NSLayoutConstraint.activate([
            captionView.topAnchor.constraint(equalTo: topAnchor),
            captionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            captionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            captionView.bottomAnchor.constraint(equalTo: bottomAnchor),

            topBarBackground.topAnchor.constraint(equalTo: topAnchor),
            topBarBackground.leadingAnchor.constraint(equalTo: leadingAnchor),
            topBarBackground.trailingAnchor.constraint(equalTo: trailingAnchor),
            topBarBackground.heightAnchor.constraint(equalToConstant: 50),
            bottomBarBackground.bottomAnchor.constraint(equalTo: bottomAnchor),
            bottomBarBackground.leadingAnchor.constraint(equalTo: leadingAnchor),
            bottomBarBackground.trailingAnchor.constraint(equalTo: trailingAnchor),
            bottomBarBackground.heightAnchor.constraint(equalToConstant: 50),
            loadingView.topAnchor.constraint(equalTo: topAnchor),
            loadingView.leadingAnchor.constraint(equalTo: leadingAnchor),
            loadingView.trailingAnchor.constraint(equalTo: trailingAnchor),
            loadingView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        PlayerSkinSlot.allCases.forEach { slot in
            let stack = UIStackView()
            stack.translatesAutoresizingMaskIntoConstraints = false
            let layout = blueprint.layouts[slot] ?? PlayerSkinSlotLayout()
            stack.axis = (slot == .leftRail || slot == .rightRail) ? .vertical : .horizontal
            stack.spacing = layout.spacing
            stack.alignment = (slot == .bottomBar || slot == .centerControls) ? .fill : .center
            slotContainers[slot] = stack
            addSubview(stack)
            positionSlot(slot, stack)
        }
        addSubview(seekPreviewPresenter.view)

        let gestureHUDView = gestureHUDOverlay.view
        gestureHUDView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(gestureHUDView)
        NSLayoutConstraint.activate([
            gestureHUDView.topAnchor.constraint(equalTo: topAnchor),
            gestureHUDView.leadingAnchor.constraint(equalTo: leadingAnchor),
            gestureHUDView.trailingAnchor.constraint(equalTo: trailingAnchor),
            gestureHUDView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        // 캡처 차단막은 최상단 — 프리뷰 모달/HUD 포함 전부를 가린다.
        captureShield.isHidden = true
        captureShield.translatesAutoresizingMaskIntoConstraints = false
        addSubview(captureShield)
        NSLayoutConstraint.activate([
            captureShield.topAnchor.constraint(equalTo: topAnchor),
            captureShield.leadingAnchor.constraint(equalTo: leadingAnchor),
            captureShield.trailingAnchor.constraint(equalTo: trailingAnchor),
            captureShield.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    // MARK: 화면 캡처 대응
    private func configureCaptureMonitor() {
        // UIScreen.main 대신 소속 윈도우의 screen을 읽는다 — 윈도우 밖이면 비캡처로 본다.
        let monitor = PlayerScreenCaptureMonitor { [weak self] in
            self?.window?.windowScene?.screen.isCaptured ?? false
        }
        monitor.onChange = { [weak self] captured in
            guard let self else { return }
            self.applyCaptureShield()
            if captured, self.isCaptureProtectionEnabled {
                self.seekPreviewPresenter.end()
            }
            self.onScreenCaptureChanged?(captured)
        }
        captureMonitor = monitor
    }

    private func applyCaptureShield() {
        captureShield.isHidden = !(isCaptureProtectionEnabled && isScreenCaptured)
    }

    /// 윈도우 attach 전에는 캡처 상태를 알 수 없다 — attach 시점에 재평가.
    public override func didMoveToWindow() {
        super.didMoveToWindow()
        captureMonitor?.refresh()
    }

    private func positionSlot(_ slot: PlayerSkinSlot, _ stack: UIStackView) {
        let inset: CGFloat = 20
        switch slot {
        case .topLeading:
            NSLayoutConstraint.activate([
                stack.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: inset),
                stack.centerYAnchor.constraint(equalTo: topBarBackground.centerYAnchor)])
        case .topCenter:
            let lead = stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: inset + 44)
            lead.priority = .defaultLow
            NSLayoutConstraint.activate([
                stack.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: inset + 52),
                stack.centerYAnchor.constraint(equalTo: topBarBackground.centerYAnchor)])
        case .topTrailing:
            NSLayoutConstraint.activate([
                stack.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -inset),
                stack.centerYAnchor.constraint(equalTo: topBarBackground.centerYAnchor)])
        case .centerControls:
            NSLayoutConstraint.activate([
                stack.leadingAnchor.constraint(equalTo: leadingAnchor),
                stack.trailingAnchor.constraint(equalTo: trailingAnchor),
                stack.centerYAnchor.constraint(equalTo: centerYAnchor)])
        case .leftRail:
            NSLayoutConstraint.activate([
                stack.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: inset),
                stack.centerYAnchor.constraint(equalTo: centerYAnchor)])
        case .rightRail:
            NSLayoutConstraint.activate([
                stack.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -inset),
                stack.centerYAnchor.constraint(equalTo: centerYAnchor)])
        case .bottomBar:
            NSLayoutConstraint.activate([
                stack.leadingAnchor.constraint(equalTo: bottomBarBackground.leadingAnchor),
                stack.trailingAnchor.constraint(equalTo: bottomBarBackground.trailingAnchor),
                stack.topAnchor.constraint(equalTo: bottomBarBackground.topAnchor),
                stack.bottomAnchor.constraint(equalTo: bottomBarBackground.bottomAnchor)])
            stack.distribution = .fill
        case .sectionRepeatRange:
            NSLayoutConstraint.activate([
                stack.centerXAnchor.constraint(equalTo: centerXAnchor),
                stack.bottomAnchor.constraint(equalTo: bottomBarBackground.topAnchor, constant: -42)
            ])
        case .floatingCenterTrailing:
            NSLayoutConstraint.activate([
                stack.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -(inset - 10)),
                stack.centerYAnchor.constraint(equalTo: centerYAnchor)])
        case .floatingBottomTrailing:
            let bottom = stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -48)
            floatingBottomConstraint = bottom
            NSLayoutConstraint.activate([
                stack.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -inset),
                bottom])
        }
    }

    private func assembleBlocks() {
        for slot in PlayerSkinSlot.allCases {
            guard let container = slotContainers[slot], let makers = blueprint.blocks[slot] else { continue }
            for make in makers {
                let block = make()
                block.onAction = { [weak self] action in
                    self?.interceptForSeekPreview(action)
                    self?.onAction?(action)
                }
                container.addArrangedSubview(block.view)
                blocks.append(block)
            }
        }
        for bar in blocks.compactMap({ $0 as? ProgressBarBlock }) {
            bar.onScrubTick = { [weak self, weak bar] time in
                guard let self, let bar else { return }
                self.seekPreviewPresenter.move(
                    time: time,
                    anchor: bar.seekPreviewAnchor(in: self),
                    in: self.bounds
                )
            }
        }
    }

    /// 시킹 프리뷰 모달은 skin이 자체 처리한다 — host 라우팅과 무관하게 액션을 관찰만 한다.
    private func interceptForSeekPreview(_ action: PlayerSkinAction) {
        switch action {
        case .seekBegan:
            guard latestState.isSeekEnabled, latestState.duration > 0 else { return }
            // 캡처 중엔 모달을 띄우지 않는다 — 차단막이 가리긴 하지만 디코드 비용도 아낀다.
            if isCaptureProtectionEnabled, isScreenCaptured { return }
            seekPreviewPresenter.begin()
            if let bar = blocks.compactMap({ $0 as? ProgressBarBlock }).first {
                seekPreviewPresenter.requestImage(at: bar.currentPreviewTime)
            }
        case .seekPreviewChanged(let time):
            seekPreviewPresenter.requestImage(at: time)
        case .seekEnded:
            seekPreviewPresenter.end()
        default:
            break
        }
    }

    private func applyLegacyMetrics(_ state: PlayerSkinState) {
        let usesPadMetrics = traitCollection.userInterfaceIdiom == .pad && state.layoutMode == .fullScreen
        slotContainers[.topTrailing]?.spacing = usesPadMetrics ? 12 : 8
        slotContainers[.leftRail]?.spacing = usesPadMetrics ? 10 : 0
        let nextEpisodeOffset: CGFloat
        if usesPadMetrics {
            nextEpisodeOffset = -72
        } else if state.layoutMode == .verticalSplit {
            nextEpisodeOffset = -48
        } else {
            nextEpisodeOffset = -60
        }
        floatingBottomConstraint?.constant = nextEpisodeOffset
    }

    /// 반응형 슬롯 노출 + controlsVisible/lock 게이트.
    private func applyVisibility(_ state: PlayerSkinState) {
        let visible = blueprint.visibleSlots[state.layoutMode] ?? Set(PlayerSkinSlot.allCases)
        let controlsVisible = state.controlsVisible
        let baseVisible = controlsVisible && !state.isLocked

        backgroundColor = controlsVisible ? UIColor.black.withAlphaComponent(0.5) : .clear

        topBarBackground.alpha = controlsVisible ? 1 : 0
        bottomBarBackground.alpha = baseVisible ? 1 : 0
        topBarBackground.isHidden = !controlsVisible
        bottomBarBackground.isHidden = !baseVisible

        for (slot, container) in slotContainers {
            let inMode = visible.contains(slot)
            let isLockSurvivor = state.isLocked && (slot == .topCenter || slot == .topTrailing)
            let alpha: CGFloat = inMode ? ((baseVisible || (controlsVisible && isLockSurvivor)) ? 1 : 0) : 0
            container.alpha = alpha
            container.isHidden = alpha == 0
            container.isUserInteractionEnabled = (alpha > 0)
        }
    }

    private func applyCaptionBottomInset() {
        guard abs(captionOverlay.bottomInset - captionBottomInset) > 0.5 else { return }
        captionOverlay.bottomInset = captionBottomInset
    }
}
