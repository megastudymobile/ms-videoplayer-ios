//
//  PlayerErrorClassifier.swift
//  VideoPlayerModule
//
//  Created by 모바일팀_정준영 on 2026/06/10.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import Foundation

/// 에러가 발생한 작업 지점. SDK가 도메인/코드 상수를 공개하지 않는 경우
/// 트리거 시점이 분류의 1차 근거가 된다 (Kollus SDK 가이드 09-error-code 트리거 표 참조).
public enum PlayerErrorContext: Sendable {
    /// SDK 세션/저장소 시작 (인증·기기 검증 시점)
    case bootstrap
    /// 콘텐츠 메타 등록·조회 (loadContentURL / checkContentURL)
    case resolve
    /// 다운로드 시작·진행
    case download
    /// 콘텐츠/캐시 삭제
    case removal
    /// 라이선스 갱신 (updateDRM)
    case licenseRenewal
    /// 재생 준비·재생 명령
    case playback
}

/// 벤더 SDK의 NSError를 `PlayerError` 구체 케이스로 분류하는 확장 포인트.
/// 엔진 모듈이 자기 SDK 전용 분류기를 구현해 chain 앞단에 등록한다.
public protocol PlayerErrorClassifier: Sendable {
    /// 분류 성공 시 PlayerError, 알 수 없는 에러면 nil (다음 분류기로 위임).
    func classify(_ error: NSError, context: PlayerErrorContext) -> PlayerError?
}

/// 분류기 체인. 앞에서부터 순회하며 첫 비-nil 결과를 채택하고,
/// 전부 실패하면 `PlayerError.classify`(Foundation 도메인 기반)로 폴백한다.
public struct PlayerErrorClassifierChain: Sendable {
    private let classifiers: [any PlayerErrorClassifier]

    public init(classifiers: [any PlayerErrorClassifier] = []) {
        self.classifiers = classifiers
    }

    public func classify(_ error: Error, context: PlayerErrorContext) -> PlayerError {
        if let playerError = error as? PlayerError {
            return playerError
        }
        let nsError = error as NSError
        for classifier in classifiers {
            if let classified = classifier.classify(nsError, context: context) {
                return classified
            }
        }
        return PlayerError.classify(error)
    }
}
