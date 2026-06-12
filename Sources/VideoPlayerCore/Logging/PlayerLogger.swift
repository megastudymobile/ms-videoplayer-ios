//
//  PlayerLogger.swift
//  VideoPlayerModule
//
//  Created by 모바일팀_정준영 on 2026/06/12.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import Foundation

/// host가 주입하는 로깅 계약. 모듈은 이 protocol로만 로그를 발행하고
/// 출력 대상(콘솔/파일/원격)·포맷·버퍼링은 host 구현이 결정한다.
///
/// ```swift
/// // host 측 어댑터 예시 — os.Logger로 브리지
/// struct OSLogPlayerLogger: PlayerLogger {
///     func log(_ entry: PlayerLogEntry) {
///         Logger(subsystem: "com.example.app", category: entry.category)
///             .log("\(entry.message)")
///     }
/// }
/// ```
public protocol PlayerLogger: Sendable {
    /// 해당 레벨의 로그를 수집할지 여부. `false`면 편의 메서드가 메시지 생성 자체를 생략한다.
    func isEnabled(_ level: PlayerLogLevel) -> Bool

    /// 로그 한 건 처리. 호출 스레드는 보장되지 않으므로 구현이 스레드 안전해야 한다.
    func log(_ entry: PlayerLogEntry)
}

public extension PlayerLogger {
    func isEnabled(_ level: PlayerLogLevel) -> Bool {
        true
    }
}

// MARK: - Convenience

public extension PlayerLogger {
    /// 레벨이 비활성이면 autoclosure 평가 없이 반환해 메시지 생성 비용을 피한다.
    func log(
        _ level: PlayerLogLevel,
        category: String,
        _ message: @autoclosure () -> String,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        guard isEnabled(level) else {
            return
        }
        log(PlayerLogEntry(
            level: level,
            category: category,
            message: message(),
            file: file,
            function: function,
            line: line
        ))
    }

    func debug(
        _ message: @autoclosure () -> String,
        category: String,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        log(.debug, category: category, message(), file: file, function: function, line: line)
    }

    func info(
        _ message: @autoclosure () -> String,
        category: String,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        log(.info, category: category, message(), file: file, function: function, line: line)
    }

    func warning(
        _ message: @autoclosure () -> String,
        category: String,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        log(.warning, category: category, message(), file: file, function: function, line: line)
    }

    func error(
        _ message: @autoclosure () -> String,
        category: String,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        log(.error, category: category, message(), file: file, function: function, line: line)
    }
}

// MARK: - NoopPlayerLogger

/// 기본 logger — 아무것도 기록하지 않는다. host가 주입하지 않으면 모듈은 침묵한다.
public struct NoopPlayerLogger: PlayerLogger {
    public init() {}

    public func isEnabled(_ level: PlayerLogLevel) -> Bool {
        false
    }

    public func log(_ entry: PlayerLogEntry) {}
}
