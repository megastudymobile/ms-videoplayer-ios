//
//  PlayerSkinTheme.swift
//  VideoPlayerSkin
//
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import UIKit

/// 재생기 skin 의 룩(색/폰트/아이콘) 토큰.
///
/// Blueprint 와 동일하게 host 가 원하는 role 만 채워 주입하는 값 struct.
/// 비어 있는 role 은 `.default` 값을 사용해 현 구현 룩을 유지한다.
public struct PlayerSkinTheme {
    public var colors: [PlayerSkinColorRole: UIColor]
    public var fonts: [PlayerSkinFontRole: UIFont]
    public var icons: [PlayerSkinIcon: UIImage]

    public init(colors: [PlayerSkinColorRole: UIColor] = [:],
                fonts: [PlayerSkinFontRole: UIFont] = [:],
                icons: [PlayerSkinIcon: UIImage] = [:]) {
        self.colors = colors
        self.fonts = fonts
        self.icons = icons
    }

    /// 현 PlayerSkinControlView 하드코딩 룩과 1:1인 기본 테마.
    public static let `default` = PlayerSkinTheme(
        colors: [
            .controlTint: .white,
            .progressFill: UIColor(named: "primarySkyBlue", in: .module, compatibleWith: nil) ?? .systemBlue,
            .progressTrack: UIColor(named: "Line/grey-03", in: .module, compatibleWith: nil)
                ?? UIColor.white.withAlphaComponent(0.35),
            .barBackground: UIColor.black.withAlphaComponent(0.52),
            .timeText: UIColor.white.withAlphaComponent(0.9)
        ],
        fonts: [
            .title: Self.appleSDGothic(size: 16, weight: .regular),
            .time: Self.appleSDGothic(size: 11, weight: .regular),
            .rateLabel: Self.appleSDGothic(size: 13, weight: .regular),
            .skipInterval: Self.appleSDGothic(size: 12, weight: .semibold),
            .extraControlTitle: Self.appleSDGothic(size: 13, weight: .semibold),
            .sectionRepeatRange: Self.appleSDGothic(size: 15, weight: .regular),
            .caption: Self.appleSDGothic(size: 16, weight: .regular)
        ],
        icons: [
            .close: UIImage(named: "PlayerCloseNormal", in: .module, with: nil),
            .more: UIImage(named: "PlayerMoreNormal", in: .module, with: nil),
            .lock: UIImage(named: "PlayerLockNormal", in: .module, with: nil),
            .unlock: UIImage(named: "PlayerUnlockNormal", in: .module, with: nil),
            .play: UIImage(named: "PlayerPlayNormal", in: .module, with: nil),
            .pause: UIImage(named: "PlayerPauseNormal", in: .module, with: nil),
            .skipBackward: UIImage(named: "PlayerBackwardNormal", in: .module, with: nil),
            .skipForward: UIImage(named: "PlayerForwardNormal", in: .module, with: nil),
            .screenExpand: UIImage(named: "PlayerScreenPortraitNormal", in: .module, with: nil),
            .screenShrink: UIImage(named: "PlayerScreenLandscapeNormal", in: .module, with: nil),
            .displayScaleFit: UIImage(named: "PlayerScreenScalingAspectFitNormal", in: .module, with: nil),
            .displayScaleAspectFill: UIImage(named: "PlayerScreenScalingAspectFillNormal", in: .module, with: nil),
            .displayScaleFill: UIImage(named: "PlayerScreenScalingFillNormal", in: .module, with: nil),
            .rateUp: UIImage(named: "PlayerControlRateUp", in: .module, with: nil)
                ?? UIImage(named: "PlayerRatePlusButton", in: .module, with: nil),
            .rateDown: UIImage(named: "PlayerControlRateDown", in: .module, with: nil)
                ?? UIImage(named: "PlayerRateMinusButton", in: .module, with: nil),
            .sectionRepeatIdle: UIImage(named: "PlayerRepeatNormal", in: .module, with: nil),
            .sectionRepeatActive: UIImage(named: "PlayerRepeatSelected", in: .module, with: nil),
            .sliderThumb: UIImage(named: "PlayerPlaybackSliderCircleNormal", in: .module, with: nil)
        ].compactMapValues { $0 }
    )

    public func color(_ role: PlayerSkinColorRole) -> UIColor {
        colors[role] ?? PlayerSkinTheme.default.colors[role] ?? .white
    }

    public func font(_ role: PlayerSkinFontRole) -> UIFont {
        fonts[role] ?? PlayerSkinTheme.default.fonts[role] ?? .systemFont(ofSize: 14)
    }

    public func icon(_ icon: PlayerSkinIcon) -> UIImage? {
        icons[icon] ?? PlayerSkinTheme.default.icons[icon]
    }

    public func icon(_ icon: PlayerSkinIcon, compatibleWith traitCollection: UITraitCollection) -> UIImage? {
        if traitCollection.userInterfaceIdiom == .pad {
            switch icon {
            case .play:
                return image(assetName: "PlayerPlayNormaliPad") ?? self.icon(icon)
            case .pause:
                return image(assetName: "PlayerPauseNormaliPad") ?? self.icon(icon)
            case .skipBackward:
                return image(assetName: "PlayerBackwardNormaliPad") ?? self.icon(icon)
            case .skipForward:
                return image(assetName: "PlayerForwardNormaliPad") ?? self.icon(icon)
            default:
                break
            }
        }
        return self.icon(icon)
    }

    public func highlightedBackground(for icon: PlayerSkinIcon, compatibleWith traitCollection: UITraitCollection) -> UIImage? {
        let isPad = traitCollection.userInterfaceIdiom == .pad
        switch icon {
        case .play, .pause, .skipBackward, .skipForward:
            return image(assetName: isPad ? "PlayerTouchMHighlightediPad" : "PlayerTouchMHighlighted")
        default:
            return image(assetName: "PlayerTouchSHighlighted")
        }
    }

    /// host 주입 ExtraControl 등 동적 asset 이름 조회: 패키지 번들 → 앱 main 번들.
    public func image(assetName: String) -> UIImage? {
        UIImage(named: assetName, in: .module, with: nil) ?? UIImage(named: assetName)
    }

    private static func appleSDGothic(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let suffix: String
        switch weight {
        case .bold:
            suffix = "Bold"
        case .semibold:
            suffix = "SemiBold"
        case .light:
            suffix = "Light"
        default:
            suffix = "Regular"
        }
        return UIFont(name: "AppleSDGothicNeo-\(suffix)", size: size)
            ?? .systemFont(ofSize: size, weight: weight)
    }
}
