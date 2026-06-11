//
//  CenterPlaybackControlsBlock.swift
//  VideoPlayerSkin
//
//  Created by 모바일팀_정준영 on 2026/06/11.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import UIKit

/// 중앙 재생 컨트롤 묶음(backward / play-pause / forward).
///
/// Fullscreen 에서는 단순 spacing 이 아니라 좌/우 side menu 영역을 제외한
/// 남은 영역의 중앙에 10초 버튼을 배치한다.
public final class CenterPlaybackControlsBlock: UIView, PlayerSkinPlaybackControlBlock {
    private enum Metric {
        static let sideMenuAreaWidth: CGFloat = 56
        static let compactSpacing: CGFloat = 24
        static let height: CGFloat = 66
    }

    public var view: UIView { self }
    public var onAction: ((PlayerSkinAction) -> Void)? {
        didSet {
            backwardBlock.onAction = onAction
            playBlock.onAction = onAction
            forwardBlock.onAction = onAction
        }
    }

    private let backwardBlock = SkipButtonBlock(.backward)
    private let playBlock = PlayButtonBlock()
    private let forwardBlock = SkipButtonBlock(.forward)

    private var fullscreenConstraints: [NSLayoutConstraint] = []
    private var compactConstraints: [NSLayoutConstraint] = []
    private var isUsingFullscreenLayout = true

    public override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func setInterval(seconds: Int) {
        backwardBlock.setInterval(seconds: seconds)
        forwardBlock.setInterval(seconds: seconds)
    }

    public func render(_ state: PlayerSkinState, theme: PlayerSkinTheme) {
        updateLayoutIfNeeded(isFullscreen: state.layoutMode == .fullScreen)
        backwardBlock.render(state, theme: theme)
        playBlock.render(state, theme: theme)
        forwardBlock.render(state, theme: theme)
    }

    func renderPlaybackState(_ state: PlayerSkinState, theme: PlayerSkinTheme) {
        playBlock.renderPlaybackState(state, theme: theme)
    }

    private func configure() {
        translatesAutoresizingMaskIntoConstraints = false
        setContentHuggingPriority(.defaultLow, for: .horizontal)
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        [backwardBlock.view, playBlock.view, forwardBlock.view].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }

        let backwardRegion = UILayoutGuide()
        let forwardRegion = UILayoutGuide()
        addLayoutGuide(backwardRegion)
        addLayoutGuide(forwardRegion)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: Metric.height),
            playBlock.view.centerXAnchor.constraint(equalTo: centerXAnchor),
            playBlock.view.centerYAnchor.constraint(equalTo: centerYAnchor),
            backwardBlock.view.centerYAnchor.constraint(equalTo: playBlock.view.centerYAnchor),
            forwardBlock.view.centerYAnchor.constraint(equalTo: playBlock.view.centerYAnchor)
        ])

        fullscreenConstraints = [
            backwardRegion.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Metric.sideMenuAreaWidth),
            backwardRegion.trailingAnchor.constraint(equalTo: playBlock.view.leadingAnchor),
            backwardBlock.view.centerXAnchor.constraint(equalTo: backwardRegion.centerXAnchor),

            forwardRegion.leadingAnchor.constraint(equalTo: playBlock.view.trailingAnchor),
            forwardRegion.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Metric.sideMenuAreaWidth),
            forwardBlock.view.centerXAnchor.constraint(equalTo: forwardRegion.centerXAnchor)
        ]

        compactConstraints = [
            backwardBlock.view.trailingAnchor.constraint(equalTo: playBlock.view.leadingAnchor, constant: -Metric.compactSpacing),
            forwardBlock.view.leadingAnchor.constraint(equalTo: playBlock.view.trailingAnchor, constant: Metric.compactSpacing)
        ]
        updateLayoutIfNeeded(isFullscreen: false)
    }

    private func updateLayoutIfNeeded(isFullscreen: Bool) {
        guard isUsingFullscreenLayout != isFullscreen else { return }
        isUsingFullscreenLayout = isFullscreen
        NSLayoutConstraint.deactivate(isFullscreen ? compactConstraints : fullscreenConstraints)
        NSLayoutConstraint.activate(isFullscreen ? fullscreenConstraints : compactConstraints)
    }
}
