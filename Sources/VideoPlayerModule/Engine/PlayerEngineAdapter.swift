//
//  PlayerEngineAdapter.swift
//  VideoPlayerModule
//
//  Created by 모바일개발팀_정준영 on 2026/04/17.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

import CoreGraphics
import Foundation
#if canImport(UIKit)
import UIKit
#endif

public struct EngineCapabilities: OptionSet, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let continuesWithoutSurface = EngineCapabilities(rawValue: 1 << 0)
    public static let seamlessSurfaceSwap = EngineCapabilities(rawValue: 1 << 1)
    public static let nativePiP = EngineCapabilities(rawValue: 1 << 2)
}

public protocol PlayerPlaybackEngine: Actor {
    nonisolated static var capabilities: EngineCapabilities { get }

    func prepare(source: PlaybackSource) async throws
    func play() async throws
    func pause() async throws
    func seek(to time: TimeInterval) async throws
    func stop(reason: PlayerStopReason) async throws

    var currentState: PlaybackState { get }
    var eventStream: AsyncStream<PlayerEvent> { get }
}

public protocol PlayerPlaybackRateEngine: Actor {
    func setPlaybackRate(_ rate: Double) async throws
}

public protocol PlayerSubtitleEngine: Actor {
    func setSubtitleVisible(_ isVisible: Bool) async throws
    func selectSubtitleTrack(_ trackID: PlayerSubtitleTrackID?) async throws
    func setCaptionFontSize(_ fontSize: Int) async throws
}

public protocol PlayerBookmarkEngine: Actor {
    func addBookmark(at time: TimeInterval) async throws
}

public protocol PlayerTitledBookmarkEngine: PlayerBookmarkEngine {
    func addBookmark(at time: TimeInterval, title: String) async throws
    func removeBookmark(at time: TimeInterval) async throws
    func currentBookmarks() async -> [Bookmark]
}

public protocol PlayerExternalSubtitleEngine: PlayerSubtitleEngine {
    func selectSubtitleFile(_ fileURL: URL?) async throws
}

public protocol PlayerDisplayLockEngine: Actor {
    func setDisplayLocked(_ isLocked: Bool) async throws
}

public protocol PlayerDisplayScalingEngine: Actor {
    func setDisplayScaled(_ isScaled: Bool) async throws
    func toggleDisplayScaling() async throws
}

public protocol PlayerDisplayEngine: PlayerDisplayLockEngine, PlayerDisplayScalingEngine {}

#if canImport(UIKit)
public protocol PlayerZoomEngine: Actor {
    func zoom(_ recognizer: UIPinchGestureRecognizer) async throws
    func setZoomOutDisabled(_ disabled: Bool) async
    func zoomValue() async -> CGFloat
    var isZoomedIn: Bool { get async }
}
#endif

public protocol PlayerScrollEngine: Actor {
    func scroll(by distance: CGPoint) async throws
    func stopScroll() async throws
}

public protocol PlayerAdaptiveStreamingEngine: Actor {
    func changeBandwidth(_ bps: Int) async throws
    func streamInfoList() async -> [StreamInfo]
}

public protocol PlayerPiPCapability: Actor {
    func startPiP() async throws
    func stopPiP() async throws
    var isPiPActive: Bool { get async }
}
