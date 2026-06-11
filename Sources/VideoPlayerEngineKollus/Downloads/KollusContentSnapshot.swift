//
//  KollusContentSnapshot.swift
//  VideoPlayerModule
//
//  Created by 모바일팀_정준영 on 2026/05/15.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import CoreGraphics
import Foundation
import VideoPlayerCore

#if canImport(KollusSDKBinary)
import KollusSDKBinary
#endif

/// SDK `KollusContent` → 중립 모델 변환 중간 표현. host에는 `DownloadedContent`만 노출된다.
struct KollusContentSnapshot: Sendable, Hashable, Identifiable {
    enum ContentType: Sendable, Hashable {
        case streaming
        case downloading
        case hlsStreaming
        case hlsDownload
        case sample
    }

    enum DRMStatus: Sendable, Hashable {
        case unknown
        case valid(
            expiresAt: Date?,
            playCountRemaining: Int?,
            playTimeRemaining: TimeInterval?,
            needsRenewalPrompt: Bool
        )
        case expired
    }

    enum DownloadStatus: Sendable, Hashable {
        case notDownloaded
        case inProgress(percent: Double, downloadedBytes: Int64)
        case completed
    }

    let id: String
    let title: String
    let course: String
    let teacher: String
    let synopsis: String?
    let thumbnailPath: String?
    let snapshotPath: String?
    let descriptionURL: URL?
    let naturalSize: CGSize
    let duration: TimeInterval
    let position: TimeInterval
    let contentType: ContentType
    let drm: DRMStatus
    let download: DownloadStatus
    let fileSize: Int64
    let downloadedAt: Date?
    /// SDK가 오프라인 재생에 사용하는 인덱스 (KollusContent.contentIndex)
    let contentIndex: Int
    /// 다운로드 중단 시점 바이트 (재개 위치 표시용)
    let downloadStopSize: Int64

    init(
        id: String,
        title: String = "",
        course: String = "",
        teacher: String = "",
        synopsis: String? = nil,
        thumbnailPath: String? = nil,
        snapshotPath: String? = nil,
        descriptionURL: URL? = nil,
        naturalSize: CGSize = .zero,
        duration: TimeInterval = 0,
        position: TimeInterval = 0,
        contentType: ContentType = .streaming,
        drm: DRMStatus = .unknown,
        download: DownloadStatus = .notDownloaded,
        fileSize: Int64 = 0,
        downloadedAt: Date? = nil,
        contentIndex: Int = 0,
        downloadStopSize: Int64 = 0
    ) {
        self.id = id
        self.title = title
        self.course = course
        self.teacher = teacher
        self.synopsis = synopsis
        self.thumbnailPath = thumbnailPath
        self.snapshotPath = snapshotPath
        self.descriptionURL = descriptionURL
        self.naturalSize = naturalSize
        self.duration = duration
        self.position = position
        self.contentType = contentType
        self.drm = drm
        self.download = download
        self.fileSize = fileSize
        self.downloadedAt = downloadedAt
        self.contentIndex = contentIndex
        self.downloadStopSize = downloadStopSize
    }
}

// MARK: - 중립 모델 변환

extension KollusContentSnapshot {
    func toDownloadedContent() -> DownloadedContent {
        var vendorFields: [String: String] = [:]
        if !course.isEmpty { vendorFields["course"] = course }
        if !teacher.isEmpty { vendorFields["teacher"] = teacher }
        if contentIndex > 0 { vendorFields["contentIndex"] = String(contentIndex) }
        if downloadStopSize > 0 { vendorFields["downloadStopSize"] = String(downloadStopSize) }

        return DownloadedContent(
            id: id,
            title: title,
            synopsis: synopsis,
            thumbnailPath: thumbnailPath,
            snapshotPath: snapshotPath,
            duration: duration,
            lastPosition: position,
            download: neutralDownloadStatus,
            license: neutralLicenseStatus,
            fileSize: fileSize,
            downloadedAt: downloadedAt,
            vendorFields: vendorFields
        )
    }

    private var neutralDownloadStatus: DownloadedContent.DownloadStatus {
        switch download {
        case .notDownloaded:
            return .notDownloaded
        case .inProgress(let percent, let bytes):
            return .inProgress(percent: percent, downloadedBytes: bytes)
        case .completed:
            return .completed
        }
    }

    private var neutralLicenseStatus: DownloadedContent.LicenseStatus {
        switch drm {
        case .unknown:
            return .unknown
        case .expired:
            return .expired
        case .valid(let expiresAt, let count, let time, let prompt):
            return .valid(.init(
                expiresAt: expiresAt,
                playCountRemaining: count,
                playTimeRemaining: time,
                needsRenewalPrompt: prompt
            ))
        }
    }
}

#if canImport(KollusSDKBinary)

extension KollusContentSnapshot {
    static func fromSDKContent(_ content: KollusContent) -> KollusContentSnapshot {
        KollusContentSnapshot(
            id: content.mediaContentKey ?? "",
            title: content.title ?? "",
            course: content.course ?? "",
            teacher: content.teacher ?? "",
            synopsis: content.synopsis,
            thumbnailPath: content.thumbnail,
            snapshotPath: content.snapshot,
            descriptionURL: content.descriptionURL.flatMap { URL(string: $0) },
            naturalSize: content.naturalSize,
            duration: content.duration,
            position: content.position,
            contentType: contentType(from: content.contentType),
            drm: drmStatus(from: content),
            download: downloadStatus(from: content),
            fileSize: max(0, Int64(content.fileSize)),
            downloadedAt: downloadedAt(from: content.downloadedTime),
            contentIndex: Int(content.contentIndex),
            downloadStopSize: max(0, Int64(content.downloadStopSize))
        )
    }

    private static func contentType(from sdkType: KollusContentType) -> ContentType {
        switch sdkType.rawValue {
        case 1:
            return .downloading
        case 2:
            return .sample
        case 3:
            return .hlsStreaming
        case 4:
            return .hlsDownload
        default:
            return .streaming
        }
    }

    private static func drmStatus(from content: KollusContent) -> DRMStatus {
        if content.drmExpired {
            return .expired
        }

        // 제약 없는 항목은 nil — "무제한"과 "소진"을 구분한다.
        let playCountRemaining: Int?
        if content.drmExpireCountMax > 0 {
            playCountRemaining = max(0, Int(content.drmExpireCount))
        } else {
            playCountRemaining = nil
        }

        let playTimeRemaining: TimeInterval?
        if content.drmTotalExpirePlayTime > 0 {
            playTimeRemaining = max(0, content.drmExpirePlayTime)
        } else {
            playTimeRemaining = nil
        }

        let hasAnyConstraint = content.drmExpireDate != nil
            || playCountRemaining != nil
            || playTimeRemaining != nil
        guard hasAnyConstraint else {
            return .unknown
        }

        return .valid(
            expiresAt: content.drmExpireDate,
            playCountRemaining: playCountRemaining,
            playTimeRemaining: playTimeRemaining,
            needsRenewalPrompt: content.drmExpireRefreshPopup
        )
    }

    private static func downloadStatus(from content: KollusContent) -> DownloadStatus {
        if content.downloaded {
            return .completed
        }

        let downloadedBytes = max(0, Int64(content.downloadSize))
        let percent = min(100, max(0, Double(content.downloadProgress)))
        if percent > 0 || downloadedBytes > 0 {
            return .inProgress(percent: percent, downloadedBytes: downloadedBytes)
        }
        return .notDownloaded
    }

    private static func downloadedAt(from downloadedTime: Int32) -> Date? {
        guard downloadedTime > 0 else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(downloadedTime))
    }
}

#endif
