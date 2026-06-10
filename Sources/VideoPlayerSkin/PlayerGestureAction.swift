//
//  PlayerGestureAction.swift
//  SmartPlayer
//
//  Created by 모바일팀_정준영 on 2026/05/19.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import CoreGraphics
import Foundation

public enum PlayerGestureAction: Equatable {
    case toggleControlsVisibility
    case skipBackward
    case skipForward
    case seekPreview(TimeInterval, delta: TimeInterval)
    case seekEnded(TimeInterval)
    case brightnessPreview(Float)
    case volumePreview(Float)
    case pinchPreview(scale: CGFloat)
    case longPressBegan
    case longPressEnded
    case doubleTapTogglePlayPause
    case doubleTapSkip(forward: Bool)
}
