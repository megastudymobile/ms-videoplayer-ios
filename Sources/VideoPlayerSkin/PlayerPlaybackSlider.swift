//
//  PlayerPlaybackSlider.swift
//  SmartPlayer
//
//  Created by 모바일팀_정준영 on 2026/05/28.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import UIKit

/// spec-052 Phase 4.2 — dev `SLPlayerPlaybackSlider` 의 swift port.
///
/// dev parity:
/// - track height = 3pt (`kSLPlayerPlaybackSliderHeight`)
/// - minimumTrackTintColor / maximumTrackTintColor / thumbImage 는 외부에서 설정.
final class PlayerPlaybackSlider: UISlider {
    private static let trackHeight: CGFloat = 3

    override func trackRect(forBounds bounds: CGRect) -> CGRect {
        var trackRect = super.trackRect(forBounds: bounds)
        trackRect.size.height = Self.trackHeight
        return trackRect
    }
}
