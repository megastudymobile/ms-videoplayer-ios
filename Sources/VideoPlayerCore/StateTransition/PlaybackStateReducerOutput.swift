//
//  PlaybackStateReducerOutput.swift
//  VideoPlayerModule
//
//  Created by 모바일팀_정준영 on 2026/06/04.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import Foundation

/// `PlaybackStateReducer.reduce(_:state:)`의 결과.
///
/// `next`는 계산된 다음 상태, `events`는 그 전이로 발행할 이벤트다. reducer는 순수 함수이므로
/// 이 출력에 부수효과(effect)를 담지 않는다. polling, prepare continuation resume 같은 작업은
/// 어댑터/Core가 reducer 밖에서 처리한다.
public struct PlaybackStateReducerOutput: Sendable, Equatable {
    public let next: PlaybackState
    public let events: [PlayerEvent]

    public init(next: PlaybackState, events: [PlayerEvent]) {
        self.next = next
        self.events = events
    }
}
