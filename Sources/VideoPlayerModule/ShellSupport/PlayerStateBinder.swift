//
//  PlayerStateBinder.swift
//  SmartPlayer
//
//  Created by 모바일개발팀_정준영 on 2026/04/17.
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
        observeUseCase: ObservePlaybackStateUseCaseProtocol,
        onState: @escaping (PlaybackState) -> Void,
        onEvent: @escaping (PlayerEvent) -> Void
    ) {
        unbind()

        stateTask = Task { @MainActor in
            for await state in observeUseCase.stateStream {
                onState(state)
            }
        }

        eventTask = Task { @MainActor in
            for await event in observeUseCase.eventStream {
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
