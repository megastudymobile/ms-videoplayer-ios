//
//  PlayerSkinAction.swift
//  SmartPlayer
//
//  Created by 모바일팀_정준영 on 2026/05/19.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import Foundation

public enum PlayerSkinAction: Equatable {
    case closeRequested
    case togglePlayPause
    case seekPreviewChanged(TimeInterval)
    case seekEnded(TimeInterval)
    case skipBackward
    case skipForward
    case rateSelected(Double)
    case rateStepUp
    case rateStepDown
    case rateToggleCenter
    /// spec-062 Phase D4 — dev `MGPlayerViewController.showPlaybackRateSetting`
    /// (`MGPlayerViewController.m:2382-2429`) parity. rate 버튼 tap 시 cycle toggle
    /// 대신 detailed 배속 패널 (`SLPlayerDetailedPlaybackRateView` 동등) 표시 요청.
    case ratePanelRequested
    case toggleDisplayScaling
    case toggleScreenMode
    case settingRequested
    case moreRequested
    case holdToggleRequested
    case sectionRepeatToggleRequested
    case sectionRepeatStartRequested
    case sectionRepeatEndRequested
    /// spec-064 Phase 1 — host(강의)가 주입한 추가 버튼 tap. skin 은 id 만 전달하고 의미는 모른다.
    /// dev 의 강의 인덱스 / 북마크 목록 / 다음 강의 버튼이 이 슬롯으로 이전됨.
    case extraControlTapped(id: String)
}
