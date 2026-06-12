//
//  PlayerLogEntry.swift
//  VideoPlayerModule
//
//  Created by 모바일팀_정준영 on 2026/06/12.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import Foundation

/// 플레이어 모듈이 발행하는 로그 한 건의 불변 값 객체.
/// timestamp/포맷/출력 대상은 host 로깅 시스템의 책임이므로 포함하지 않는다.
public struct PlayerLogEntry: Sendable {
    /// 로그 심각도
    public let level: PlayerLogLevel

    /// 발생 영역 식별자 (예: ``PlayerLogCategory/core``)
    public let category: String

    /// 로그 메시지 본문
    public let message: String

    /// 호출 파일 경로 (`#fileID`)
    public let file: String

    /// 호출 함수명
    public let function: String

    /// 호출 라인 번호
    public let line: Int

    public init(
        level: PlayerLogLevel,
        category: String,
        message: String,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        self.level = level
        self.category = category
        self.message = message
        self.file = file
        self.function = function
        self.line = line
    }
}

/// 모듈 내부에서 사용하는 카테고리 상수.
public enum PlayerLogCategory {
    /// 상태 머신(`PlayerCore`) 영역
    public static let core = "Player.Core"
    /// AVPlayer 엔진 영역
    public static let nativeEngine = "Player.NativeEngine"
    /// Kollus 엔진 영역
    public static let kollusEngine = "Player.KollusEngine"
}

// MARK: - CustomStringConvertible

extension PlayerLogEntry: CustomStringConvertible {
    public var description: String {
        "[\(level.name)] [\(category)] \(message) (\(file):\(line))"
    }
}
