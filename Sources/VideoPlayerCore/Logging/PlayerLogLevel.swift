//
//  PlayerLogLevel.swift
//  VideoPlayerModule
//
//  Created by 모바일팀_정준영 on 2026/06/12.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import Foundation

/// 플레이어 모듈 로그 심각도. host 로깅 시스템의 레벨로 매핑해 사용한다.
public enum PlayerLogLevel: Int, Comparable, Sendable, CaseIterable {
    /// 신호/상태 전이 추적 등 개발용 상세 로그
    case debug = 0
    /// 일반 정보성 로그
    case info = 1
    /// 동작은 계속되지만 주의가 필요한 상황 (예: transient 명령 실패 무시)
    case warning = 2
    /// 재생 실패 등 오류
    case error = 3

    public static func < (lhs: PlayerLogLevel, rhs: PlayerLogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// 로그 레벨의 문자열 표현
    public var name: String {
        switch self {
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warning: return "WARNING"
        case .error: return "ERROR"
        }
    }
}
