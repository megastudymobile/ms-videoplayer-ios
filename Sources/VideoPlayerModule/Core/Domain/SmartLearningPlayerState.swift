//
//  SmartLearningPlayerState.swift
//  SmartPlayer
//
//  Created by JunyoungJung on 2026-05-13.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import Foundation

public struct SmartLearningPlayerState: Equatable, Sendable {
    public let playbackState: PlaybackState
    public let selectedPlaybackRate: Double
    public let selectedSkipInterval: TimeInterval
    public let isLocked: Bool
    public let isScreenScaled: Bool
    public let isCastModeEnabled: Bool
    public let isAutoPlayNextLectureEnabled: Bool
    public let isSubtitleEnabled: Bool
    public let isAISubtitleEnabled: Bool
    public let captionFontSize: Int
    public let activePanel: SmartLearningPlayerPanel?

    public init(
        playbackState: PlaybackState = .idle,
        selectedPlaybackRate: Double = 1.0,
        selectedSkipInterval: TimeInterval = 10,
        isLocked: Bool = false,
        isScreenScaled: Bool = false,
        isCastModeEnabled: Bool = false,
        isAutoPlayNextLectureEnabled: Bool = true,
        isSubtitleEnabled: Bool = false,
        isAISubtitleEnabled: Bool = false,
        captionFontSize: Int = 16,
        activePanel: SmartLearningPlayerPanel? = nil
    ) {
        self.playbackState = playbackState
        self.selectedPlaybackRate = selectedPlaybackRate
        self.selectedSkipInterval = selectedSkipInterval
        self.isLocked = isLocked
        self.isScreenScaled = isScreenScaled
        self.isCastModeEnabled = isCastModeEnabled
        self.isAutoPlayNextLectureEnabled = isAutoPlayNextLectureEnabled
        self.isSubtitleEnabled = isSubtitleEnabled
        self.isAISubtitleEnabled = isAISubtitleEnabled
        self.captionFontSize = captionFontSize
        self.activePanel = activePanel
    }
}

public protocol SmartLearningPlayerStateProviding: Actor {
    var smartLearningState: SmartLearningPlayerState { get }
}
