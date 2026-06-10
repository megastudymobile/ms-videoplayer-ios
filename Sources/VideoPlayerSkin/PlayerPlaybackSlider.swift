//
//  PlayerPlaybackSlider.swift
//  SmartPlayer
//
//  Created by 모바일팀_정준영 on 2026/05/28.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import UIKit

/// track 높이를 고정한 진행 슬라이더. 색상/thumb 이미지는 사용처에서 설정한다.
final class PlayerPlaybackSlider: UISlider {
    private static let trackHeight: CGFloat = 3

    override func trackRect(forBounds bounds: CGRect) -> CGRect {
        var trackRect = super.trackRect(forBounds: bounds)
        trackRect.size.height = Self.trackHeight
        return trackRect
    }
}
