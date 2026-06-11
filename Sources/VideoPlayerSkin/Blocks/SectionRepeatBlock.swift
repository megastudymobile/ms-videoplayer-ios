//
//  SectionRepeatBlock.swift
//  VideoPlayerSkin
//
//  Created by 모바일팀_정준영 on 2026/06/11.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import UIKit

public final class SectionRepeatBlock: UIView, PlayerSkinBlock {
    public var view: UIView { self }
    public var onAction: ((PlayerSkinAction) -> Void)?
    private let button = PlayerSkinIconButtonFactory.make()
    public override init(frame: CGRect) {
        super.init(frame: frame); pin(button)
        button.accessibilityIdentifier = "videoPlayer.skin.sectionRepeatButton"; button.accessibilityLabel = "구간 반복"
        button.addTarget(self, action: #selector(tap), for: .touchUpInside)
    }
    @available(*, unavailable) public required init?(coder: NSCoder) { fatalError() }
    public func render(_ state: PlayerSkinState, theme: PlayerSkinTheme) {
        let looping: Bool = { if case .looping = state.sectionRepeat { return true }; return false }()
        PlayerSkinIconButtonFactory.apply(button,
            icon: looping ? .sectionRepeatActive : .sectionRepeatIdle,
            fallbackTitle: looping ? "AB●" : "AB", theme: theme)
        button.isEnabled = !state.isLocked
        isHidden = state.isLocked || state.layoutMode != .fullScreen
    }
    @objc private func tap() { onAction?(.sectionRepeatToggleRequested) }
    private func pin(_ subview: UIView) {
        addSubview(subview)
        NSLayoutConstraint.activate([
            subview.topAnchor.constraint(equalTo: topAnchor),
            subview.bottomAnchor.constraint(equalTo: bottomAnchor),
            subview.leadingAnchor.constraint(equalTo: leadingAnchor),
            subview.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }
}
