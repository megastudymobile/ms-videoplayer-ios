//
//  ObservePlaybackStateUseCase.swift
//  SmartPlayer
//
//  Created by 모바일개발팀_정준영 on 2026/04/17.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import Foundation

@MainActor
public protocol ObservePlaybackStateUseCaseProtocol {
    var stateStream: AsyncStream<PlaybackState> { get }
    var eventStream: AsyncStream<PlayerEvent> { get }
}

@MainActor
public final class DefaultObservePlaybackStateUseCase: ObservePlaybackStateUseCaseProtocol {
    public let stateStream: AsyncStream<PlaybackState>
    public let eventStream: AsyncStream<PlayerEvent>

    public init(core: PlayerCore) {
        self.stateStream = core.stateStream
        self.eventStream = core.eventStream
    }
}
