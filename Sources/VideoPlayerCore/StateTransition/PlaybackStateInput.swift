//
//  PlaybackStateInput.swift
//  VideoPlayerModule
//
//  Created by 모바일팀_정준영 on 2026/06/04.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import Foundation

/// 재생 상태를 움직이는 입력. "엔진이 보낸 신호"가 아니라 "상태를 바꾸는 사건"을 표현한다.
///
/// 엔진 어댑터가 SDK 신호를 이 타입으로 정규화하면, `PlaybackStateReducer`가 SDK를 모른 채
/// 다음 상태를 계산한다. 상태를 움직이지 않는 신호(caption, hlsHeight 등)는 이 타입에 넣지 않고
/// `PlayerEngineOutput.event` passthrough로 흘린다.
public enum PlaybackStateInput: Sendable {
    case prepared(PlaybackPreparedSnapshot)
    case prepareFailed(PlayerError)
    case playStarted
    case pauseStarted
    case bufferingChanged(Bool)
    case stopped(PlayerStopReason)
    case positionChanged(time: TimeInterval, duration: TimeInterval?)
    /// 사용자 seek 명령. 목표 위치로 즉시 점프한다. seek 완료는 엔진의 `positionChanged`로 감지한다.
    case seeking(time: TimeInterval)
    case failed(PlayerError)
}
