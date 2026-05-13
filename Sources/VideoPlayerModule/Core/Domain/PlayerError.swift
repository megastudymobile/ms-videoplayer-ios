//
//  PlayerError.swift
//  VideoPlayerModule
//
//  Created by 모바일개발팀_정준영 on 2026/04/17.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

import Foundation

public enum PlayerError: Error, Equatable, Sendable {
    case networkError(String)
    case authenticationFailed(String)
    case decodingError(String)
    case engineError(String)
    case unknown(String)
}

extension PlayerError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .networkError(let message),
             .authenticationFailed(let message),
             .decodingError(let message),
             .engineError(let message),
             .unknown(let message):
            return message
        }
    }
}
