//
//  PlayerGesturePolicy.swift
//  VideoPlayerExample
//
//  Created by JunyoungJung on 2026/06/10.
//

import CoreGraphics
import Foundation
import UIKit

enum PlayerGesturePolicy {
    static let doubleTapSeekInterval: TimeInterval = 10
    static let longPressMinimumDuration: TimeInterval = 0.5

    static func doubleTapSeekDelta(locationX: CGFloat, boundsWidth: CGFloat) -> TimeInterval {
        locationX >= boundsWidth / 2 ? doubleTapSeekInterval : -doubleTapSeekInterval
    }

    static func allowsDiscreteSurfaceGesture(from touchedView: UIView?) -> Bool {
        guard let touchedView else { return true }
        if touchedView.hasSliderAncestor { return false }
        if touchedView.hasButtonAncestor { return false }
        return true
    }
}

private extension UIView {
    var hasButtonAncestor: Bool {
        if self is UIButton { return true }
        return superview?.hasButtonAncestor ?? false
    }

    var hasSliderAncestor: Bool {
        if self is UISlider { return true }
        return superview?.hasSliderAncestor ?? false
    }
}
