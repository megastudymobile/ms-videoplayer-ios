//
//  KollusContentSnapshot.swift
//  VideoPlayerModule
//
//  Created by 모바일개발팀_정준영 on 2026/05/15.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

import CoreGraphics
import Foundation

#if canImport(KollusSDKBinary)
import KollusSDKBinary
#endif

public struct KollusContentSnapshot: Sendable, Hashable, Identifiable {
    public enum ContentType: Sendable, Hashable {
        case streaming
        case downloading
        case hlsStreaming
        case hlsDownload
        case sample
    }

    public enum DRMStatus: Sendable, Hashable {
        case unknown
        case valid(expiresAt: Date?, playCountRemaining: Int?)
        case expired
    }

    public enum DownloadStatus: Sendable, Hashable {
        case notDownloaded
        case inProgress(percent: Double, downloadedBytes: Int64)
        case completed
    }

    public let id: String
    public let title: String
    public let course: String
    public let teacher: String
    public let synopsis: String?
    public let thumbnailPath: String?
    public let snapshotPath: String?
    public let descriptionURL: URL?
    public let naturalSize: CGSize
    public let duration: TimeInterval
    public let position: TimeInterval
    public let contentType: ContentType
    public let drm: DRMStatus
    public let download: DownloadStatus
    public let fileSize: Int64
    public let downloadedAt: Date?

    public init(
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
        downloadedAt: Date? = nil
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
            downloadedAt: downloadedAt(from: content.downloadedTime)
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
        if content.drmExpireDate != nil {
            let remaining = Int(content.drmExpireCountMax - content.drmExpireCount)
            return .valid(
                expiresAt: content.drmExpireDate,
                playCountRemaining: remaining > 0 ? remaining : nil
            )
        }
        return .unknown
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
