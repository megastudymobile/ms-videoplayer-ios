//
//  PlayerFeatureSet.swift
//  VideoPlayerModule
//
//  Created by JunyoungJung on 2026-05-13.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

import Foundation

public struct PlayerPlaybackFeatures: Equatable, Sendable {
    public let allowsSeeking: Bool
    public let allowsAutoplay: Bool
    public let allowsBackgroundPlayback: Bool
    public let allowedPlaybackRates: [Double]
    public let initialPlaybackRate: Double
    public let skipIntervals: [TimeInterval]
    public let initialSkipInterval: TimeInterval

    public init(
        allowsSeeking: Bool = true,
        allowsAutoplay: Bool = true,
        allowsBackgroundPlayback: Bool = false,
        allowedPlaybackRates: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0],
        initialPlaybackRate: Double = 1.0,
        skipIntervals: [TimeInterval] = [5, 10, 30],
        initialSkipInterval: TimeInterval = 10
    ) {
        let normalizedRates = Self.normalized(allowedPlaybackRates, fallback: [1.0])
        let normalizedIntervals = Self.normalized(skipIntervals, fallback: [10])

        self.allowsSeeking = allowsSeeking
        self.allowsAutoplay = allowsAutoplay
        self.allowsBackgroundPlayback = allowsBackgroundPlayback
        self.allowedPlaybackRates = normalizedRates
        self.initialPlaybackRate = normalizedRates.contains(initialPlaybackRate) ? initialPlaybackRate : 1.0
        self.skipIntervals = normalizedIntervals
        self.initialSkipInterval = normalizedIntervals.contains(initialSkipInterval) ? initialSkipInterval : normalizedIntervals[0]
    }

    private static func normalized<Value: Comparable & Hashable>(
        _ values: [Value],
        fallback: [Value]
    ) -> [Value] {
        let uniqueValues = Array(SetBackedSequence(values)).sorted()
        return uniqueValues.isEmpty ? fallback : uniqueValues
    }
}

public struct PlayerSubtitleTrack: Equatable, Sendable {
    public let id: PlayerSubtitleTrackID
    public let title: String
    public let localeIdentifier: String?

    public init(
        id: PlayerSubtitleTrackID,
        title: String,
        localeIdentifier: String? = nil
    ) {
        self.id = id
        self.title = title
        self.localeIdentifier = localeIdentifier
    }
}

public struct PlayerSubtitleFeatures: Equatable, Sendable {
    public let supportsSubtitles: Bool
    public let supportsTrackSelection: Bool
    public let supportsVisibilityToggle: Bool
    public let availableTracks: [PlayerSubtitleTrack]
    public let captionFontSizes: [Int]
    public let initialCaptionFontSize: Int

    public init(
        supportsSubtitles: Bool = true,
        supportsTrackSelection: Bool = true,
        supportsVisibilityToggle: Bool = true,
        availableTracks: [PlayerSubtitleTrack] = [],
        captionFontSizes: [Int] = [14, 16, 18, 20, 22],
        initialCaptionFontSize: Int = 16
    ) {
        let normalizedSizes = Array(SetBackedSequence(captionFontSizes)).sorted()
        let resolvedSizes = normalizedSizes.isEmpty ? [16] : normalizedSizes

        self.supportsSubtitles = supportsSubtitles
        self.supportsTrackSelection = supportsTrackSelection
        self.supportsVisibilityToggle = supportsVisibilityToggle
        self.availableTracks = availableTracks
        self.captionFontSizes = resolvedSizes
        self.initialCaptionFontSize = resolvedSizes.contains(initialCaptionFontSize) ? initialCaptionFontSize : resolvedSizes[0]
    }
}

public struct PlayerBookmarkFeatures: Equatable, Sendable {
    public let supportsBookmarks: Bool
    public let supportsMutation: Bool

    public init(
        supportsBookmarks: Bool = true,
        supportsMutation: Bool = true
    ) {
        self.supportsBookmarks = supportsBookmarks
        self.supportsMutation = supportsMutation
    }
}

public struct PlayerPlaylistFeatures: Equatable, Sendable {
    public let supportsItemSelection: Bool
    public let supportsNextItem: Bool
    public let supportsAutoplayNextItem: Bool

    public init(
        supportsItemSelection: Bool = true,
        supportsNextItem: Bool = true,
        supportsAutoplayNextItem: Bool = true
    ) {
        self.supportsItemSelection = supportsItemSelection
        self.supportsNextItem = supportsNextItem
        self.supportsAutoplayNextItem = supportsAutoplayNextItem
    }
}

public struct PlayerDisplayFeatures: Equatable, Sendable {
    public let supportsLock: Bool
    public let supportsScaling: Bool
    public let supportsExternalPlayback: Bool

    public init(
        supportsLock: Bool = true,
        supportsScaling: Bool = true,
        supportsExternalPlayback: Bool = false
    ) {
        self.supportsLock = supportsLock
        self.supportsScaling = supportsScaling
        self.supportsExternalPlayback = supportsExternalPlayback
    }
}

public struct PlayerOfflineFeatures: Equatable, Sendable {
    public let supportsOfflinePlayback: Bool
    public let supportsOfflineSourceValidation: Bool

    public init(
        supportsOfflinePlayback: Bool = false,
        supportsOfflineSourceValidation: Bool = false
    ) {
        self.supportsOfflinePlayback = supportsOfflinePlayback
        self.supportsOfflineSourceValidation = supportsOfflineSourceValidation
    }
}

public struct PlayerFeatureSet: Equatable, Sendable {
    public let playback: PlayerPlaybackFeatures
    public let subtitle: PlayerSubtitleFeatures
    public let bookmark: PlayerBookmarkFeatures
    public let playlist: PlayerPlaylistFeatures
    public let display: PlayerDisplayFeatures
    public let offline: PlayerOfflineFeatures

    public static let `default` = PlayerFeatureSet()

    public init(
        playback: PlayerPlaybackFeatures = PlayerPlaybackFeatures(),
        subtitle: PlayerSubtitleFeatures = PlayerSubtitleFeatures(),
        bookmark: PlayerBookmarkFeatures = PlayerBookmarkFeatures(),
        playlist: PlayerPlaylistFeatures = PlayerPlaylistFeatures(),
        display: PlayerDisplayFeatures = PlayerDisplayFeatures(),
        offline: PlayerOfflineFeatures = PlayerOfflineFeatures()
    ) {
        self.playback = playback
        self.subtitle = subtitle
        self.bookmark = bookmark
        self.playlist = playlist
        self.display = display
        self.offline = offline
    }
}

private struct SetBackedSequence<Element: Hashable>: Sequence {
    private let values: [Element]

    init(_ values: [Element]) {
        var seen = Set<Element>()
        self.values = values.filter { seen.insert($0).inserted }
    }

    func makeIterator() -> Array<Element>.Iterator {
        values.makeIterator()
    }
}
