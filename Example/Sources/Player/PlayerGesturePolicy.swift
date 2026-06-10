//
//  PlayerGesturePolicy.swift
//  VideoPlayerExample
//
//  Created by JunyoungJung on 2026/06/10.
//

import CoreGraphics
import Foundation

enum PlayerGesturePolicy {
    static let doubleTapSeekInterval: TimeInterval = 10

    static func doubleTapSeekDelta(locationX: CGFloat, boundsWidth: CGFloat) -> TimeInterval {
        locationX >= boundsWidth / 2 ? doubleTapSeekInterval : -doubleTapSeekInterval
    }
}
