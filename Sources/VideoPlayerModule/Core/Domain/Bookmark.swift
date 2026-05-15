//
//  Bookmark.swift
//  VideoPlayerModule
//
//  Created by 모바일개발팀_정준영 on 2026/05/15.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

import Foundation

public struct Bookmark: Equatable, Sendable, Hashable {
    public enum Kind: Equatable, Sendable, Hashable {
        case user
        case index
    }

    public let position: TimeInterval
    public let title: String
    public let kind: Kind
    public let createdAt: Date?

    public init(
        position: TimeInterval,
        title: String,
        kind: Kind,
        createdAt: Date? = nil
    ) {
        self.position = max(0, position)
        self.title = title
        self.kind = kind
        self.createdAt = createdAt
    }
}
