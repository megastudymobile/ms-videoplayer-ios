//
//  KollusContentSnapshot.swift
//  VideoPlayerModule
//
//  Created by 모바일개발팀_정준영 on 2026/05/15.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

import CoreGraphics
import Foundation

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
