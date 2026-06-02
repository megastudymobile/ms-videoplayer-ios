//
//  PlayerSkinIcon.swift
//  VideoPlayerSkin
//  Copyright © 2026 megastudyedu. All rights reserved.
//

/// skin 이 요구하는 아이콘의 "의미". 기본 asset 매핑은 `PlayerSkinTheme.default` 가 소유한다.
public enum PlayerSkinIcon: Hashable, Sendable {
    case close, more, lock, unlock
    case play, pause, skipBackward, skipForward
    case screenExpand, screenShrink         // 전체화면 진입 / 해제
    case displayScaleFit, displayScaleAspectFill, displayScaleFill  // 화면 맞춤 / 자름 / 꽉참
    case rateUp, rateDown
    case sectionRepeatIdle, sectionRepeatActive
    case sliderThumb
}
