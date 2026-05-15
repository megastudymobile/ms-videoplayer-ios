//
//  PlayerEngineAdapter.swift
//  VideoPlayerModule
//
//  Created by 모바일개발팀_정준영 on 2026/04/17.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

import Foundation

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
    func play()
    func pause()
    func seek(to time: TimeInterval) async
    func stop()

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
