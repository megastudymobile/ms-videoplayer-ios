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
}
#endif
