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
        applyLegacyMetrics(state)
        applyVisibility(state)
        blocks.forEach { $0.render(state, theme: theme) }
        // lecture-ui-parity 05 §4.9 — preparing/buffering(state.isLoading) 시 중앙 ring 표시.
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
        // lecture-ui-parity 05 §4.9 — 로딩 ring 은 배경 위·슬롯(컨트롤) 아래. non-interactive 라 tap 무영향.
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
        let gestureHUDView = gestureHUDOverlay.view
        gestureHUDView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(gestureHUDView)
        NSLayoutConstraint.activate([
            gestureHUDView.topAnchor.constraint(equalTo: topAnchor),
            gestureHUDView.leadingAnchor.constraint(equalTo: leadingAnchor),
            gestureHUDView.trailingAnchor.constraint(equalTo: trailingAnchor),
            gestureHUDView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
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
                block.onAction = { [weak self] action in self?.onAction?(action) }
                container.addArrangedSubview(block.view)
                blocks.append(block)
            }
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

    /// 반응형 슬롯 노출 + controlsVisible/lock 게이트 (legacy `setHiddenWithControl` parity).
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
