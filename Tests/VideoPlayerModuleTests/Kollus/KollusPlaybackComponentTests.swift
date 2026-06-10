//
//  KollusPlaybackComponentTests.swift
//  VideoPlayerModuleTests
//
//  Created by JunyoungJung on 2026/06/10.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

#if canImport(UIKit)

import Foundation
import Testing
import VideoPlayerCore
@testable import VideoPlayerEngineKollus

@Suite("KollusBookmarkStore 낙관적 캐시")
struct KollusBookmarkStoreTests {

    @Test("낙관적 추가는 정렬 누적된다")
    func optimisticAdd_accumulatesSorted() {
        var store = KollusBookmarkStore()

        store.addOptimistically(position: 20, title: "b")
        let result = store.addOptimistically(position: 10, title: "a")

        #expect(result.map(\.position) == [10, 20])
        #expect(result.map(\.title) == ["a", "b"])
    }

    @Test("tolerance 내 중복 위치는 무시된다")
    func duplicateWithinTolerance_isIgnored() {
        var store = KollusBookmarkStore()

        store.addOptimistically(position: 10.0, title: "a")
        let result = store.addOptimistically(position: 10.3, title: "dup")

        #expect(result.count == 1)
        #expect(result[0].title == "a")
    }

    @Test("낙관적 제거는 tolerance 내 항목을 지운다")
    func optimisticRemove_dropsWithinTolerance() {
        var store = KollusBookmarkStore()
        store.addOptimistically(position: 10, title: "a")
        store.addOptimistically(position: 30, title: "b")

        let result = store.removeOptimistically(position: 10.4)

        #expect(result.map(\.position) == [30])
    }

    @Test("권위 목록 교체는 낙관적 누적을 덮어쓴다")
    func replaceAll_overridesOptimisticState() {
        var store = KollusBookmarkStore()
        store.addOptimistically(position: 10, title: "optimistic")

        store.replaceAll([Bookmark(position: 99, title: "authoritative", kind: .index)])

        #expect(store.bookmarks.map(\.position) == [99])
    }
}

@Suite("KollusNextEpisodeEmitter 발화 판정")
struct KollusNextEpisodeEmitterTests {

    private let url = URL(string: "https://example.com/next")!

    @Test("도달 전에는 nil, 도달 시 1회 발화 후 재발화 없음")
    func firesOnceAtThreshold() {
        var emitter = KollusNextEpisodeEmitter()
        emitter.arm(showAt: 60, callbackURL: url, params: ["k": "v"], showsButton: true)

        #expect(emitter.takeDueInfo(currentTime: 59.9) == nil)

        let info = emitter.takeDueInfo(currentTime: 60.0)
        #expect(info?.showAt == 60)
        #expect(info?.callbackURL == url)
        #expect(info?.callbackParameters == ["k": "v"])
        #expect(info?.showsButton == true)

        #expect(emitter.takeDueInfo(currentTime: 61.0) == nil)
    }

    @Test("showAt 0 이하는 비무장 — hot path 즉시 단락")
    func nonPositiveShowAt_disarms() {
        var emitter = KollusNextEpisodeEmitter()
        emitter.arm(showAt: 0, callbackURL: url, params: [:], showsButton: false)

        #expect(emitter.takeDueInfo(currentTime: 9999) == nil)
    }

    @Test("callbackURL 없으면 발화하지 않는다")
    func missingCallbackURL_neverFires() {
        var emitter = KollusNextEpisodeEmitter()
        emitter.arm(showAt: 10, callbackURL: nil, params: [:], showsButton: true)

        #expect(emitter.takeDueInfo(currentTime: 20) == nil)
    }

    @Test("재-arm은 발화 플래그를 리셋한다")
    func rearm_resetsEmissionFlag() {
        var emitter = KollusNextEpisodeEmitter()
        emitter.arm(showAt: 10, callbackURL: url, params: [:], showsButton: true)
        _ = emitter.takeDueInfo(currentTime: 10)

        emitter.arm(showAt: 10, callbackURL: url, params: [:], showsButton: true)

        #expect(emitter.takeDueInfo(currentTime: 10) != nil)
    }
}

#endif
