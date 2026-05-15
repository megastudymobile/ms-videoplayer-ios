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
import XCTest
@testable import VideoPlayerEngineKollus

final class KollusContentSnapshotMappingTests: XCTestCase {

    func test_snapshotFromKollusContent_mapsOfficialDownloadFields() {
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

        XCTAssertEqual(snapshot.id, "mck-1")
        XCTAssertEqual(snapshot.naturalSize, CGSize(width: 1920, height: 1080))
        XCTAssertEqual(snapshot.duration, 120)
        XCTAssertEqual(snapshot.position, 12)
        XCTAssertEqual(snapshot.contentType, .hlsDownload)
        XCTAssertEqual(snapshot.fileSize, 1_000)
        XCTAssertEqual(snapshot.downloadedAt, downloadedAt)
        XCTAssertEqual(snapshot.download, .inProgress(percent: 42, downloadedBytes: 420))
        XCTAssertEqual(snapshot.drm, .valid(expiresAt: drmExpiresAt, playCountRemaining: 7))
    }

    func test_snapshotFromKollusContent_mapsCompletedDownload() {
        let content = KollusContent()
        content.setValue("mck-2", forKey: "mediaContentKey")
        content.setValue(NSNumber(value: 1), forKey: "contentType")
        content.setValue(NSNumber(value: 1_000), forKey: "fileSize")
        content.setValue(NSNumber(value: 1_000), forKey: "downloadSize")
        content.setValue(NSNumber(value: 100), forKey: "downloadProgress")
        content.setValue(NSNumber(value: true), forKey: "downloaded")

        let snapshot = KollusContentSnapshot.fromSDKContent(content)

        XCTAssertEqual(snapshot.contentType, .downloading)
        XCTAssertEqual(snapshot.fileSize, 1_000)
        XCTAssertEqual(snapshot.download, .completed)
    }
}

#endif
