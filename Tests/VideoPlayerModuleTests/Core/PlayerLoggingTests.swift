//
//  PlayerLoggingTests.swift
//  VideoPlayerModule
//
//  Created by 모바일팀_정준영 on 2026/06/12.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import Foundation
import Testing
@testable import VideoPlayerCore

/// 테스트용 수집 logger — 받은 entry를 순서대로 보관한다.
final class RecordingPlayerLogger: PlayerLogger, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [PlayerLogEntry] = []
    private let enabledLevels: Set<PlayerLogLevel>

    init(enabledLevels: Set<PlayerLogLevel> = Set(PlayerLogLevel.allCases)) {
        self.enabledLevels = enabledLevels
    }

    var entries: [PlayerLogEntry] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func isEnabled(_ level: PlayerLogLevel) -> Bool {
        enabledLevels.contains(level)
    }

    func log(_ entry: PlayerLogEntry) {
        lock.lock()
        defer { lock.unlock() }
        storage.append(entry)
    }
}

struct PlayerLogLevelTests {
    @Test("레벨은 debug < info < warning < error 순으로 비교된다")
    func levelOrdering() {
        #expect(PlayerLogLevel.debug < .info)
        #expect(PlayerLogLevel.info < .warning)
        #expect(PlayerLogLevel.warning < .error)
    }
}

struct PlayerLoggerTests {
    @Test("편의 메서드는 레벨·카테고리·메시지·호출 위치를 entry에 담는다")
    func convenienceBuildsEntry() throws {
        let logger = RecordingPlayerLogger()

        logger.warning("transient failure", category: PlayerLogCategory.core)

        #expect(logger.entries.count == 1)
        let entry = try #require(logger.entries.first)
        #expect(entry.level == .warning)
        #expect(entry.category == PlayerLogCategory.core)
        #expect(entry.message == "transient failure")
        #expect(entry.file.hasSuffix("PlayerLoggingTests.swift"))
        #expect(entry.line > 0)
    }

    @Test("비활성 레벨은 메시지 autoclosure를 평가하지 않는다")
    func disabledLevelSkipsMessageEvaluation() {
        let logger = RecordingPlayerLogger(enabledLevels: [.error])
        var evaluated = false

        logger.debug(
            {
                evaluated = true
                return "expensive message"
            }(),
            category: PlayerLogCategory.core
        )

        #expect(!evaluated)
        #expect(logger.entries.isEmpty)
    }

    @Test("NoopPlayerLogger는 모든 레벨이 비활성이다")
    func noopLoggerDisablesAllLevels() {
        let logger = NoopPlayerLogger()

        for level in PlayerLogLevel.allCases {
            #expect(!logger.isEnabled(level))
        }
    }
}
