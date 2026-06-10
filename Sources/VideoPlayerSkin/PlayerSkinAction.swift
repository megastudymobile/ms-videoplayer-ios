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
    /// 진행바 스크러버 잡기 시작(touchDown). host 가 재생을 일시정지(freeze)해
    /// 사용자가 위치를 고르는 동안 화면을 멈춘다.
    case seekBegan
    case seekPreviewChanged(TimeInterval)
    case seekEnded(TimeInterval)
    case skipBackward
    case skipForward
    case rateSelected(Double)
    case rateStepUp
    case rateStepDown
    case rateToggleCenter
    /// rate 버튼 tap 시 cycle toggle 대신 상세 배속 패널 표시 요청.
    case ratePanelRequested
    case toggleDisplayScaling
    case toggleScreenMode
    case settingRequested
    case moreRequested
    case holdToggleRequested
    case sectionRepeatToggleRequested
    case sectionRepeatStartRequested
    case sectionRepeatEndRequested
    /// host 가 주입한 추가 버튼 tap. skin 은 id 만 전달하고 의미는 모른다.
    case extraControlTapped(id: String)
}
