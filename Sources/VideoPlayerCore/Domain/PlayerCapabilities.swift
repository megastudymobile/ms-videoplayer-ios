//
//  PlayerCapabilities.swift
//  VideoPlayerModule
//
//  Created by JunyoungJung on 2026-05-13.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

import Foundation

public enum PlayerStopReason: Equatable, Sendable {
    case userClosed
    case replacedSource
    case appLifecycle
    case finished
}

public enum PlayerSeekOrigin: Equatable, Sendable {
    case scrubber
    case skipForward
    case skipBackward
    case bookmark(PlayerBookmarkID)
    case chapter(PlayerChapterID)
    case timedMetadata(PlayerTimedMetadataID)
    case gesture
    case programmatic
}

public protocol PlayerPlaybackControlling: Actor {
    func load(_ source: PlaybackSource) async throws
    func play() async throws
    func pause() async throws
    func stop(reason: PlayerStopReason) async throws
    func seek(to time: TimeInterval, origin: PlayerSeekOrigin) async throws
}

public protocol PlayerRateControlling: Actor {
    func setPlaybackRate(_ rate: Double) async throws
    func setSkipInterval(_ interval: TimeInterval) async throws
    func skipForward() async throws
    func skipBackward() async throws
}

public protocol PlayerSubtitleControlling: Actor {
    func setSubtitleVisible(_ isVisible: Bool) async throws
    func selectSubtitleTrack(_ trackID: PlayerSubtitleTrackID?) async throws
    func setCaptionFontSize(_ fontSize: Int) async throws
}

public protocol PlayerBookmarkControlling: Actor {
    func addBookmark(at time: TimeInterval) async throws
    func selectBookmark(_ bookmarkID: PlayerBookmarkID) async throws
    func deleteBookmark(_ bookmarkID: PlayerBookmarkID) async throws
}

public protocol PlayerPlaylistControlling: Actor {
    func selectPlaylistItem(_ itemID: PlayerPlaylistItemID) async throws
    func playNextItem() async throws
    func setAutoplayNextItemEnabled(_ isEnabled: Bool) async throws
}

public protocol PlayerDisplayControlling: Actor {
    func setDisplayLocked(_ isLocked: Bool) async throws
    func setDisplayScaleMode(_ mode: PlayerDisplayScaleMode) async throws
    func setDisplayScaled(_ isScaled: Bool) async throws
    func toggleDisplayScaleMode() async throws
    func toggleDisplayScaling() async throws
}

public protocol PlayerOfflineControlling: Actor {
    func validateOfflineSource(_ sourceID: PlayerOfflineSourceID) async throws
    func selectOfflineSource(_ sourceID: PlayerOfflineSourceID) async throws
}

public protocol PlayerStateSnapshotProviding: Actor {
    var stateSnapshot: PlayerStateSnapshot { get }
}

public protocol PlayerSession:
    PlayerPlaybackControlling,
    PlayerRateControlling,
    PlayerSubtitleControlling,
    PlayerBookmarkControlling,
    PlayerPlaylistControlling,
    PlayerDisplayControlling,
    PlayerOfflineControlling,
    PlayerStateSnapshotProviding {}
