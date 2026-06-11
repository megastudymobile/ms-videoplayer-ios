//
//  StreamInfo.swift
//  VideoPlayerModule
//
//  Created by 모바일팀_정준영 on 2026/05/15.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import Foundation

public struct StreamInfo: Equatable, Sendable, Hashable {
    public let bitrate: Int
    public let width: Int
    public let height: Int

    public init(bitrate: Int, width: Int, height: Int) {
        self.bitrate = bitrate
        self.width = width
        self.height = height
    }
}
