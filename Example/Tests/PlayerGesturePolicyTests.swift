//
//  PlayerGesturePolicyTests.swift
//  VideoPlayerExampleTests
//
//  Created by JunyoungJung on 2026/06/10.
//

import Testing
import UIKit
@testable import VideoPlayerExample

@Suite("PlayerGesturePolicy")
struct PlayerGesturePolicyTests {

    @Test("더블탭은 좌측 -10초, 우측 +10초 이동만 허용")
    func doubleTapSeekDelta_isFixedTenSecondSkip() {
        #expect(PlayerGesturePolicy.doubleTapSeekDelta(locationX: 49, boundsWidth: 100) == -10)
        #expect(PlayerGesturePolicy.doubleTapSeekDelta(locationX: 50, boundsWidth: 100) == 10)
        #expect(PlayerGesturePolicy.doubleTapSeekDelta(locationX: 99, boundsWidth: 100) == 10)
    }

    @Test("더블탭과 롱프레스는 UIControl 하위 터치를 가로채지 않는다")
    func discreteSurfaceGesture_ignoresUIControlSubtrees() {
        let rootView = UIView()
        let contentView = UIView()
        let controls: [UIControl] = [
            UIButton(type: .system),
            UISlider(),
            UISwitch(),
            UISegmentedControl(items: ["A", "B"])
        ]

        rootView.addSubview(contentView)
        controls.forEach(rootView.addSubview)

        #expect(PlayerGesturePolicy.allowsDiscreteSurfaceGesture(from: contentView))
        for control in controls {
            let touchedSubview = UIView()
            control.addSubview(touchedSubview)
            #expect(PlayerGesturePolicy.allowsDiscreteSurfaceGesture(from: control) == false)
            #expect(PlayerGesturePolicy.allowsDiscreteSurfaceGesture(from: touchedSubview) == false)
        }
        #expect(PlayerGesturePolicy.longPressMinimumDuration == 0.5)
    }
}
