//
//  PlayerCaption.swift
//  VideoPlayerModule
//
//  Created by 모바일개발팀_정준영 on 2026/05/15.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

import Foundation

public struct PlayerCaption: Equatable, Sendable, Hashable {
    public let text: String
    public let charset: String?
    public let isSecondary: Bool
    public let timestamp: TimeInterval?

    public init(
        text: String,
        charset: String? = nil,
        isSecondary: Bool = false,
        timestamp: TimeInterval? = nil
    ) {
        self.text = text
        self.charset = charset
        self.isSecondary = isSecondary
        self.timestamp = timestamp
    }
}
