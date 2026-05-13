//
//  PlayerEvent.swift
//  VideoPlayerModule
//
//  Created by 모바일개발팀_정준영 on 2026/04/17.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

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
}
