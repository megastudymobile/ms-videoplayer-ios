//
//  PlaybackCommand.swift
//  SmartPlayer
//
//  Created by 모바일개발팀_정준영 on 2026/04/17.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import Foundation

public enum PlaybackCommand: Equatable, Sendable {
    case load(PlaybackSource)
    case play
    case pause
    case seek(to: TimeInterval)
    case stop
    case smartLearning(SmartLearningPlayerCommand)
}
