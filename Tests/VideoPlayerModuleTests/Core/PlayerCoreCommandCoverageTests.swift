//
//  PlayerCoreCommandCoverageTests.swift
//  VideoPlayerModuleTests
//
//  Created by 모바일개발팀_정준영 on 2026/05/15.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

import XCTest
@testable import VideoPlayerCore

final class PlayerCoreCommandCoverageTests: XCTestCase {

    func test_addBookmarkWithTitle_throwsWhenEngineDoesNotConform() async throws {
        let engine = PlaybackOnlyEngine()
        let core = PlayerCore(engine: engine, engineCapabilities: [])

        do {
            try await core.execute(command: .addBookmarkWithTitle(at: 10, title: "test"))
            XCTFail("Expected engineError")
        } catch let PlayerError.engineError(message) {
            XCTAssertTrue(message.contains("Bookmark"))
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func test_addBookmarkWithTitle_invokesTitledEngine() async throws {
        let engine = TitledBookmarkEngine()
        let core = PlayerCore(engine: engine, engineCapabilities: [])

        try await core.execute(command: .addBookmarkWithTitle(at: 30, title: "chapter1"))

        let recorded = await engine.recorded
        XCTAssertEqual(recorded.count, 1)
        XCTAssertEqual(recorded.first?.time, 30)
        XCTAssertEqual(recorded.first?.title, "chapter1")
    }

    func test_removeBookmark_throwsWhenEngineDoesNotConform() async throws {
        let engine = PlaybackOnlyEngine()
        let core = PlayerCore(engine: engine, engineCapabilities: [])

        do {
            try await core.execute(command: .removeBookmark(at: 10))
            XCTFail("Expected engineError")
        } catch let PlayerError.engineError(message) {
            XCTAssertTrue(message.contains("Bookmark removal"))
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func test_removeBookmark_invokesTitledEngine() async throws {
        let engine = TitledBookmarkEngine()
        let core = PlayerCore(engine: engine, engineCapabilities: [])

        try await core.execute(command: .removeBookmark(at: 45))

        let removed = await engine.removedTimes
        XCTAssertEqual(removed, [45])
    }

    func test_selectSubtitleFile_throwsWhenEngineDoesNotConform() async throws {
        let engine = PlaybackOnlyEngine()
        let core = PlayerCore(engine: engine, engineCapabilities: [])

        do {
            try await core.execute(command: .selectSubtitleFile(URL(string: "https://example.com/a.srt")))
            XCTFail("Expected engineError")
        } catch let PlayerError.engineError(message) {
            XCTAssertTrue(message.contains("subtitle"))
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func test_selectSubtitleFile_invokesExternalSubtitleEngine() async throws {
        let engine = ExternalSubtitleEngine()
        let core = PlayerCore(engine: engine, engineCapabilities: [])

        let url = URL(string: "https://example.com/sub.srt")!
        try await core.execute(command: .selectSubtitleFile(url))

        let selected = await engine.selectedURLs
        XCTAssertEqual(selected, [url])
    }

    // MARK: - Phase 5 (T029) — title/edge-case coverage for bookmark·subtitle commands

    func test_addBookmarkWithTitle_passesTitleToTitledEngine() async throws {
        let engine = TitledBookmarkEngine()
        let core = PlayerCore(engine: engine, engineCapabilities: [])

        // 빈 title: addBookmark(at:title:)가 아니라 addBookmark(at:)로 라우팅된다 (PlayerCore 정책).
        try await core.execute(command: .addBookmarkWithTitle(at: 5, title: ""))

        // 긴 title: 1KB 한계 근처에서 raw 문자열이 손실 없이 전달되는지.
        let longTitle = String(repeating: "북마크", count: 256)
        try await core.execute(command: .addBookmarkWithTitle(at: 120, title: longTitle))

        let recorded = await engine.recorded
        XCTAssertEqual(recorded.count, 2)
        XCTAssertEqual(recorded[0].time, 5)
        XCTAssertEqual(recorded[0].title, "", "빈 title은 무제목 북마크로 기록되어야 한다")
        XCTAssertEqual(recorded[1].time, 120)
        XCTAssertEqual(recorded[1].title, longTitle, "긴 title은 손실 없이 전달되어야 한다")
    }

    func test_removeBookmark_validatesNonNegativeTime() async throws {
        let engine = TitledBookmarkEngine()
        let core = PlayerCore(engine: engine, engineCapabilities: [])

        do {
            try await core.execute(command: .removeBookmark(at: -1))
            XCTFail("Expected engineError for negative time")
        } catch let PlayerError.engineError(message) {
            XCTAssertTrue(message.contains("greater than or equal to 0"), "got: \(message)")
        } catch {
            XCTFail("unexpected error: \(error)")
        }

        let removed = await engine.removedTimes
        XCTAssertTrue(removed.isEmpty, "음수 time은 엔진에 도달해서는 안 된다")
    }

    func test_selectSubtitleFile_acceptsNilForDisable() async throws {
        let engine = ExternalSubtitleEngine()
        let core = PlayerCore(engine: engine, engineCapabilities: [])

        // nil은 외부 자막 비활성화를 의미. throw 없이 엔진까지 nil이 흘러야 한다.
        try await core.execute(command: .selectSubtitleFile(nil))

        let selected = await engine.selectedURLs
        XCTAssertEqual(selected.count, 1)
        if let first = selected.first {
            XCTAssertNil(first, "nil URL이 엔진까지 그대로 전달되어야 한다")
        } else {
            XCTFail("selectedURLs에 1건이 기록되어야 함")
        }
    }
}

// MARK: - Test fakes

private actor PlaybackOnlyEngine: PlayerPlaybackEngine {
    nonisolated static let capabilities: EngineCapabilities = []

    var currentState: PlaybackState { .idle }
    let eventStream: AsyncStream<PlayerEvent>
    private let continuation: AsyncStream<PlayerEvent>.Continuation

    init() {
        var continuation: AsyncStream<PlayerEvent>.Continuation?
        self.eventStream = AsyncStream { continuation = $0 }
        self.continuation = continuation!
    }

    deinit { continuation.finish() }

    func prepare(source: PlaybackSource) async throws {}
    func play() {}
    func pause() {}
    func seek(to time: TimeInterval) async {}
    func stop() {}
}

private actor TitledBookmarkEngine: PlayerPlaybackEngine, PlayerTitledBookmarkEngine {
    nonisolated static let capabilities: EngineCapabilities = []

    var currentState: PlaybackState { .idle }
    let eventStream: AsyncStream<PlayerEvent>
    private let continuation: AsyncStream<PlayerEvent>.Continuation

    private(set) var recorded: [(time: TimeInterval, title: String)] = []
    private(set) var removedTimes: [TimeInterval] = []
    private(set) var bookmarks: [Bookmark] = []

    init() {
        var continuation: AsyncStream<PlayerEvent>.Continuation?
        self.eventStream = AsyncStream { continuation = $0 }
        self.continuation = continuation!
    }

    deinit { continuation.finish() }

    func prepare(source: PlaybackSource) async throws {}
    func play() {}
    func pause() {}
    func seek(to time: TimeInterval) async {}
    func stop() {}

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

    var currentState: PlaybackState { .idle }
    let eventStream: AsyncStream<PlayerEvent>
    private let continuation: AsyncStream<PlayerEvent>.Continuation

    private(set) var selectedURLs: [URL?] = []

    init() {
        var continuation: AsyncStream<PlayerEvent>.Continuation?
        self.eventStream = AsyncStream { continuation = $0 }
        self.continuation = continuation!
    }

    deinit { continuation.finish() }

    func prepare(source: PlaybackSource) async throws {}
    func play() {}
    func pause() {}
    func seek(to time: TimeInterval) async {}
    func stop() {}

    func setSubtitleVisible(_ isVisible: Bool) async throws {}
    func selectSubtitleTrack(_ trackID: PlayerSubtitleTrackID?) async throws {}
    func setCaptionFontSize(_ fontSize: Int) async throws {}

    func selectSubtitleFile(_ fileURL: URL?) async throws {
        selectedURLs.append(fileURL)
    }
}
