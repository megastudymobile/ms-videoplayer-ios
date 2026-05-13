//
//  PlaybackSource.swift
//  VideoPlayerModule
//
//  Created by 모바일개발팀_정준영 on 2026/04/17.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

import Foundation

public enum PlaybackSource: Equatable, Sendable {
    case kollus(mediaContentKey: String)
    case url(URL)
}
