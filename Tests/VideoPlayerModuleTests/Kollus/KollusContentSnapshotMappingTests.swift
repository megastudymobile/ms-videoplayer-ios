//
//  KollusContentSnapshotMappingTests.swift
//  VideoPlayerModuleTests
//
//  Created by 모바일개발팀_정준영 on 2026/05/15.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

#if canImport(UIKit) && canImport(KollusSDKBinary)

import CoreGraphics
import Foundation
import KollusSDKBinary
import Testing
import VideoPlayerCore
@testable import VideoPlayerEngineKollus

@Suite("KollusContentSnapshot SDK 콘텐츠 매핑")
struct KollusContentSnapshotMappingTests {

    @Test("공식 다운로드 필드를 snapshot으로 매핑")
    func snapshotFromKollusContent_mapsOfficialDownloadFields() {
        let downloadedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let drmExpiresAt = Date(timeIntervalSince1970: 1_800_000_000)
        let content = KollusContent()
        content.setValue("mck-1", forKey: "mediaContentKey")
        content.setValue("Title", forKey: "title")
        content.setValue("Course", forKey: "course")
        content.setValue("Teacher", forKey: "teacher")
        content.setValue(NSValue(cgSize: CGSize(width: 1920, height: 1080)), forKey: "naturalSize")
        content.setValue(NSNumber(value: 120), forKey: "duration")
        content.setValue(NSNumber(value: 12), forKey: "position")
        content.setValue(NSNumber(value: 4), forKey: "contentType")
        content.setValue(drmExpiresAt, forKey: "DRMExpireDate")
        content.setValue(NSNumber(value: 10), forKey: "DRMExpireCountMax")
        content.setValue(NSNumber(value: 3), forKey: "DRMExpireCount")
        content.setValue(NSNumber(value: false), forKey: "DRMExpired")
        content.setValue(NSNumber(value: 1_000), forKey: "fileSize")
        content.setValue(NSNumber(value: 420), forKey: "downloadSize")
        content.setValue(NSNumber(value: 42), forKey: "downloadProgress")
        content.setValue(NSNumber(value: false), forKey: "downloaded")
        content.setValue(NSNumber(value: Int32(downloadedAt.timeIntervalSince1970)), forKey: "downloadedTime")

        let snapshot = KollusContentSnapshot.fromSDKContent(content)

        #expect(snapshot.id == "mck-1")
        #expect(snapshot.naturalSize == CGSize(width: 1920, height: 1080))
        #expect(snapshot.duration == 120)
        #expect(snapshot.position == 12)
        #expect(snapshot.contentType == .hlsDownload)
        #expect(snapshot.fileSize == 1_000)
        #expect(snapshot.downloadedAt == downloadedAt)
        #expect(snapshot.download == .inProgress(percent: 42, downloadedBytes: 420))
        #expect(snapshot.drm == .valid(
            expiresAt: drmExpiresAt,
            playCountRemaining: 3,
            playTimeRemaining: nil,
            needsRenewalPrompt: false
        ))
    }

    @Test("DRM 잔여 재생 횟수는 drmExpireCount를 그대로 사용")
    func drmPlayCountRemaining_usesRemainingCount() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        let fresh = downloadedContent(drmExpireCountMax: 10, drmExpireCount: 10)
        let partial = downloadedContent(drmExpireCountMax: 10, drmExpireCount: 3)
        let exhausted = downloadedContent(drmExpireCountMax: 10, drmExpireCount: 0)

        #expect(playCountRemaining(of: fresh) == 10)
        #expect(playCountRemaining(of: partial) == 3)
        #expect(playCountRemaining(of: exhausted) == 0)
        #expect(fresh.validateOfflinePlayability(now: now) == nil)
        #expect(partial.validateOfflinePlayability(now: now) == nil)

        guard case .licenseExpired? = exhausted.validateOfflinePlayability(now: now) else {
            Issue.record("남은 횟수 0은 licenseExpired여야 함")
            return
        }
    }

    @Test("완료된 다운로드를 snapshot으로 매핑")
    func snapshotFromKollusContent_mapsCompletedDownload() {
        let content = KollusContent()
        content.setValue("mck-2", forKey: "mediaContentKey")
        content.setValue(NSNumber(value: 1), forKey: "contentType")
        content.setValue(NSNumber(value: 1_000), forKey: "fileSize")
        content.setValue(NSNumber(value: 1_000), forKey: "downloadSize")
        content.setValue(NSNumber(value: 100), forKey: "downloadProgress")
        content.setValue(NSNumber(value: true), forKey: "downloaded")

        let snapshot = KollusContentSnapshot.fromSDKContent(content)

        #expect(snapshot.contentType == .downloading)
        #expect(snapshot.fileSize == 1_000)
        #expect(snapshot.download == .completed)
    }

    private func downloadedContent(
        drmExpireCountMax: Int,
        drmExpireCount: Int
    ) -> DownloadedContent {
        let content = KollusContent()
        content.setValue("mck-count-\(drmExpireCount)", forKey: "mediaContentKey")
        content.setValue(NSNumber(value: true), forKey: "downloaded")
        content.setValue(NSNumber(value: false), forKey: "DRMExpired")
        content.setValue(Date(timeIntervalSince1970: 1_800_000_000), forKey: "DRMExpireDate")
        content.setValue(NSNumber(value: drmExpireCountMax), forKey: "DRMExpireCountMax")
        content.setValue(NSNumber(value: drmExpireCount), forKey: "DRMExpireCount")

        return KollusContentSnapshot.fromSDKContent(content).toDownloadedContent()
    }

    private func playCountRemaining(of content: DownloadedContent) -> Int? {
        guard case .valid(let constraints) = content.license else {
            return nil
        }
        return constraints.playCountRemaining
    }
}

#endif
