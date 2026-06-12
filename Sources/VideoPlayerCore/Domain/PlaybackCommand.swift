//
//  PlaybackCommand.swift
//  VideoPlayerModule
//
//  Created by 모바일팀_정준영 on 2026/04/17.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import CoreGraphics
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
    case addBookmarkWithTitle(at: TimeInterval, title: String)
    case removeBookmark(at: TimeInterval)
    case selectSubtitleFile(URL?)
    case setDisplayLocked(Bool)
    case setDisplayScaleMode(PlayerDisplayScaleMode)
    case setDisplayScaled(Bool)
    case toggleDisplayScaleMode
    case toggleDisplayScaling
    case scroll(by: CGPoint)
    case stopScroll
    case changeBandwidth(Int)
    case stop
}
