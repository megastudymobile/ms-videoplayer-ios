//
//  KollusThumbnailSpriteLayoutTests.swift
//  VideoPlayerModuleTests
//
//  Created by JunyoungJung on 2026/06/10.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

#if canImport(UIKit)
import CoreGraphics
import Foundation
import Testing
@testable import VideoPlayerEngineKollus

@Suite("Kollus 스프라이트 썸네일 레이아웃 — 파일명 파싱/인덱스/crop 영역")
struct KollusThumbnailSpriteLayoutTests {

    @Test("표준 파일명 파싱")
    func parsesStandardFileName() throws {
        let layout = try #require(KollusThumbnailSpriteLayout(fileName: "thumbnail.160x90x100.jpg"))
        #expect(layout.tileWidth == 160)
        #expect(layout.tileHeight == 90)
        #expect(layout.tileCount == 100)
    }

    @Test("콘텐츠 이름에 점이 있어도 확장자 직전 토큰만 본다")
    func parsesFileNameContainingDots() throws {
        let layout = try #require(KollusThumbnailSpriteLayout(fileName: "강의.1강.오리엔테이션.320x180x60.png"))
        #expect(layout.tileWidth == 320)
        #expect(layout.tileCount == 60)
    }

    @Test("형식이 아니면 nil", arguments: [
        "lec.jpg",
        "lec.axbxc.jpg",
        "lec.160x90.jpg",
        "lec.0x90x100.jpg",
        "lec.160x90x0.jpg"
    ])
    func rejectsInvalidFileName(_ fileName: String) {
        #expect(KollusThumbnailSpriteLayout(fileName: fileName) == nil)
    }

    @Test("타일 인덱스 — 경계 클램프")
    func tileIndexClampsToBounds() throws {
        let layout = try #require(KollusThumbnailSpriteLayout(fileName: "t.160x90x100.jpg"))
        #expect(layout.tileIndex(at: -5, duration: 100) == 0)
        #expect(layout.tileIndex(at: 0, duration: 100) == 0)
        #expect(layout.tileIndex(at: 50, duration: 100) == 50)
        #expect(layout.tileIndex(at: 100, duration: 100) == 99)
        #expect(layout.tileIndex(at: 999, duration: 100) == 99)
        #expect(layout.tileIndex(at: 10, duration: 0) == 0)
    }

    @Test("crop 영역 — 10열 그리드 wrap")
    func tileRectWrapsByColumns() throws {
        let layout = try #require(KollusThumbnailSpriteLayout(fileName: "t.160x90x100.jpg"))
        #expect(layout.tileRect(at: 0, columns: 10) == CGRect(x: 0, y: 0, width: 160, height: 90))
        #expect(layout.tileRect(at: 9, columns: 10) == CGRect(x: 1440, y: 0, width: 160, height: 90))
        #expect(layout.tileRect(at: 10, columns: 10) == CGRect(x: 0, y: 90, width: 160, height: 90))
        #expect(layout.tileRect(at: 99, columns: 10) == CGRect(x: 1440, y: 810, width: 160, height: 90))
    }

    @Test("columns 0 방어 — 1열로 처리")
    func tileRectGuardsZeroColumns() throws {
        let layout = try #require(KollusThumbnailSpriteLayout(fileName: "t.160x90x4.jpg"))
        #expect(layout.tileRect(at: 2, columns: 0) == CGRect(x: 0, y: 180, width: 160, height: 90))
    }
}
#endif
