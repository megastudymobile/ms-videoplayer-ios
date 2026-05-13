//
//  PlaybackState.swift
//  VideoPlayerModule
//
//  Created by 모바일개발팀_정준영 on 2026/04/17.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

import Foundation

public struct PlaybackState: Equatable, Sendable {
    public enum Status: Equatable, Sendable {
        case idle
        case preparing
        case readyToPlay
        case playing
        case paused
        case buffering
        case finished
        case failed(PlayerError)
    }

    public let status: Status
    public let currentTime: TimeInterval
    public let duration: TimeInterval
    public let isBuffering: Bool

    public static let idle = PlaybackState(
        status: .idle,
        currentTime: 0,
        duration: 0,
        isBuffering: false
    )

    public init(
        status: Status,
        currentTime: TimeInterval,
        duration: TimeInterval,
        isBuffering: Bool
    ) {
        self.status = status
        self.currentTime = currentTime
        self.duration = duration
        self.isBuffering = isBuffering
    }

    public func updating(
        status: Status? = nil,
        currentTime: TimeInterval? = nil,
        duration: TimeInterval? = nil,
        isBuffering: Bool? = nil
    ) -> PlaybackState {
        PlaybackState(
            status: status ?? self.status,
            currentTime: currentTime ?? self.currentTime,
            duration: duration ?? self.duration,
            isBuffering: isBuffering ?? self.isBuffering
        )
    }
}
