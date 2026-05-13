//
//  SmartLearningPlayerFeatureSet.swift
//  SmartPlayer
//
//  Created by JunyoungJung on 2026-05-13.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import Foundation

public struct SmartLearningContentIdentity: Equatable, Sendable {
    public let courseIdentifier: String
    public let lectureIdentifier: String
    public let title: String?

    public init(
        courseIdentifier: String,
        lectureIdentifier: String,
        title: String? = nil
    ) {
        self.courseIdentifier = courseIdentifier
        self.lectureIdentifier = lectureIdentifier
        self.title = title
    }
}

public struct SmartLearningPlaybackFeatures: Equatable, Sendable {
    public let allowsSeeking: Bool
    public let allowedPlaybackRates: [Double]
    public let initialPlaybackRate: Double
    public let skipIntervals: [TimeInterval]
    public let initialSkipInterval: TimeInterval
    public let allowsAutoPlayNextLecture: Bool
    public let allowsBackgroundPlayback: Bool

    public init(
        allowsSeeking: Bool = true,
        allowedPlaybackRates: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0],
        initialPlaybackRate: Double = 1.0,
        skipIntervals: [TimeInterval] = [5, 10, 30],
        initialSkipInterval: TimeInterval = 10,
        allowsAutoPlayNextLecture: Bool = true,
        allowsBackgroundPlayback: Bool = false
    ) {
        let normalizedRates = allowedPlaybackRates.isEmpty ? [1.0] : allowedPlaybackRates
        let normalizedIntervals = skipIntervals.isEmpty ? [10] : skipIntervals
        self.allowsSeeking = allowsSeeking
        self.allowedPlaybackRates = normalizedRates
        self.initialPlaybackRate = normalizedRates.contains(initialPlaybackRate) ? initialPlaybackRate : 1.0
        self.skipIntervals = normalizedIntervals
        self.initialSkipInterval = normalizedIntervals.contains(initialSkipInterval) ? initialSkipInterval : normalizedIntervals[0]
        self.allowsAutoPlayNextLecture = allowsAutoPlayNextLecture
        self.allowsBackgroundPlayback = allowsBackgroundPlayback
    }
}

public struct SmartLearningSubtitleFeatures: Equatable, Sendable {
    public let supportsPrimarySubtitle: Bool
    public let supportsAISubtitle: Bool
    public let supportsSubtitleErrorReport: Bool
    public let captionFontSizes: [Int]
    public let initialCaptionFontSize: Int
    public let initialAISubtitleEnabled: Bool

    public init(
        supportsPrimarySubtitle: Bool = true,
        supportsAISubtitle: Bool = true,
        supportsSubtitleErrorReport: Bool = true,
        captionFontSizes: [Int] = [14, 16, 18, 20, 22],
        initialCaptionFontSize: Int = 16,
        initialAISubtitleEnabled: Bool = false
    ) {
        let normalizedSizes = captionFontSizes.isEmpty ? [16] : captionFontSizes
        self.supportsPrimarySubtitle = supportsPrimarySubtitle
        self.supportsAISubtitle = supportsAISubtitle
        self.supportsSubtitleErrorReport = supportsSubtitleErrorReport
        self.captionFontSizes = normalizedSizes
        self.initialCaptionFontSize = normalizedSizes.contains(initialCaptionFontSize) ? initialCaptionFontSize : normalizedSizes[0]
        self.initialAISubtitleEnabled = initialAISubtitleEnabled
    }
}

public struct SmartLearningPanelFeatures: Equatable, Sendable {
    public let supportsBookmarkList: Bool
    public let supportsLectureIndex: Bool
    public let supportsLecturePlaylist: Bool
    public let supportsMegaling: Bool
    public let supportsAISummary: Bool
    public let supportsLectureQnA: Bool

    public init(
        supportsBookmarkList: Bool = true,
        supportsLectureIndex: Bool = true,
        supportsLecturePlaylist: Bool = true,
        supportsMegaling: Bool = true,
        supportsAISummary: Bool = true,
        supportsLectureQnA: Bool = true
    ) {
        self.supportsBookmarkList = supportsBookmarkList
        self.supportsLectureIndex = supportsLectureIndex
        self.supportsLecturePlaylist = supportsLecturePlaylist
        self.supportsMegaling = supportsMegaling
        self.supportsAISummary = supportsAISummary
        self.supportsLectureQnA = supportsLectureQnA
    }
}

public struct SmartLearningOfflineFeatures: Equatable, Sendable {
    public let supportsDownloadPlayback: Bool
    public let supportsDownloadedFileValidation: Bool
    public let supportsDownloadQueueNavigation: Bool

    public init(
        supportsDownloadPlayback: Bool = false,
        supportsDownloadedFileValidation: Bool = false,
        supportsDownloadQueueNavigation: Bool = false
    ) {
        self.supportsDownloadPlayback = supportsDownloadPlayback
        self.supportsDownloadedFileValidation = supportsDownloadedFileValidation
        self.supportsDownloadQueueNavigation = supportsDownloadQueueNavigation
    }
}

public struct SmartLearningGestureFeatures: Equatable, Sendable {
    public let supportsPlayPauseTap: Bool
    public let supportsDoubleTapSeek: Bool
    public let supportsPinchZoom: Bool
    public let supportsPanSeek: Bool
    public let supportsVolumeGesture: Bool
    public let supportsBrightnessGesture: Bool
    public let supportsLock: Bool

    public init(
        supportsPlayPauseTap: Bool = true,
        supportsDoubleTapSeek: Bool = true,
        supportsPinchZoom: Bool = true,
        supportsPanSeek: Bool = true,
        supportsVolumeGesture: Bool = true,
        supportsBrightnessGesture: Bool = true,
        supportsLock: Bool = true
    ) {
        self.supportsPlayPauseTap = supportsPlayPauseTap
        self.supportsDoubleTapSeek = supportsDoubleTapSeek
        self.supportsPinchZoom = supportsPinchZoom
        self.supportsPanSeek = supportsPanSeek
        self.supportsVolumeGesture = supportsVolumeGesture
        self.supportsBrightnessGesture = supportsBrightnessGesture
        self.supportsLock = supportsLock
    }
}

public struct SmartLearningPlayerFeatureSet: Equatable, Sendable {
    public let playback: SmartLearningPlaybackFeatures
    public let subtitle: SmartLearningSubtitleFeatures
    public let panels: SmartLearningPanelFeatures
    public let offline: SmartLearningOfflineFeatures
    public let gestures: SmartLearningGestureFeatures
    public let allowsCastMode: Bool
    public let allowsScreenScaling: Bool

    public static let `default` = SmartLearningPlayerFeatureSet()

    public init(
        playback: SmartLearningPlaybackFeatures = SmartLearningPlaybackFeatures(),
        subtitle: SmartLearningSubtitleFeatures = SmartLearningSubtitleFeatures(),
        panels: SmartLearningPanelFeatures = SmartLearningPanelFeatures(),
        offline: SmartLearningOfflineFeatures = SmartLearningOfflineFeatures(),
        gestures: SmartLearningGestureFeatures = SmartLearningGestureFeatures(),
        allowsCastMode: Bool = false,
        allowsScreenScaling: Bool = true
    ) {
        self.playback = playback
        self.subtitle = subtitle
        self.panels = panels
        self.offline = offline
        self.gestures = gestures
        self.allowsCastMode = allowsCastMode
        self.allowsScreenScaling = allowsScreenScaling
    }
}
