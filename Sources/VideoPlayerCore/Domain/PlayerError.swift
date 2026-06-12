//
//  PlayerError.swift
//  VideoPlayerModule
//
//  Created by 모바일팀_정준영 on 2026/04/17.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import Foundation

public enum PlayerError: Error, Equatable, Sendable {
    case networkError(String)
    case authenticationFailed(String)
    case decodingError(String)
    case engineError(String)
    /// 라이선스가 만료되었고 갱신으로도 복구 불가(재생 횟수/시간 소진 등).
    case licenseExpired(String)
    /// 라이선스 갱신(updateDRM)으로 복구 가능한 만료.
    case licenseRenewalRequired(String)
    /// 기기 저장 공간 부족 또는 파일 쓰기 실패.
    case storageFull(String)
    /// 중복 다운로드 요청 또는 완료된 콘텐츠 재다운로드 요청.
    case downloadConflict(String)
    /// 대상 콘텐츠가 저장소에 없음.
    case contentNotFound(String)
    /// SDK/DRM 미지원 기기.
    case deviceNotSupported(String)
    /// 현재 엔진이 지원하지 않는 명령.
    case unsupportedCommand(String)
    case unknown(String)
}

extension PlayerError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .networkError(let message),
             .authenticationFailed(let message),
             .decodingError(let message),
             .engineError(let message),
             .licenseExpired(let message),
             .licenseRenewalRequired(let message),
             .storageFull(let message),
             .downloadConflict(let message),
             .contentNotFound(let message),
             .deviceNotSupported(let message),
             .unsupportedCommand(let message),
             .unknown(let message):
            return message
        }
    }
}
