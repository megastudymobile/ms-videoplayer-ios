//
//  PlayerSkinIconButton.swift
//  VideoPlayerSkin
//
//  Created by 모바일팀_정준영 on 2026/06/11.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import UIKit

/// 블럭들이 공유하는 아이콘 버튼 빌더.
enum PlayerSkinIconButtonFactory {
    private static let controlInset: CGFloat = 10
    private static let fallbackSize: CGFloat = 48

    static func make(size: CGFloat = fallbackSize) -> UIButton {
        let button = ResizableIconButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.imageView?.contentMode = .scaleAspectFit
        button.updateSize(width: size, height: size)
        return button
    }

    /// 의미 아이콘 적용 (built-in skin 아이콘). theme.icon 으로 해석 → 없으면 텍스트 fallback.
    static func apply(_ button: UIButton, icon: PlayerSkinIcon, fallbackTitle: String, theme: PlayerSkinTheme) {
        set(
            button,
            image: theme.icon(icon, compatibleWith: button.traitCollection),
            highlightedBackground: theme.highlightedBackground(for: icon, compatibleWith: button.traitCollection),
            fallbackTitle: fallbackTitle,
            theme: theme
        )
    }

    /// 동적 asset 이름 적용 (host 주입 ExtraControl). asset → SF Symbol → 텍스트 fallback.
    static func apply(_ button: UIButton, assetName: String, fallbackTitle: String, theme: PlayerSkinTheme) {
        apply(button, assetName: assetName, selectedAssetName: nil, isSelected: false, fallbackTitle: fallbackTitle, theme: theme)
    }

    static func apply(
        _ button: UIButton,
        assetName: String,
        selectedAssetName: String?,
        isSelected: Bool,
        fallbackTitle: String,
        theme: PlayerSkinTheme
    ) {
        let normalImage = theme.image(assetName: assetName)
        let selectedImage = selectedAssetName.flatMap { theme.image(assetName: $0) }
        let image = (isSelected ? selectedImage : normalImage) ?? normalImage ?? UIImage(systemName: assetName)
        set(
            button,
            image: image,
            highlightedBackground: theme.image(assetName: "PlayerTouchSHighlighted"),
            fallbackTitle: fallbackTitle,
            theme: theme
        )
        if let selectedImage {
            button.setImage(selectedImage.withRenderingMode(.alwaysOriginal), for: .selected)
        }
        button.isSelected = isSelected
    }

    private static func set(
        _ button: UIButton,
        image: UIImage?,
        highlightedBackground: UIImage?,
        fallbackTitle: String,
        theme: PlayerSkinTheme
    ) {
        if let highlightedBackground {
            button.setBackgroundImage(highlightedBackground.withRenderingMode(.alwaysOriginal), for: .highlighted)
        }

        if let image {
            button.tintColor = nil
            button.setImage(image.withRenderingMode(.alwaysOriginal), for: .normal)
            button.setTitle(nil, for: .normal)
            let size = highlightedBackground?.size ?? CGSize(
                width: image.size.width + controlInset * 2,
                height: image.size.height + controlInset * 2
            )
            (button as? ResizableIconButton)?.updateSize(width: max(size.width, fallbackSize), height: max(size.height, fallbackSize))
        } else {
            button.tintColor = theme.color(.controlTint)
            button.setImage(nil, for: .normal)
            button.setTitle(fallbackTitle, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
            (button as? ResizableIconButton)?.updateSize(width: fallbackSize, height: fallbackSize)
        }
    }
}

private final class ResizableIconButton: UIButton {
    private var widthConstraint: NSLayoutConstraint?
    private var heightConstraint: NSLayoutConstraint?

    func updateSize(width: CGFloat, height: CGFloat) {
        if widthConstraint == nil {
            widthConstraint = widthAnchor.constraint(equalToConstant: width)
            heightConstraint = heightAnchor.constraint(equalToConstant: height)
            widthConstraint?.isActive = true
            heightConstraint?.isActive = true
        } else {
            widthConstraint?.constant = width
            heightConstraint?.constant = height
        }
    }
}
