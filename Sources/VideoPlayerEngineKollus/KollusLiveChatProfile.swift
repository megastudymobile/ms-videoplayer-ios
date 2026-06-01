//
//  KollusLiveChatProfile.swift
//  VideoPlayerModule
//
//  Created by 모바일개발팀_정준영 on 2026/05/15.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

import Foundation

public struct KollusLiveChatProfile: Sendable, Equatable {
    public let roomId: String
    public let chattingServer: URL
    public let userId: String
    public let nickName: String
    public let photoURL: URL?
    public let isAdmin: Bool
    public let isAnonymous: Bool

    public init(
        roomId: String,
        chattingServer: URL,
        userId: String,
        nickName: String,
        photoURL: URL? = nil,
        isAdmin: Bool = false,
        isAnonymous: Bool = false
    ) {
        self.roomId = roomId
        self.chattingServer = chattingServer
        self.userId = userId
        self.nickName = nickName
        self.photoURL = photoURL
        self.isAdmin = isAdmin
        self.isAnonymous = isAnonymous
    }
}
