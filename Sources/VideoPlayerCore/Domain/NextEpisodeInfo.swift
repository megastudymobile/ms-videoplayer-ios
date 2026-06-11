//
//  NextEpisodeInfo.swift
//  VideoPlayerModule
//
//  Created by 모바일팀_정준영 on 2026/05/15.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import Foundation

public struct NextEpisodeInfo: Equatable, Sendable, Hashable {
    public let showAt: TimeInterval
    public let callbackURL: URL
    public let callbackParameters: [String: String]
    public let showsButton: Bool

    public init(
        showAt: TimeInterval,
        callbackURL: URL,
        callbackParameters: [String: String] = [:],
        showsButton: Bool = true
    ) {
        self.showAt = showAt
        self.callbackURL = callbackURL
        self.callbackParameters = callbackParameters
        self.showsButton = showsButton
    }
}
