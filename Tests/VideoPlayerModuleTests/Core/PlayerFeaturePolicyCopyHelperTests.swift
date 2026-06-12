//
//  PlayerFeaturePolicyCopyHelperTests.swift
//  VideoPlayerModuleTests
//
//  Created by JunyoungJung on 2026/06/12.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

import Foundation
import Testing
@testable import VideoPlayerCore

@Suite("PlayerFeaturePolicy copy helper")
struct PlayerFeaturePolicyCopyHelperTests {

    @Test("background downgrade 후 allowsSeekPreview false를 보존한다")
    func backgroundDowngradePreservesSeekPreviewPolicy() async throws {
        let core = PlayerCore(
            engine: PolicyRecordingEngine(),
            engineRuntimeTraits: .default
        )
        let policy = PlayerFeaturePolicy(
            allowsBackgroundPlayback: true,
            allowedPlaybackRates: [0.8, 1.0, 1.5],
            allowsAutoplay: false,
            skipInterval: 15,
            nextEpisodeButtonLeadTime: 25,
            allowsSeekPreview: false
        )

        try await core.start(source: .url(testURL), policy: policy)

        let currentPolicy = await core.currentPolicy
        #expect(currentPolicy.allowsBackgroundPlayback == false)
        #expect(currentPolicy.allowsSeekPreview == false)
        #expect(currentPolicy.allowedPlaybackRates == [0.8, 1.0, 1.5])
        #expect(currentPolicy.allowsAutoplay == false)
        #expect(currentPolicy.skipInterval == 15)
        #expect(currentPolicy.nextEpisodeButtonLeadTime == 25)
    }

    @Test("setSkipInterval 처리 후 allowsSeekPreview false를 보존한다")
    func setSkipIntervalPreservesSeekPreviewPolicy() async throws {
        let core = PlayerCore(
            engine: PolicyRecordingEngine(),
            engineRuntimeTraits: .default,
            initialPolicy: PlayerFeaturePolicy(
                allowsBackgroundPlayback: false,
                allowedPlaybackRates: [1.0, 1.25],
                allowsAutoplay: true,
                skipInterval: 10,
                nextEpisodeButtonLeadTime: 20,
                allowsSeekPreview: false
            )
        )

        try await core.execute(command: .setSkipInterval(35))

        let currentPolicy = await core.currentPolicy
        #expect(currentPolicy.skipInterval == 35)
        #expect(currentPolicy.allowsSeekPreview == false)
        #expect(currentPolicy.allowsBackgroundPlayback == false)
        #expect(currentPolicy.allowedPlaybackRates == [1.0, 1.25])
        #expect(currentPolicy.allowsAutoplay)
        #expect(currentPolicy.nextEpisodeButtonLeadTime == 20)
    }

    @Test("helper는 대상 필드 외 모든 정책 필드를 보존한다")
    func copyHelpersPreserveUntargetedFields() {
        let policy = PlayerFeaturePolicy(
            allowsBackgroundPlayback: true,
            allowedPlaybackRates: [1.5, 0.75, 1.0],
            allowsAutoplay: false,
            skipInterval: 12,
            nextEpisodeButtonLeadTime: 45,
            allowsSeekPreview: false
        )

        let backgroundChanged = policy.withBackgroundPlayback(false)
        #expect(backgroundChanged.allowsBackgroundPlayback == false)
        #expect(backgroundChanged.allowedPlaybackRates == policy.allowedPlaybackRates)
        #expect(backgroundChanged.allowsAutoplay == policy.allowsAutoplay)
        #expect(backgroundChanged.skipInterval == policy.skipInterval)
        #expect(backgroundChanged.nextEpisodeButtonLeadTime == policy.nextEpisodeButtonLeadTime)
        #expect(backgroundChanged.allowsSeekPreview == policy.allowsSeekPreview)

        let skipChanged = policy.withSkipInterval(30)
        #expect(skipChanged.allowsBackgroundPlayback == policy.allowsBackgroundPlayback)
        #expect(skipChanged.allowedPlaybackRates == policy.allowedPlaybackRates)
        #expect(skipChanged.allowsAutoplay == policy.allowsAutoplay)
        #expect(skipChanged.skipInterval == 30)
        #expect(skipChanged.nextEpisodeButtonLeadTime == policy.nextEpisodeButtonLeadTime)
        #expect(skipChanged.allowsSeekPreview == policy.allowsSeekPreview)
    }

    private var testURL: URL {
        URL(string: "https://example.com/video.m3u8")!
    }
}

private actor PolicyRecordingEngine: PlayerPlaybackEngine {
    nonisolated static let runtimeTraits: EngineRuntimeTraits = .default
    let outputStream: AsyncStream<PlayerEngineOutput> = AsyncStream { $0.finish() }

    func handle(_ command: PlaybackCommand) async throws {}
    nonisolated func supports(_ feature: PlayerFeature) -> Bool { false }
}
