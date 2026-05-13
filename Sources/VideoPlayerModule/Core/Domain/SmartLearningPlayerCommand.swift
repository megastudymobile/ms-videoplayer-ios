//
//  SmartLearningPlayerCommand.swift
//  SmartPlayer
//
//  Created by JunyoungJung on 2026-05-13.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import Foundation

public enum SmartLearningPlayerPanel: Equatable, Sendable {
    case bookmarkList
    case lectureIndex
    case lecturePlaylist
    case megaling
    case aiSummary
    case lectureQnA
    case settings
}

public enum SmartLearningPlayerCommand: Equatable, Sendable {
    case setPlaybackRate(Double)
    case setSkipInterval(TimeInterval)
    case skipForward
    case skipBackward
    case setAISubtitleEnabled(Bool)
    case setSubtitleEnabled(Bool)
    case setCaptionFontSize(Int)
    case reportSubtitleError
    case openPanel(SmartLearningPlayerPanel)
    case closePanel(SmartLearningPlayerPanel)
    case selectBookmark(identifier: String)
    case deleteBookmark(identifier: String)
    case addBookmark(time: TimeInterval)
    case selectLectureIndex(identifier: String, time: TimeInterval?)
    case selectLecture(identifier: String)
    case seekMegaling(time: TimeInterval)
    case seekAISummary(time: TimeInterval)
    case setLocked(Bool)
    case toggleScreenScaling
    case setCastModeEnabled(Bool)
    case setVolume(Double)
    case setBrightness(Double)
    case setAutoPlayNextLecture(Bool)
    case requestLectureQnA
    case validateDownloadedFile(identifier: String)
    case selectDownloadedLecture(identifier: String)
}

public protocol SmartLearningPlayerCommandHandling: Actor {
    func executeSmartLearningCommand(_ command: SmartLearningPlayerCommand) async throws
}
