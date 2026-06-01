//
//  DefaultPlayerSkin.swift
//  VideoPlayerSkin
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import UIKit

/// 기본 제공 재생기 skin 의 명명 진입점. AssembledPlayerSkin(.default) 얇은 wrapper (0-config parity).
public final class DefaultPlayerSkin: PlayerSkin {
    private let assembled: AssembledPlayerSkin

    public init(theme: PlayerSkinTheme = .default) {
        self.assembled = AssembledPlayerSkin(blueprint: .default, theme: theme)
    }

    public var view: UIView { assembled.view }
    public var onAction: ((PlayerSkinAction) -> Void)? {
        get { assembled.onAction }
        set { assembled.onAction = newValue }
    }
    public func configure(title: String, maxPlaybackRate: Double) {
        assembled.configure(title: title, maxPlaybackRate: maxPlaybackRate)
    }
    public func render(_ state: PlayerSkinState) { assembled.render(state) }
    public func setExtraControls(_ controls: [ExtraControl]) { assembled.setExtraControls(controls) }
    public func updateSkipIntervalLabel(seconds: Int) { assembled.updateSkipIntervalLabel(seconds: seconds) }
}
