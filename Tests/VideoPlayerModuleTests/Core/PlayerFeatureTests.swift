//
//  PlayerFeatureTests.swift
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

@Suite("PlayerFeature.available — engine.supports 기반 기능 협상")
struct PlayerFeatureTests {

    @Test("기본 엔진은 가용 기능 없음")
    func bareEngine_hasNoFeatures() {
        #expect(PlayerFeature.available(for: BareEngine()) == [])
    }

    @Test("supports 신고가 곧 가용 기능이다")
    func supportingEngine_reportsFeatures() {
        let features = PlayerFeature.available(for: RichEngine())

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
        let core = PlayerCore(engine: RichEngine(), engineRuntimeTraits: .default)

        #expect(core.availableFeatures.contains(.playbackRate))
        #expect(!core.availableFeatures.contains(.pictureInPicture))
    }

    @Test("정책 allows — seekPreview만 정책 게이트, 나머지는 항상 허용")
    func policyAllows_gatesSeekPreviewOnly() {
        let blocked = PlayerFeaturePolicy(
            allowsBackgroundPlayback: false,
            allowedPlaybackRates: [1.0],
            allowsAutoplay: true,
            allowsSeekPreview: false
        )

        #expect(blocked.allows(.seekPreview) == false)
        #expect(blocked.allows(.bookmarks))
        #expect(PlayerFeaturePolicy.default.allows(.seekPreview))
    }
}

// MARK: - Fakes

private actor BareEngine: PlayerPlaybackEngine {
    nonisolated static let runtimeTraits: EngineRuntimeTraits = .default
    let outputStream: AsyncStream<PlayerEngineOutput> = AsyncStream { $0.finish() }

    func handle(_ command: PlaybackCommand) async throws {}
    nonisolated func supports(_ feature: PlayerFeature) -> Bool { false }
}

private actor RichEngine: PlayerPlaybackEngine {
    nonisolated static let runtimeTraits: EngineRuntimeTraits = .default
    let outputStream: AsyncStream<PlayerEngineOutput> = AsyncStream { $0.finish() }

    func handle(_ command: PlaybackCommand) async throws {}

    nonisolated func supports(_ feature: PlayerFeature) -> Bool {
        switch feature {
        case .playbackRate, .subtitles, .bookmarks, .titledBookmarks, .adaptiveStreaming:
            return true
        case .externalSubtitles, .zoom, .scroll, .pictureInPicture, .displayScaling, .displayLock, .seekPreview:
            return false
        }
    }
}

#if canImport(UIKit)
extension PlayerFeatureTests {
    @Test("EngineSeekPreviewAbility 채택 → .seekPreview 가용")
    func seekPreviewEngine_reportsSeekPreview() {
        #expect(PlayerFeature.available(for: SeekPreviewEngine()).contains(.seekPreview))
        #expect(PlayerFeature.available(for: BareEngine()).contains(.seekPreview) == false)
    }
}

private actor SeekPreviewEngine: PlayerPlaybackEngine, EngineSeekPreviewAbility {
    nonisolated static let runtimeTraits: EngineRuntimeTraits = .default
    let outputStream: AsyncStream<PlayerEngineOutput> = AsyncStream { $0.finish() }

    func handle(_ command: PlaybackCommand) async throws {}
    nonisolated func supports(_ feature: PlayerFeature) -> Bool { feature == .seekPreview }
    func seekPreviewImage(at time: TimeInterval) async -> UIImage? { nil }
}
#endif
