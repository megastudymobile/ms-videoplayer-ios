//
//  PlaybackPreparedSnapshot.swift
//  VideoPlayerModule
//
//  Created by 모바일팀_정준영 on 2026/06/04.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import Foundation

/// prepare 완료 시점의 SDK 독립 스냅샷.
///
/// 엔진 어댑터가 SDK에서 position/duration/live 정보를 조회해 채우고,
/// `PlaybackStateReducer`가 이를 `.readyToPlay` 상태로 접는다. 어댑터는 `PlaybackState`를
/// 직접 만들지 않고 이 스냅샷만 제공한다.
public struct PlaybackPreparedSnapshot: Sendable, Equatable {
    public let position: TimeInterval
    public let duration: TimeInterval
    public let isLive: Bool
    public let liveDuration: TimeInterval?

    public init(
        position: TimeInterval,
        duration: TimeInterval,
        isLive: Bool,
        liveDuration: TimeInterval?
    ) {
        self.position = position
        self.duration = duration
        self.isLive = isLive
        self.liveDuration = liveDuration
    }
}
