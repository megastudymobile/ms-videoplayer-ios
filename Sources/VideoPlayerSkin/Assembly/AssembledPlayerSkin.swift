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
    private var slotContainers: [PlayerSkinSlot: UIStackView] = [:]
    private var blocks: [PlayerSkinBlock] = []
    private var latestState = PlayerSkinState.initial

    public init(blueprint: PlayerSkinBlueprint = .default,
                theme: PlayerSkinTheme = .default) {
        self.blueprint = blueprint
        self.theme = theme
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
    }
    public func setExtraControls(_ controls: [ExtraControl]) {
        blocks.compactMap { $0 as? ExtraControlsRailBlock }.forEach { $0.setExtraControls(controls) }
        blocks.compactMap { $0 as? ExtraFloatingBlock }.forEach { $0.setExtraControls(controls) }
        render(latestState)
    }
    public func render(_ state: PlayerSkinState) {
        latestState = state
        applyVisibility(state)
        blocks.forEach { $0.render(state, theme: theme) }
    }

    // MARK: 스켈레톤
    private func buildSkeleton() {
        topBarBackground.translatesAutoresizingMaskIntoConstraints = false
        bottomBarBackground.translatesAutoresizingMaskIntoConstraints = false
        addSubview(topBarBackground); addSubview(bottomBarBackground)
        NSLayoutConstraint.activate([
            topBarBackground.topAnchor.constraint(equalTo: topAnchor),
            topBarBackground.leadingAnchor.constraint(equalTo: leadingAnchor),
            topBarBackground.trailingAnchor.constraint(equalTo: trailingAnchor),
            topBarBackground.heightAnchor.constraint(equalToConstant: 50),
            bottomBarBackground.bottomAnchor.constraint(equalTo: bottomAnchor),
            bottomBarBackground.leadingAnchor.constraint(equalTo: leadingAnchor),
            bottomBarBackground.trailingAnchor.constraint(equalTo: trailingAnchor),
            bottomBarBackground.heightAnchor.constraint(equalToConstant: 50)
        ])
        PlayerSkinSlot.allCases.forEach { slot in
            let stack = UIStackView()
            stack.translatesAutoresizingMaskIntoConstraints = false
            let layout = blueprint.layouts[slot] ?? PlayerSkinSlotLayout()
            stack.axis = (slot == .leftRail || slot == .rightRail) ? .vertical : .horizontal
            stack.spacing = layout.spacing
            stack.alignment = (slot == .bottomBar) ? .fill : .center
            slotContainers[slot] = stack
            addSubview(stack)
            positionSlot(slot, stack)
        }
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
                stack.centerXAnchor.constraint(equalTo: centerXAnchor),
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
        case .floatingCenterTrailing:
            NSLayoutConstraint.activate([
                stack.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -inset),
                stack.centerYAnchor.constraint(equalTo: centerYAnchor)])
        case .floatingBottomTrailing:
            NSLayoutConstraint.activate([
                stack.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -inset),
                stack.bottomAnchor.constraint(equalTo: bottomBarBackground.topAnchor, constant: -12)])
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

    /// 반응형 슬롯 노출 + controlsVisible/lock alpha 게이트 (현 PlayerSkinControlView render parity).
    private func applyVisibility(_ state: PlayerSkinState) {
        let visible = blueprint.visibleSlots[state.layoutMode] ?? Set(PlayerSkinSlot.allCases)
        let controlsVisible = state.controlsVisible
        let baseVisible = controlsVisible && !state.isLocked

        topBarBackground.alpha = controlsVisible ? 1 : 0
        bottomBarBackground.alpha = baseVisible ? 1 : 0

        for (slot, container) in slotContainers {
            let inMode = visible.contains(slot)
            let topSlot = (slot == .topLeading || slot == .topCenter || slot == .topTrailing)
            // top 슬롯: controlsVisible 게이트(lock 중 close/unlock 노출). 나머지: baseVisible.
            let alpha: CGFloat = inMode ? (topSlot ? (controlsVisible ? 1 : 0) : (baseVisible ? 1 : 0)) : 0
            container.alpha = alpha
            container.isUserInteractionEnabled = (alpha > 0)
        }
    }
}
