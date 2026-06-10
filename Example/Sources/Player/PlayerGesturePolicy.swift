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
        return touchedView.isInsideUIControlSubtree == false
    }
}

private extension UIView {
    var isInsideUIControlSubtree: Bool {
        var currentView: UIView? = self
        while let view = currentView {
            if view is UIControl { return true }
            currentView = view.superview
        }
        return false
    }
}
