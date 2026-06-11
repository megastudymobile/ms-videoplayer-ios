//
//  PlayerCoreCommandCoverageTests.swift
//  VideoPlayerModuleTests
//
//  Created by 모바일개발팀_정준영 on 2026/05/15.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

import Testing
import Foundation
@testable import VideoPlayerCore

@Suite("PlayerCore 명령 라우팅 커버리지")
struct PlayerCoreCommandCoverageTests {

    @Test("미지원 엔진에서 addBookmarkWithTitle은 engineError를 던진다")
    func addBookmarkWithTitle_throwsWhenEngineDoesNotConform() async throws {
        let engine = PlaybackOnlyEngine()
        let core = PlayerCore(engine: engine, engineCapabilities: [])

        await #expect {
            try await core.execute(command: .addBookmarkWithTitle(at: 10, title: "test"))
        } throws: { error in
            guard case let PlayerError.engineError(message) = error else { return false }
            return message.contains("Bookmark")
        }
    }

    @Test("addBookmarkWithTitle은 Titled 엔진을 호출한다")
    func addBookmarkWithTitle_invokesTitledEngine() async throws {
        let engine = TitledBookmarkEngine()
        let core = PlayerCore(engine: engine, engineCapabilities: [])

        try await core.execute(command: .addBookmarkWithTitle(at: 30, title: "chapter1"))

        let recorded = await engine.recorded
        #expect(recorded.count == 1)
        #expect(recorded.first?.time == 30)
        #expect(recorded.first?.title == "chapter1")
    }

    @Test("미지원 엔진에서 removeBookmark는 engineError를 던진다")
    func removeBookmark_throwsWhenEngineDoesNotConform() async throws {
        let engine = PlaybackOnlyEngine()
        let core = PlayerCore(engine: engine, engineCapabilities: [])

        await #expect {
            try await core.execute(command: .removeBookmark(at: 10))
        } throws: { error in
            guard case let PlayerError.engineError(message) = error else { return false }
            return message.contains("Bookmark removal")
        }
    }

    @Test("removeBookmark는 Titled 엔진을 호출한다")
    func removeBookmark_invokesTitledEngine() async throws {
        let engine = TitledBookmarkEngine()
        let core = PlayerCore(engine: engine, engineCapabilities: [])

        try await core.execute(command: .removeBookmark(at: 45))

        let removed = await engine.removedTimes
        #expect(removed == [45])
    }

    @Test("미지원 엔진에서 selectSubtitleFile은 engineError를 던진다")
    func selectSubtitleFile_throwsWhenEngineDoesNotConform() async throws {
        let engine = PlaybackOnlyEngine()
        let core = PlayerCore(engine: engine, engineCapabilities: [])

        await #expect {
            try await core.execute(command: .selectSubtitleFile(URL(string: "https://example.com/a.srt")))
        } throws: { error in
            guard case let PlayerError.engineError(message) = error else { return false }
            return message.contains("subtitle")
        }
    }

    @Test("selectSubtitleFile은 외부 자막 엔진을 호출한다")
    func selectSubtitleFile_invokesExternalSubtitleEngine() async throws {
        let engine = ExternalSubtitleEngine()
        let core = PlayerCore(engine: engine, engineCapabilities: [])

        let url = try #require(URL(string: "https://example.com/sub.srt"))
        try await core.execute(command: .selectSubtitleFile(url))

        let selected = await engine.selectedURLs
        #expect(selected == [url])
    }

    // MARK: - Phase 5 (T029) — title/edge-case coverage for bookmark·subtitle commands

    @Test("addBookmarkWithTitle은 title을 Titled 엔진에 그대로 전달한다")
    func addBookmarkWithTitle_passesTitleToTitledEngine() async throws {
        let engine = TitledBookmarkEngine()
        let core = PlayerCore(engine: engine, engineCapabilities: [])

        // 빈 title: addBookmark(at:title:)가 아니라 addBookmark(at:)로 라우팅된다 (PlayerCore 정책).
        try await core.execute(command: .addBookmarkWithTitle(at: 5, title: ""))

        // 긴 title: 1KB 한계 근처에서 raw 문자열이 손실 없이 전달되는지.
        let longTitle = String(repeating: "북마크", count: 256)
        try await core.execute(command: .addBookmarkWithTitle(at: 120, title: longTitle))

        let recorded = await engine.recorded
        #expect(recorded.count == 2)
        #expect(recorded[0].time == 5)
        #expect(recorded[0].title == "", "빈 title은 무제목 북마크로 기록되어야 한다")
        #expect(recorded[1].time == 120)
        #expect(recorded[1].title == longTitle, "긴 title은 손실 없이 전달되어야 한다")
    }

    @Test("removeBookmark는 음수 time을 검증한다")
    func removeBookmark_validatesNonNegativeTime() async throws {
        let engine = TitledBookmarkEngine()
        let core = PlayerCore(engine: engine, engineCapabilities: [])

        await #expect {
            try await core.execute(command: .removeBookmark(at: -1))
        } throws: { error in
            guard case let PlayerError.engineError(message) = error else { return false }
            return message.contains("greater than or equal to 0")
        }

        let removed = await engine.removedTimes
        #expect(removed.isEmpty, "음수 time은 엔진에 도달해서는 안 된다")
    }

    @Test("selectSubtitleFile은 비활성화를 위한 nil을 허용한다")
    func selectSubtitleFile_acceptsNilForDisable() async throws {
        let engine = ExternalSubtitleEngine()
        let core = PlayerCore(engine: engine, engineCapabilities: [])

        // nil은 외부 자막 비활성화를 의미. throw 없이 엔진까지 nil이 흘러야 한다.
        try await core.execute(command: .selectSubtitleFile(nil))

        let selected = await engine.selectedURLs
        #expect(selected.count == 1)
        if let first = selected.first {
            #expect(first == nil, "nil URL이 엔진까지 그대로 전달되어야 한다")
        } else {
            Issue.record("selectedURLs에 1건이 기록되어야 함")
        }
    }
}

// MARK: - Test fakes

private actor PlaybackOnlyEngine: PlayerPlaybackEngine {
    nonisolated static let capabilities: EngineCapabilities = []

    let outputStream: AsyncStream<PlayerEngineOutput> = AsyncStream { $0.finish() }

    func prepare(source: PlaybackSource) async throws {}
    func play() async throws {}
    func pause() async throws {}
    func seek(to time: TimeInterval) async throws {}
    func stop(reason: PlayerStopReason) async throws {}
}

private actor TitledBookmarkEngine: PlayerPlaybackEngine, PlayerTitledBookmarkEngine {
    nonisolated static let capabilities: EngineCapabilities = []

    private(set) var recorded: [(time: TimeInterval, title: String)] = []
    private(set) var removedTimes: [TimeInterval] = []
    private(set) var bookmarks: [Bookmark] = []

    let outputStream: AsyncStream<PlayerEngineOutput> = AsyncStream { $0.finish() }

    func prepare(source: PlaybackSource) async throws {}
    func play() async throws {}
    func pause() async throws {}
    func seek(to time: TimeInterval) async throws {}
    func stop(reason: PlayerStopReason) async throws {}

    func addBookmark(at time: TimeInterval) async throws {
        recorded.append((time: time, title: ""))
    }

    func addBookmark(at time: TimeInterval, title: String) async throws {
        recorded.append((time: time, title: title))
    }

    func removeBookmark(at time: TimeInterval) async throws {
        removedTimes.append(time)
    }

    func currentBookmarks() async -> [Bookmark] {
        bookmarks
    }
}

private actor ExternalSubtitleEngine: PlayerPlaybackEngine, PlayerExternalSubtitleEngine {
    nonisolated static let capabilities: EngineCapabilities = []

    private(set) var selectedURLs: [URL?] = []

    let outputStream: AsyncStream<PlayerEngineOutput> = AsyncStream { $0.finish() }

    func prepare(source: PlaybackSource) async throws {}
    func play() async throws {}
    func pause() async throws {}
    func seek(to time: TimeInterval) async throws {}
    func stop(reason: PlayerStopReason) async throws {}

    func setSubtitleVisible(_ isVisible: Bool) async throws {}
    func selectSubtitleTrack(_ trackID: PlayerSubtitleTrackID?) async throws {}
    func setCaptionFontSize(_ fontSize: Int) async throws {}

    func selectSubtitleFile(_ fileURL: URL?) async throws {
        selectedURLs.append(fileURL)
    }
}
