//
//  DownloadedContent.swift
//  VideoPlayerModule
//
//  Created by JunyoungJung on 2026/06/10.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

import Foundation

/// 엔진 중립 다운로드 콘텐츠 모델. host는 이 타입만 보고 벤더 snapshot 타입은 모른다.
public struct DownloadedContent: Sendable, Hashable, Identifiable {
    public enum DownloadStatus: Sendable, Hashable {
        case notDownloaded
        case inProgress(percent: Double, downloadedBytes: Int64)
        case completed
    }

    /// 오프라인 재생 라이선스 상태.
    public enum LicenseStatus: Sendable, Hashable {
        /// DRM 정보 없음 (DRM 미적용 콘텐츠 또는 미확인)
        case unknown
        case valid(LicenseConstraints)
        case expired
    }

    /// 유효 라이선스의 잔여 제약. nil 필드는 해당 제약이 없음을 뜻한다.
    public struct LicenseConstraints: Sendable, Hashable {
        public let expiresAt: Date?
        public let playCountRemaining: Int?
        public let playTimeRemaining: TimeInterval?
        /// 벤더가 갱신 안내 노출을 요구하는 시점인가.
        public let needsRenewalPrompt: Bool

        public init(
            expiresAt: Date? = nil,
            playCountRemaining: Int? = nil,
            playTimeRemaining: TimeInterval? = nil,
            needsRenewalPrompt: Bool = false
        ) {
            self.expiresAt = expiresAt
            self.playCountRemaining = playCountRemaining
            self.playTimeRemaining = playTimeRemaining
            self.needsRenewalPrompt = needsRenewalPrompt
        }
    }

    /// 엔진 콘텐츠 식별자. `PlaybackSource.mediaKey(id)`로 그대로 재생 가능해야 한다.
    public let id: String
    public let title: String
    public let synopsis: String?
    public let thumbnailPath: String?
    public let duration: TimeInterval
    /// 이어보기 위치
    public let lastPosition: TimeInterval
    public let download: DownloadStatus
    public let license: LicenseStatus
    public let fileSize: Int64
    public let downloadedAt: Date?
    /// 중립 모델로 일반화되지 않는 벤더 고유 필드 (예: course, teacher, contentIndex).
    /// UI 표시용 — 로직 분기에 사용하지 않는다.
    public let vendorFields: [String: String]

    public init(
        id: String,
        title: String = "",
        synopsis: String? = nil,
        thumbnailPath: String? = nil,
        duration: TimeInterval = 0,
        lastPosition: TimeInterval = 0,
        download: DownloadStatus = .notDownloaded,
        license: LicenseStatus = .unknown,
        fileSize: Int64 = 0,
        downloadedAt: Date? = nil,
        vendorFields: [String: String] = [:]
    ) {
        self.id = id
        self.title = title
        self.synopsis = synopsis
        self.thumbnailPath = thumbnailPath
        self.duration = duration
        self.lastPosition = lastPosition
        self.download = download
        self.license = license
        self.fileSize = fileSize
        self.downloadedAt = downloadedAt
        self.vendorFields = vendorFields
    }
}

public extension DownloadedContent {
    /// 오프라인 재생 가능 여부 사전 판정. 만료/소진이면 거부 사유(PlayerError)를 반환한다.
    /// (SDK 가이드 — 오프라인 재생 전 라이선스 4조건 검증)
    func validateOfflinePlayability(now: Date = Date()) -> PlayerError? {
        switch license {
        case .expired:
            return .licenseRenewalRequired("오프라인 라이선스가 만료되었습니다.")
        case .valid(let constraints):
            if let expiresAt = constraints.expiresAt, expiresAt <= now {
                return .licenseRenewalRequired("라이선스 유효 기간이 지났습니다.")
            }
            if let count = constraints.playCountRemaining, count <= 0 {
                return .licenseExpired("남은 재생 횟수가 없습니다.")
            }
            if let time = constraints.playTimeRemaining, time <= 0 {
                return .licenseExpired("남은 재생 시간이 없습니다.")
            }
            return nil
        case .unknown:
            return nil
        }
    }
}
