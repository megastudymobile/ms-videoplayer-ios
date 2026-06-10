//
//  PlayerFeatureAvailabilityTests.swift
//  VideoPlayerModuleTests
//
//  Created by JunyoungJung on 2026/06/10.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

import Foundation
import Testing
import VideoPlayerCore
#if canImport(UIKit)
import UIKit
#endif

@Suite("PlayerFeatureAvailability probe — 엔진 protocol 채택 기반 기능 협상")
struct PlayerFeatureAvailabilityTests {

    @Test("기본 엔진은 가용 기능 없음")
    func bareEngine_hasNoFeatures() {
        #expect(PlayerFeatureAvailability.probe(BareEngine()) == [])
    }

    @Test("optional protocol 채택이 곧 가용 기능이다")
    func conformingEngine_reportsAdoptedFeatures() {
        let features = PlayerFeatureAvailability.probe(RichEngine())

        #expect(features.contains(.playbackRate))
        #expect(features.contains(.subtitles))
        #expect(features.contains(.bookmarks))
        #expect(features.contains(.titledBookmarks))
        #expect(features.contains(.adaptiveStreaming))
        #expect(!features.contains(.pictureInPicture))
        #expect(!features.contains(.scroll))
        #expect(!features.contains(.displayScaling))
    }

    @Test("PlayerCore는 init 시점에 availability를 산출한다")
    func playerCore_probesAtInit() {
        let core = PlayerCore(engine: RichEngine(), engineCapabilities: [])

        #expect(core.availableFeatures.contains(.playbackRate))
        #expect(!core.availableFeatures.contains(.pictureInPicture))
    }
}

// MARK: - Fakes

private actor BareEngine: PlayerPlaybackEngine {
    nonisolated static let capabilities: EngineCapabilities = []
    var currentState: PlaybackState { .idle }
    let eventStream: AsyncStream<PlayerEvent> = AsyncStream { $0.finish() }

    func prepare(source: PlaybackSource) async throws {}
    func play() async throws {}
    func pause() async throws {}
    func seek(to time: TimeInterval) async throws {}
    func stop(reason: PlayerStopReason) async throws {}
}

private actor RichEngine: PlayerPlaybackEngine,
    PlayerPlaybackRateEngine,
    PlayerSubtitleEngine,
    PlayerTitledBookmarkEngine,
    PlayerAdaptiveStreamingEngine {
    nonisolated static let capabilities: EngineCapabilities = []
    var currentState: PlaybackState { .idle }
    let eventStream: AsyncStream<PlayerEvent> = AsyncStream { $0.finish() }

    func prepare(source: PlaybackSource) async throws {}
    func play() async throws {}
    func pause() async throws {}
    func seek(to time: TimeInterval) async throws {}
    func stop(reason: PlayerStopReason) async throws {}

    func setPlaybackRate(_ rate: Double) async throws {}

    func setSubtitleVisible(_ isVisible: Bool) async throws {}
    func selectSubtitleTrack(_ trackID: PlayerSubtitleTrackID?) async throws {}
    func setCaptionFontSize(_ fontSize: Int) async throws {}

    func addBookmark(at time: TimeInterval) async throws {}
    func addBookmark(at time: TimeInterval, title: String) async throws {}
    func removeBookmark(at time: TimeInterval) async throws {}
    func currentBookmarks() async -> [Bookmark] { [] }

    func changeBandwidth(_ bps: Int) async throws {}
    func streamInfoList() async -> [StreamInfo] { [] }
}

#if canImport(UIKit)
extension PlayerFeatureAvailabilityTests {
    @Test("PlayerSeekPreviewEngine 채택 → .seekPreview 가용")
    func seekPreviewEngine_reportsSeekPreview() {
        #expect(PlayerFeatureAvailability.probe(SeekPreviewEngine()).contains(.seekPreview))
        #expect(PlayerFeatureAvailability.probe(BareEngine()).contains(.seekPreview) == false)
    }
}

private actor SeekPreviewEngine: PlayerPlaybackEngine, PlayerSeekPreviewEngine {
    nonisolated static let capabilities: EngineCapabilities = []
    var currentState: PlaybackState { .idle }
    let eventStream: AsyncStream<PlayerEvent> = AsyncStream { $0.finish() }

    func prepare(source: PlaybackSource) async throws {}
    func play() async throws {}
    func pause() async throws {}
    func seek(to time: TimeInterval) async throws {}
    func stop(reason: PlayerStopReason) async throws {}
    func seekPreviewImage(at time: TimeInterval) async -> UIImage? { nil }
}
#endif
