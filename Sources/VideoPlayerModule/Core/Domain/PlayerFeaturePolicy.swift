//
//  PlayerFeaturePolicy.swift
//  VideoPlayerModule
//
//  Created by 모바일개발팀_정준영 on 2026/04/17.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

import Foundation

public struct PlayerFeaturePolicy: Equatable, Sendable {
    public let allowsBackgroundPlayback: Bool
    public let maxPlaybackRate: Float
    public let allowsAutoplay: Bool
    public let skipInterval: TimeInterval

    public static let `default` = PlayerFeaturePolicy(
        allowsBackgroundPlayback: false,
        maxPlaybackRate: 2.0,
        allowsAutoplay: true,
        skipInterval: 10
    )

    public init(
        allowsBackgroundPlayback: Bool,
        maxPlaybackRate: Float,
        allowsAutoplay: Bool,
        skipInterval: TimeInterval = 10
    ) {
        self.allowsBackgroundPlayback = allowsBackgroundPlayback
        self.maxPlaybackRate = maxPlaybackRate
        self.allowsAutoplay = allowsAutoplay
        self.skipInterval = skipInterval > 0 ? skipInterval : 10
    }
}
