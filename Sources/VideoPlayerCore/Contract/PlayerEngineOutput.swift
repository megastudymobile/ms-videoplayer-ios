//
//  PlayerEngineOutput.swift
//  VideoPlayerModule
//
//  Created by 모바일개발팀_정준영 on 2026/06/04.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

import Foundation

/// 엔진 어댑터가 Core로 내보내는 출력 단위.
///
/// 상태를 움직이는 입력(`stateInput`)과 상태와 무관한 passthrough 이벤트(`event`)로 나뉜다.
/// Core는 `stateInput`만 `PlaybackStateReducer`에 통과시키고, `event`는 그대로 publish한다.
///
/// - Important: 이 타입에는 `Error` existential을 싣지 않는다. vendor 신호의 `Error`는
///   actor/stream 경계를 넘기 전에 `PlayerError`로 변환해 Sendable-clean하게 만든다.
///   (설계 문서 §5.2 / §6 Swift 6 strict concurrency 대비)
public enum PlayerEngineOutput: Sendable {
    case stateInput(PlaybackStateInput)
    case event(PlayerEvent)
}
