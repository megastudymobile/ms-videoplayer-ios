//
//  PlayerSkinIconButton.swift
//  VideoPlayerSkin
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import UIKit

/// 블럭들이 공유하는 아이콘 버튼 빌더 (현 PlayerSkinControlView.setButtonImageOrTitle parity).
enum PlayerSkinIconButtonFactory {
    static func make(size: CGFloat = 44) -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.imageView?.contentMode = .scaleAspectFit
        button.widthAnchor.constraint(equalToConstant: size).isActive = true
        button.heightAnchor.constraint(equalToConstant: size).isActive = true
        return button
    }

    /// 의미 아이콘 적용 (built-in skin 아이콘). theme.icon 으로 해석 → 없으면 텍스트 fallback.
    static func apply(_ button: UIButton, icon: PlayerSkinIcon, fallbackTitle: String, theme: PlayerSkinTheme) {
        set(button, image: theme.icon(icon), fallbackTitle: fallbackTitle, theme: theme)
    }

    /// 동적 asset 이름 적용 (host 주입 ExtraControl). asset → SF Symbol → 텍스트 fallback.
    static func apply(_ button: UIButton, assetName: String, fallbackTitle: String, theme: PlayerSkinTheme) {
        set(button, image: theme.image(assetName: assetName) ?? UIImage(systemName: assetName),
            fallbackTitle: fallbackTitle, theme: theme)
    }

    private static func set(_ button: UIButton, image: UIImage?, fallbackTitle: String, theme: PlayerSkinTheme) {
        button.tintColor = theme.color(.controlTint)
        if let image {
            button.setImage(image.withRenderingMode(.alwaysTemplate), for: .normal)
            button.setTitle(nil, for: .normal)
        } else {
            button.setImage(nil, for: .normal)
            button.setTitle(fallbackTitle, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        }
    }
}
