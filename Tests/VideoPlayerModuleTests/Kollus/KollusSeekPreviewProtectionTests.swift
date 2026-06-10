//
//  KollusSeekPreviewProtectionTests.swift
//  VideoPlayerModuleTests
//
//  Created by JunyoungJung on 2026/06/10.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

#if canImport(UIKit)
import Foundation
import Testing
@testable import VideoPlayerEngineKollus

@Suite("스프라이트 파일 at-rest 보호 — 백업 제외/보호 속성")
struct KollusSeekPreviewProtectionTests {

    @Test("백업 제외가 적용된다")
    func appliesBackupExclusion() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("sprite-\(UUID().uuidString).160x90x10.jpg")
        try Data([0xFF, 0xD8]).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        KollusSeekPreviewSource.applyAtRestProtection(toPath: url.path)

        let values = try url.resourceValues(forKeys: [.isExcludedFromBackupKey])
        #expect(values.isExcludedFromBackup == true)
        // 보호 클래스(.complete)는 실기기에서만 강제된다 — 실기기 QA 항목으로 검증.
    }

    @Test("없는 경로는 크래시 없이 무시된다")
    func ignoresMissingPath() {
        KollusSeekPreviewSource.applyAtRestProtection(toPath: "/nonexistent/sprite.160x90x10.jpg")
    }
}
#endif
