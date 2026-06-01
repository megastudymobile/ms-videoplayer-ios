//
//  PlayerSkinIcon.swift
//  VideoPlayerSkin
//  Copyright © 2026 megastudyedu. All rights reserved.
//

/// skin 이 요구하는 아이콘의 "의미". host theme 이 자유 매핑한다(에셋 의존 역전).
///
/// 기본 asset 이름은 `defaultAssetName` 한 곳에만 존재 → block 코드에서 문자열 산재 제거,
/// 컴파일 타임 exhaustive, host 가 매직 문자열을 알 필요 없음.
public enum PlayerSkinIcon: Hashable, Sendable {
    case close, more, lock, unlock
    case play, pause, skipBackward, skipForward
    case screenExpand, screenShrink         // 전체화면 진입 / 해제
    case displayScaleFit, displayScaleFill  // 화면 맞춤 / 채움
    case rateUp, rateDown
    case sectionRepeatIdle, sectionRepeatActive
    case sliderThumb

    /// 기본 제공 asset 이름. 커스텀 테마는 `icon(_:)` 오버라이드로 이 매핑을 건너뛸 수 있다.
    public var defaultAssetName: String {
        switch self {
        case .close:               return "PlayerCloseNormal"
        case .more:                return "PlayerMoreNormal"
        case .lock:                return "PlayerLockNormal"
        case .unlock:              return "PlayerUnlockNormal"
        case .play:                return "PlayerPlayNormal"
        case .pause:               return "PlayerPauseNormal"
        case .skipBackward:        return "PlayerBackwardNormal"
        case .skipForward:         return "PlayerForwardNormal"
        case .screenExpand:        return "PlayerScreenPortraitNormal"
        case .screenShrink:        return "PlayerScreenLandscapeNormal"
        case .displayScaleFit:     return "PlayerScreenScalingAspectFitNormal"
        case .displayScaleFill:    return "PlayerScreenScalingAspectFillNormal"
        case .rateUp:              return "PlayerRatePlusButton"
        case .rateDown:            return "PlayerRateMinusButton"
        case .sectionRepeatIdle:   return "PlayerRepeatNormal"
        case .sectionRepeatActive: return "PlayerRepeatSelected"
        case .sliderThumb:         return "PlayerPlaybackSliderCircleNormal"
        }
    }
}
