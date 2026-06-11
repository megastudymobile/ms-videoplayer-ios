//
//  PlayerIdentity.swift
//  VideoPlayerModule
//
//  Created by 모바일팀_정준영 on 2026-05-13.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import Foundation

public struct PlayerContentIdentity: Equatable, Hashable, Sendable {
    public let collectionIdentifier: String?
    public let itemIdentifier: String
    public let title: String?

    public init(
        collectionIdentifier: String? = nil,
        itemIdentifier: String,
        title: String? = nil
    ) {
        self.collectionIdentifier = collectionIdentifier
        self.itemIdentifier = itemIdentifier
        self.title = title
    }
}

public struct PlayerBookmarkID: Equatable, Hashable, Sendable, RawRepresentable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public struct PlayerPlaylistItemID: Equatable, Hashable, Sendable, RawRepresentable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public struct PlayerChapterID: Equatable, Hashable, Sendable, RawRepresentable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public struct PlayerSubtitleTrackID: Equatable, Hashable, Sendable, RawRepresentable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public struct PlayerTimedMetadataID: Equatable, Hashable, Sendable, RawRepresentable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public struct PlayerOfflineSourceID: Equatable, Hashable, Sendable, RawRepresentable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}
