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
    public let nextEpisodeButtonLeadTime: TimeInterval

    public static let `default` = PlayerFeaturePolicy(
        allowsBackgroundPlayback: false,
        maxPlaybackRate: 2.0,
        allowsAutoplay: true,
        skipInterval: 10,
        nextEpisodeButtonLeadTime: 30
    )

    public init(
        allowsBackgroundPlayback: Bool,
        maxPlaybackRate: Float,
        allowsAutoplay: Bool,
        skipInterval: TimeInterval = 10,
        nextEpisodeButtonLeadTime: TimeInterval = 30
    ) {
        self.allowsBackgroundPlayback = allowsBackgroundPlayback
        self.maxPlaybackRate = maxPlaybackRate
        self.allowsAutoplay = allowsAutoplay
        self.skipInterval = skipInterval > 0 ? skipInterval : 10
        self.nextEpisodeButtonLeadTime = max(0, nextEpisodeButtonLeadTime)
    }
}
