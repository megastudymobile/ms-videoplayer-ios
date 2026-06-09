//
//  PlayerSkinOverlay.swift
//  VideoPlayerSkin
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import UIKit

/// control block 과 별도로 skin 위에 고정 배치되는 overlay 계약.
/// caption/loading/HUD 는 controlsVisible/lock 슬롯 게이트를 타지 않아야 하므로
/// PlayerSkinBlock 이 아니라 overlay 로 분리한다.
@MainActor
public protocol PlayerSkinOverlay: AnyObject {
    var view: UIView { get }
}

@MainActor
public protocol PlayerSkinCaptionOverlay: PlayerSkinOverlay {
    var bottomInset: CGFloat { get set }

    func update(text: String, isSecondary: Bool)
    func applyFontSize(_ size: Int)
    func setVisible(_ visible: Bool)
}

@MainActor
public protocol PlayerSkinGestureHUDOverlay: PlayerSkinOverlay {
    func show(icon: String, title: String, detail: String?, emphasized: Bool)
    func presentRate(_ rate: Double)
    func hide()
}

@MainActor
public protocol PlayerSkinLoadingOverlay: PlayerSkinOverlay {
    func configure(theme: PlayerSkinTheme)
    func setLoading(_ isLoading: Bool)
}
