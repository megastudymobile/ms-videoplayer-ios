//
//  PlayerEvent.swift
//  VideoPlayerModule
//
//  Created by 모바일개발팀_정준영 on 2026/04/17.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

import CoreGraphics
import Foundation

public enum PolicyDowngradeReason: Equatable, Sendable {
    case missingContinuesWithoutSurface
    case custom(String)
}

public enum PlayerEvent: Equatable, Sendable {
    case stateDidChange(PlaybackState)
    case timeDidChange(currentTime: TimeInterval, duration: TimeInterval)
    case bufferingDidChange(isBuffering: Bool)
    case didFinish
    case didFail(PlayerError)
    case policyDowngraded(reason: PolicyDowngradeReason)
    case captionDidUpdate(text: String, isSecondary: Bool)
    case bookmarksDidLoad([Bookmark])
    case bitrateDidChange(Int)
    case heightDidChange(Int)
    case externalOutputDidChange(enabled: Bool)
    case naturalSizeDidResolve(CGSize)
    case framerateDidResolve(Int)
    case deviceLockPolicyChanged(locked: Bool)
    case nextEpisodeAvailable(NextEpisodeInfo)
}
