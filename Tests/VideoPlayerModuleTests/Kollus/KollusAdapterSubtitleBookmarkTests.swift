//
//  KollusAdapterSubtitleBookmarkTests.swift
//  VideoPlayerModuleTests
//
//  Created by 모바일개발팀_정준영 on 2026/05/15.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

#if canImport(UIKit) && canImport(KollusSDKBinary)

import Foundation
import Testing
import VideoPlayerCore
@testable import VideoPlayerEngineKollus

/// Phase 5 T030 — `KollusPlayerAdapter`가 자막/북마크 명령을 어떻게 surfacing 하는지 검증.
///
/// 검증 범위:
/// - `setSubtitleVisible(_:)` / `setCaptionFontSize(_:)` → `.policyDowngraded(.custom(...))` 이벤트.
/// - `setCaptionFontSize(0)` / 음수 → `PlayerError.engineError`.
/// - playerView가 준비되지 않은 상태에서 `addBookmark` / `removeBookmark` / `selectSubtitleFile` →
///   `PlayerError.engineError("Kollus playerView가 준비되지 않았습니다.")`.
/// - `currentBookmarks()`는 playerView 미준비 시 빈 배열.
///
/// 실제 SDK 호출이 일어나는 경로(`prepare(source:)` 이후)는 Phase 8 시뮬레이터 통합 테스트로 이월.
@Suite("KollusPlayerAdapter 자막/북마크 명령 surfacing")
struct KollusAdapterSubtitleBookmarkTests {

    private let validExpire = Date().addingTimeInterval(60 * 60 * 24 * 30)

    @MainActor
    private func makeAdapter() -> KollusPlayerAdapter {
        let env = KollusEnvironment(
            applicationKey: "k",
            applicationBundleID: "b",
            applicationExpireDate: validExpire
        )
        let storage = FakeKollusStorage()
        let bootstrapper = KollusSessionBootstrapper(environment: env) { storage }
        return KollusPlayerAdapter(bootstrapper: bootstrapper, environment: env)
    }

    /// adapter.outputStream에서 첫 번째 PlayerEvent를 (timeout 안에) 수신한다.
    private func awaitFirstEvent(
        from adapter: KollusPlayerAdapter,
        timeout: TimeInterval = 1.0,
        trigger: @escaping @Sendable () async throws -> Void
    ) async throws -> PlayerEvent? {
        let stream = await adapter.outputStream

        return try await withThrowingTaskGroup(of: PlayerEvent?.self) { group in
            group.addTask {
                for await output in stream {
                    if case .event(let event) = output {
                        return event
                    }
                }
                return nil
            }
            group.addTask {
                // 짧은 지연 후 trigger를 호출해 collector가 먼저 구독되도록 한다.
                try await Task.sleep(nanoseconds: 50_000_000)
                try await trigger()
                // collector가 영원히 매달리지 않도록 timeout 후 nil 반환.
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                return nil
            }

            let first = try await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    // MARK: - setCaptionFontSize validation

    @Test("setCaptionFontSize 0/음수는 engineError throw")
    func setCaptionFontSize_zeroOrNegative_throws() async {
        let adapter = await MainActor.run { self.makeAdapter() }

        await #expect {
            try await adapter.setCaptionFontSize(0)
        } throws: { error in
            guard case let PlayerError.engineError(message) = error else { return false }
            return message.contains("size=0")
        }

        await #expect {
            try await adapter.setCaptionFontSize(-5)
        } throws: { error in
            guard case let PlayerError.engineError(message) = error else { return false }
            return message.contains("size=-5")
        }
    }

    // MARK: - policyDowngraded surfacing

    @Test("setSubtitleVisible는 policyDowngraded 이벤트 방출")
    func setSubtitleVisible_emitsPolicyDowngraded() async throws {
        let adapter = await MainActor.run { self.makeAdapter() }

        let event = try await awaitFirstEvent(from: adapter) {
            try await adapter.setSubtitleVisible(false)
        }

        guard let event else {
            Issue.record("policyDowngraded 이벤트가 timeout 내 수신되지 않음")
            return
        }
        guard case .policyDowngraded(let reason) = event,
              case .custom(let message) = reason else {
            Issue.record("expected .policyDowngraded(.custom), got: \(event)")
            return
        }
        #expect(message.contains("자막 가시성"), "got: \(message)")
        #expect(message.contains("isVisible=false"), "got: \(message)")
    }

    @Test("setCaptionFontSize 양수는 policyDowngraded 이벤트 방출")
    func setCaptionFontSize_positive_emitsPolicyDowngraded() async throws {
        let adapter = await MainActor.run { self.makeAdapter() }

        let event = try await awaitFirstEvent(from: adapter) {
            try await adapter.setCaptionFontSize(20)
        }

        guard let event else {
            Issue.record("policyDowngraded 이벤트가 timeout 내 수신되지 않음")
            return
        }
        guard case .policyDowngraded(let reason) = event,
              case .custom(let message) = reason else {
            Issue.record("expected .policyDowngraded(.custom), got: \(event)")
            return
        }
        #expect(message.contains("폰트 크기"), "got: \(message)")
        #expect(message.contains("20pt"), "got: \(message)")
    }

    // MARK: - playerView nil guards

    @Test("addBookmark는 playerView 미준비 시 engineError throw")
    func addBookmarkWithTitle_throwsWhenPlayerViewMissing() async {
        let adapter = await MainActor.run { self.makeAdapter() }

        await #expect {
            try await adapter.addBookmark(at: 10, title: "chapter")
        } throws: { error in
            guard case let PlayerError.engineError(message) = error else { return false }
            return message.contains("playerView가 준비되지 않았습니다")
        }
    }

    @Test("removeBookmark는 playerView 미준비 시 engineError throw")
    func removeBookmark_throwsWhenPlayerViewMissing() async {
        let adapter = await MainActor.run { self.makeAdapter() }

        await #expect {
            try await adapter.removeBookmark(at: 10)
        } throws: { error in
            guard case let PlayerError.engineError(message) = error else { return false }
            return message.contains("playerView가 준비되지 않았습니다")
        }
    }

    @Test("selectSubtitleFile은 playerView 미준비 시 engineError throw")
    func selectSubtitleFile_throwsWhenPlayerViewMissing() async {
        let adapter = await MainActor.run { self.makeAdapter() }

        await #expect {
            try await adapter.selectSubtitleFile(URL(string: "file:///tmp/a.srt"))
        } throws: { error in
            guard case let PlayerError.engineError(message) = error else { return false }
            return message.contains("playerView가 준비되지 않았습니다")
        }
    }

    @Test("currentBookmarks는 playerView 미준비 시 빈 배열")
    func currentBookmarks_emptyWhenPlayerViewMissing() async {
        let adapter = await MainActor.run { self.makeAdapter() }

        let bookmarks = await adapter.currentBookmarks()
        #expect(bookmarks.isEmpty, "playerView 미준비 시 currentBookmarks()는 [] 여야 한다")
    }
}

#endif
