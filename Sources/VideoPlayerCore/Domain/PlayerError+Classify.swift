//
//  PlayerError+Classify.swift
//  VideoPlayerModule
//
//  Created by 모바일팀_정준영 on 2026/06/02.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

import Foundation

public extension PlayerError {
    /// H3 — 임의 `Error`를 `PlayerError`의 구체 케이스로 분류한다.
    ///
    /// 과거에는 모든 비-`PlayerError`가 `.unknown`으로 평탄화되어 네트워크/인증/디코딩 실패를
    /// UI에서 구분할 수 없었다. `NSError`의 `domain`/`code`를 검사해 가능한 한 구체 케이스로 매핑한다.
    /// 분류 불가한 도메인은 `.unknown`을 반환한다(엔진 컨텍스트 보강은 호출 측 책임).
    static func classify(_ error: Error) -> PlayerError {
        if let playerError = error as? PlayerError {
            return playerError
        }

        let nsError = error as NSError
        let message = nsError.localizedDescription

        switch nsError.domain {
        case NSURLErrorDomain:
            switch nsError.code {
            case NSURLErrorUserAuthenticationRequired,
                 NSURLErrorClientCertificateRequired,
                 NSURLErrorClientCertificateRejected,
                 NSURLErrorSecureConnectionFailed,
                 NSURLErrorServerCertificateUntrusted,
                 NSURLErrorServerCertificateHasBadDate,
                 NSURLErrorServerCertificateNotYetValid:
                return .authenticationFailed(message)
            default:
                return .networkError(message)
            }

        // AVFoundation 미디어 디코딩 실패. Core가 AVFoundation을 import하지 않도록 도메인 문자열로 비교.
        case "AVFoundationErrorDomain":
            return .decodingError(message)

        default:
            return .unknown(message)
        }
    }

    /// H3 — `classify` 결과가 `.unknown`이면 엔진 컨텍스트를 붙여 `.engineError`로 승격한다.
    /// 네트워크/인증/디코딩으로 분류된 경우 그 분류를 그대로 유지한다.
    static func classify(_ error: Error, engineContext context: String) -> PlayerError {
        if let playerError = error as? PlayerError {
            return playerError
        }

        let classified = classify(error)
        if case .unknown = classified {
            return .engineError("\(context): \((error as NSError).localizedDescription)")
        }
        return classified
    }
}
