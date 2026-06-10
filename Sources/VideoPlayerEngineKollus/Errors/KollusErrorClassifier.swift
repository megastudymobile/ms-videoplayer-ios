//
//  KollusErrorClassifier.swift
//  VideoPlayerModule
//
//  Created by JunyoungJung on 2026/06/10.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

import Foundation
import VideoPlayerCore

/// Kollus SDK NSError 분류기.
///
/// Kollus iOS SDK는 에러 도메인/코드 상수를 헤더로 공개하지 않는다.
/// 따라서 두 단계로 분류한다:
/// 1. `codeTable` — 실기기 QA로 확정한 코드값 매핑 (host/모듈이 주입·갱신)
/// 2. context 폴백 — 코드가 테이블에 없을 때
///    작업 지점만으로 확실하게 좁혀지는 카테고리만 분류하고, 모호하면 nil(체인 폴백).
public struct KollusErrorClassifier: PlayerErrorClassifier {
    /// SDK 에러 코드 → 분류 결과. 실기기에서 관측된 코드를 확정하는 대로 추가한다.
    public enum Kind: Sendable {
        case authenticationFailed
        case deviceNotSupported
        case storageFull
        case downloadConflict
        case contentNotFound
        case licenseExpired
        case licenseRenewalRequired
    }

    private let codeTable: [Int: Kind]

    // SDK가 코드 상수를 공개하지 않으므로 기본 테이블은 비워 둔다 —
    // 추측 매핑은 다른 작업의 동일 코드를 오분류할 수 있어 실기기 QA로 확정한 값만 주입한다.
    public init(codeTable: [Int: Kind] = [:]) {
        self.codeTable = codeTable
    }

    public func classify(_ error: NSError, context: PlayerErrorContext) -> PlayerError? {
        // Foundation/AVFoundation 도메인은 Core 기본 분류기 담당 — 여기서 가로채지 않는다.
        guard error.domain != NSURLErrorDomain, error.domain != "AVFoundationErrorDomain" else {
            return nil
        }

        let message = error.localizedDescription

        if let kind = codeTable[error.code] {
            return playerError(for: kind, message: message)
        }

        // Context 폴백 — 시점만으로 단일 카테고리로 좁혀지는 경우만.
        switch context {
        case .bootstrap:
            // start()/startWithCheck() 실패 = 인증 오류 또는 기기 미지원.
            // 둘을 코드 없이 구분할 수 없으므로 사용자 행동이 같은(앱 업데이트/문의) 인증 실패로 수렴.
            return .authenticationFailed(message)
        case .licenseRenewal:
            // updateDRM 실패 — 재시도(갱신)로 복구 가능한 범주.
            return .licenseRenewalRequired(message)
        case .resolve, .download, .removal, .playback:
            // 저장소 풀/중복/미존재/IO 가 코드 없이 섞이는 지점 — 오분류보다 미분류가 낫다.
            return nil
        }
    }

    private func playerError(for kind: Kind, message: String) -> PlayerError {
        switch kind {
        case .authenticationFailed: return .authenticationFailed(message)
        case .deviceNotSupported: return .deviceNotSupported(message)
        case .storageFull: return .storageFull(message)
        case .downloadConflict: return .downloadConflict(message)
        case .contentNotFound: return .contentNotFound(message)
        case .licenseExpired: return .licenseExpired(message)
        case .licenseRenewalRequired: return .licenseRenewalRequired(message)
        }
    }
}
