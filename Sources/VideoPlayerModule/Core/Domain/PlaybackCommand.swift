//
//  PlaybackCommand.swift
//  VideoPlayerModule
//
//  Created by 모바일개발팀_정준영 on 2026/04/17.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

import Foundation

public enum PlaybackCommand: Equatable, Sendable {
    case load(PlaybackSource)
    case play
    case pause
    case seek(to: TimeInterval)
    case seekWithOrigin(to: TimeInterval, origin: PlayerSeekOrigin)
    case setPlaybackRate(Double)
    case setSkipInterval(TimeInterval)
    case setSubtitleVisible(Bool)
    case selectSubtitleTrack(PlayerSubtitleTrackID?)
    case setCaptionFontSize(Int)
    case addBookmark(at: TimeInterval)
    case stop
}
