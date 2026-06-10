#if canImport(UIKit)
//
//  PlayerGestureActionTests.swift
//  VideoPlayerModuleTests
//
//  Created by JunyoungJung on 2026/06/10.
//

import Testing
@testable import VideoPlayerSkin

struct PlayerGestureActionTests {
    @Test("더블탭 스킵 케이스는 방향을 보존한다")
    func doubleTapSkipPreservesDirection() {
        #expect(PlayerGestureAction.doubleTapSkip(forward: true) != .doubleTapSkip(forward: false))
        #expect(PlayerGestureAction.doubleTapSkip(forward: true) == .doubleTapSkip(forward: true))
    }
}
#endif
