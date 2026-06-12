//
//  PlayerStateBinder.swift
//  VideoPlayerModule
//
//  Created by 모바일팀_정준영 on 2026/04/17.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import Foundation
import VideoPlayerCore

@MainActor
public final class PlayerStateBinder {
    private var stateTask: Task<Void, Never>?
    private var eventTask: Task<Void, Never>?

    public init() {}

    public func bind(
        core: PlayerCore,
        nowPlaying: PlayerNowPlayingCoordinator? = nil,
        onState: @escaping (PlaybackState) -> Void,
        onEvent: @escaping (PlayerEvent) -> Void
    ) {
        unbind()

        // stateStream은 단일 consumer — NowPlaying 동기화는 여기서 fan-out한다.
        stateTask = Task { @MainActor in
            for await state in core.stateStream {
                nowPlaying?.apply(state: state)
                onState(state)
            }
        }

        eventTask = Task { @MainActor in
            for await event in core.eventStream {
                nowPlaying?.apply(event: event)
                onEvent(event)
            }
        }
    }

    public func unbind() {
        stateTask?.cancel()
        eventTask?.cancel()
        stateTask = nil
        eventTask = nil
    }
}
