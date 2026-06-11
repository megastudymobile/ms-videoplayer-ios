//
//  PreferenceManagerTests.swift
//  VideoPlayerExampleTests
//
//  Created by JunyoungJung on 2026/06/10.
//

import Foundation
import Testing
@testable import VideoPlayerExample

/// UserDefaults.standard 공유 — 키 충돌 방지 위해 직렬 실행.
@Suite("PreferenceManager 라운드트립/파생값", .serialized)
struct PreferenceManagerTests {

    @Test("기본 배속 라운드트립")
    func playbackRate_roundTrips() {
        let original = PreferenceManager.playbackRate
        defer { PreferenceManager.playbackRate = original }

        PreferenceManager.playbackRate = 4.0
        #expect(PreferenceManager.playbackRate == 4.0)
        #expect(PlaybackRate.min == 0.5)
        #expect(PlaybackRate.max == 2.0)
        #expect(PlaybackRate.settingsMax == 4.0)
        #expect(PlaybackRate.step == 0.1)
        #expect(PlaybackRate.clampedForSettings(4.5) == 4.0)
    }

    @Test("코덱 표시명은 레거시 디코더 문자열을 사용")
    func playerCodecTitles_matchLegacyDisplayNames() {
        #expect(PlayerCodec.allCases.map(\.title) == ["iOS 내장", "H/W", "S/W"])
    }

    @Test("코덱 설정 → hardwareDecoderPreferred 파생")
    func playerCodec_drivesHardwareDecoderPreferred() {
        let original = PreferenceManager.playerCodec
        defer { PreferenceManager.playerCodec = original }

        PreferenceManager.playerCodec = PlayerCodec.software.rawValue
        #expect(PreferenceManager.hardwareDecoderPreferred == false)

        PreferenceManager.playerCodec = PlayerCodec.hardware.rawValue
        #expect(PreferenceManager.hardwareDecoderPreferred == true)
    }

    @Test("시크 간격 → seekRangeSeconds 파생, 비정상 rawValue는 10초 폴백")
    func seekRange_derivesSeconds() {
        let original = PreferenceManager.seekRange
        defer { PreferenceManager.seekRange = original }

        #expect(SeekRange.allCases.map(\.seconds) == [5, 10, 15, 20, 30, 40, 50, 60, 120, 180, 200])

        PreferenceManager.seekRange = SeekRange.r200.rawValue
        #expect(PreferenceManager.seekRangeSeconds == 200)

        PreferenceManager.seekRange = 9_999   // 정의되지 않은 rawValue
        #expect(PreferenceManager.seekRangeSeconds == 10)
    }

    @Test("시킹 프리뷰 토글 — 기본 true, 라운드트립")
    func useSeekPreview_defaultsTrueAndRoundTrips() {
        let original = PreferenceManager.useSeekPreview
        defer { PreferenceManager.useSeekPreview = original }

        UserDefaults.standard.removeObject(forKey: "useSeekPreview")
        #expect(PreferenceManager.useSeekPreview == true)

        PreferenceManager.useSeekPreview = false
        #expect(PreferenceManager.useSeekPreview == false)
    }

    @Test("자막 크기 설정은 10~40pt 7단계를 제공하고 기본값은 20pt")
    func subtitleSize_matchesLegacySteps() {
        let original = PreferenceManager.subtitleSize
        defer { PreferenceManager.subtitleSize = original }

        PreferenceManager.subtitleSize = SubtitleSize.normal.rawValue
        #expect(SubtitleSize.allCases.map(\.fontSize) == [10, 15, 20, 25, 30, 35, 40])
        #expect(PreferenceManager.captionFontSize == 20)
    }

    @Test("reset은 isFirstExecuted를 보존하고 나머지를 초기화")
    func reset_preservesFirstExecutedFlag() {
        let originalRate = PreferenceManager.playbackRate
        let originalFirst = PreferenceManager.isFirstExecuted
        defer {
            PreferenceManager.playbackRate = originalRate
            PreferenceManager.isFirstExecuted = originalFirst
        }

        PreferenceManager.isFirstExecuted = true
        PreferenceManager.playbackRate = 1.75

        PreferenceManager.reset()

        #expect(PreferenceManager.isFirstExecuted == true)
        #expect(PreferenceManager.playbackRate == 1.0)   // 기본값 복원
    }
}
