//
//  PlayerError+Classify.swift
//  VideoPlayerModule
//
//  Created by 모바일팀_정준영 on 2026/06/02.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

import Foundation

public extension PlayerError {
    /// 임의 `Error`를 `PlayerError`의 구체 케이스로 분류한다.
    ///
    /// `NSError`의 `domain`/`code`를 검사해 네트워크/인증/디코딩 실패를 UI가 구분할 수 있는
    /// 구체 케이스로 매핑한다.
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
}
