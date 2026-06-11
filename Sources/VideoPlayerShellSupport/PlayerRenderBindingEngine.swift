//
//  PlayerRenderBindingEngine.swift
//  VideoPlayerModule
//
//  Created by 모바일팀_정준영 on 2026/05/12.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import Foundation
import VideoPlayerCore

public protocol PlayerEngineAdapter: PlayerPlaybackEngine {
    func bind(renderSurface: PlayerRenderSurface)
    func unbindRenderSurface()
}
