//
//  PlayerGesturePolicyTests.swift
//  VideoPlayerExampleTests
//
//  Created by JunyoungJung on 2026/06/10.
//

import Testing
@testable import VideoPlayerExample

@Suite("PlayerGesturePolicy")
struct PlayerGesturePolicyTests {

    @Test("더블탭은 좌측 -10초, 우측 +10초 이동만 허용")
    func doubleTapSeekDelta_isFixedTenSecondSkip() {
        #expect(PlayerGesturePolicy.doubleTapSeekDelta(locationX: 49, boundsWidth: 100) == -10)
        #expect(PlayerGesturePolicy.doubleTapSeekDelta(locationX: 50, boundsWidth: 100) == 10)
        #expect(PlayerGesturePolicy.doubleTapSeekDelta(locationX: 99, boundsWidth: 100) == 10)
    }
}
