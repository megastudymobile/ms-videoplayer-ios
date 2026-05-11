//
//  PlayerError+NSError.swift
//  SmartPlayer
//
//  Created by 모바일개발팀_정준영 on 2026/04/20.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import Foundation
import VideoPlayerCore

public extension PlayerError {
    /// 스펙 §6.5.5 계약 3 — ObjC 호출자가 NSError의 `domain` prefix로 분류할 수 있도록 매핑한다.
    func toNSError() -> NSError {
        let (domain, code, message) = mapping
        return NSError(
            domain: domain,
            code: code,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }

    private var mapping: (domain: String, code: Int, message: String) {
        switch self {
        case .networkError(let message):
            return ("PlayerBridge.Network", 1001, message)
        case .authenticationFailed(let message):
            return ("PlayerBridge.Auth", 1002, message)
        case .decodingError(let message):
            return ("PlayerBridge.Decode", 1003, message)
        case .engineError(let message):
            return ("PlayerBridge.Engine", 1004, message)
        case .unknown(let message):
            return ("PlayerBridge.Unknown", 1099, message)
        }
    }
}
