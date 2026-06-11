#if canImport(UIKit)
//
//  PlayerGestureHUDViewTests.swift
//  VideoPlayerModuleTests
//
//  Created by JunyoungJung on 2026/06/10.
//

import Testing
import UIKit
@testable import VideoPlayerSkin

@MainActor
struct PlayerGestureHUDViewTests {
    @Test("show 직후 노출 상태가 된다")
    func showMakesVisible() {
        let hud = PlayerGestureHUDView()
        hud.show(icon: "PlayerBrightnessNormal", title: "50%")

        #expect(hud.isHidden == false)
        #expect(hud.alpha == 1)
    }

    @Test("displayDuration 0 이하면 자동 숨김을 예약하지 않는다")
    func nonPositiveDurationSkipsAutoHide() {
        let hud = PlayerGestureHUDView()
        hud.displayDuration = 0
        hud.show(icon: "x", title: "t")

        #expect(hud.isHidden == false)
    }

    @Test("2배속 HUD는 상단 캡슐 배지로 표시한다")
    func presentRateUsesHeaderBadge() {
        let hud = PlayerGestureHUDView()
        hud.presentRate(2.0)

        let badge = hud.descendant(accessibilityIdentifier: "videoPlayer.skin.gestureHUD.rateBadgeView")
        let label = hud.descendant(accessibilityIdentifier: "videoPlayer.skin.gestureHUD.rateBadgeLabel") as? UILabel
        let image = hud.descendant(accessibilityIdentifier: "videoPlayer.skin.gestureHUD.rateBadgeImageView") as? UIImageView

        #expect(hud.isHidden == false)
        #expect(badge?.isHidden == false)
        #expect(label?.attributedText?.string == "2배속")
        #expect(image?.image != nil)

        hud.show(icon: "PlayerBrightnessNormal", title: "50%")
        #expect(badge?.isHidden == true)
    }

    @Test("비정수 배속 HUD는 소수 첫째 자리까지 표시한다")
    func presentRateFormatsFractionalRate() {
        let hud = PlayerGestureHUDView()
        hud.presentRate(1.5)

        let label = hud.descendant(accessibilityIdentifier: "videoPlayer.skin.gestureHUD.rateBadgeLabel") as? UILabel
        #expect(label?.attributedText?.string == "1.5배속")
    }
}
#endif
