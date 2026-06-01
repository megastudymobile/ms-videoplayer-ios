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

    /// asset → 없으면 SF Symbol → 없으면 텍스트 fallback (현 동작 동일).
    static func apply(_ button: UIButton, assetName: String, fallbackTitle: String, theme: PlayerSkinTheme) {
        button.tintColor = theme.color(.controlTint)
        if let asset = theme.image(assetName: assetName) {
            button.setImage(asset.withRenderingMode(.alwaysTemplate), for: .normal)
            button.setTitle(nil, for: .normal)
        } else if let symbol = UIImage(systemName: assetName) {
            button.setImage(symbol, for: .normal)
            button.setTitle(nil, for: .normal)
        } else {
            button.setImage(nil, for: .normal)
            button.setTitle(fallbackTitle, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        }
    }
}
