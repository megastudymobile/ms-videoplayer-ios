//
//  PlayerStateSnapshot.swift
//  VideoPlayerModule
//
//  Created by JunyoungJung on 2026-05-13.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

import Foundation

public struct PlayerSubtitleState: Equatable, Sendable {
    public let isVisible: Bool
    public let selectedTrack: PlayerSubtitleTrack?
    public let captionFontSize: Int

    public init(
        isVisible: Bool = false,
        selectedTrack: PlayerSubtitleTrack? = nil,
        captionFontSize: Int = 16
    ) {
        self.isVisible = isVisible
        self.selectedTrack = selectedTrack
        self.captionFontSize = captionFontSize
    }
}

public struct PlayerDisplayState: Equatable, Sendable {
    public let isLocked: Bool
    public let isScaled: Bool
    public let isExternalPlaybackActive: Bool

    public init(
        isLocked: Bool = false,
        isScaled: Bool = false,
        isExternalPlaybackActive: Bool = false
    ) {
        self.isLocked = isLocked
        self.isScaled = isScaled
        self.isExternalPlaybackActive = isExternalPlaybackActive
    }
}

public enum PlayerUnavailableCapability: Equatable, Sendable {
    case playbackRate(Double)
    case skipInterval(TimeInterval)
    case subtitleTrack(PlayerSubtitleTrackID)
    case bookmark(PlayerBookmarkID)
    case playlistItem(PlayerPlaylistItemID)
    case timedMetadata(PlayerTimedMetadataID)
    case offlineSource(PlayerOfflineSourceID)
    case displayLock
    case displayScaling
}

public struct PlayerStateSnapshot: Equatable, Sendable {
    public let playbackState: PlaybackState
    public let selectedPlaybackRate: Double
    public let selectedSkipInterval: TimeInterval
    public let subtitleState: PlayerSubtitleState
    public let displayState: PlayerDisplayState
    public let unavailableCapabilities: [PlayerUnavailableCapability]

    public init(
        playbackState: PlaybackState = .idle,
        selectedPlaybackRate: Double = 1.0,
        selectedSkipInterval: TimeInterval = 10,
        subtitleState: PlayerSubtitleState = PlayerSubtitleState(),
        displayState: PlayerDisplayState = PlayerDisplayState(),
        unavailableCapabilities: [PlayerUnavailableCapability] = []
    ) {
        self.playbackState = playbackState
        self.selectedPlaybackRate = selectedPlaybackRate
        self.selectedSkipInterval = selectedSkipInterval
        self.subtitleState = subtitleState
        self.displayState = displayState
        self.unavailableCapabilities = unavailableCapabilities
    }
}
