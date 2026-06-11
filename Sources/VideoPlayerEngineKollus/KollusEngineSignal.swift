//
//  KollusEngineSignal.swift
//  VideoPlayerModule
//
//  Created by 모바일팀_정준영 on 2026/05/15.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import CoreGraphics
import Foundation

public enum KollusEngineSignal: Sendable {
    case prepareToPlayCompleted(error: Error?)
    case playStarted(userInteraction: Bool, error: Error?)
    case pauseStarted(userInteraction: Bool, error: Error?)
    case bufferingChanged(buffering: Bool, prepared: Bool, error: Error?)
    case stopStarted(userInteraction: Bool, error: Error?)
    case positionChanged(time: TimeInterval, isSeeking: Bool)
    case scrollChanged(distance: CGPoint)
    case zoomChanged(value: CGFloat)
    case naturalSizeResolved(size: CGSize)
    case contentModeChanged(mode: Int)
    case contentFrameChanged(frame: CGRect)
    case playbackRateChanged(rate: Double)
    case repeatChanged(enabled: Bool)
    case externalOutputEnabledChanged(enabled: Bool)
    case unknownError(Error)
    case framerateResolved(framerate: Int)
    case devicePolicyLocked(playerType: Int)
    case captionUpdated(charset: String?, caption: String)
    case subCaptionUpdated(charset: String?, caption: String)
    case thumbnailReady(hasThumbnail: Bool, error: Error?)
    case mediaContentKeyResolved(mck: String)
    case hlsHeightChanged(height: Int)
    case hlsBitrateChanged(bitrate: Int)
}
