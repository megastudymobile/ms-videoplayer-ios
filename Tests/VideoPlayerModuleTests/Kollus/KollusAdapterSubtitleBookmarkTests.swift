//
//  KollusAdapterSubtitleBookmarkTests.swift
//  VideoPlayerModuleTests
//
//  Created by 모바일개발팀_정준영 on 2026/05/15.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

#if canImport(UIKit) && canImport(KollusSDKBinary)

import Foundation
import XCTest
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
final class KollusAdapterSubtitleBookmarkTests: XCTestCase {

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

    /// adapter.eventStream에서 첫 번째 PlayerEvent를 (timeout 안에) 수신한다.
    private func awaitFirstEvent(
        from adapter: KollusPlayerAdapter,
        timeout: TimeInterval = 1.0,
        trigger: @escaping @Sendable () async throws -> Void
    ) async throws -> PlayerEvent? {
        let stream = await adapter.eventStream

        return try await withThrowingTaskGroup(of: PlayerEvent?.self) { group in
            group.addTask {
                for await event in stream {
                    return event
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

    func test_setCaptionFontSize_zeroOrNegative_throws() async {
        let adapter = await MainActor.run { self.makeAdapter() }

        do {
            try await adapter.setCaptionFontSize(0)
            XCTFail("Expected engineError for fontSize=0")
        } catch let PlayerError.engineError(message) {
            XCTAssertTrue(message.contains("size=0"), "got: \(message)")
        } catch {
            XCTFail("unexpected error: \(error)")
        }

        do {
            try await adapter.setCaptionFontSize(-5)
            XCTFail("Expected engineError for negative fontSize")
        } catch let PlayerError.engineError(message) {
            XCTAssertTrue(message.contains("size=-5"), "got: \(message)")
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    // MARK: - policyDowngraded surfacing

    func test_setSubtitleVisible_emitsPolicyDowngraded() async throws {
        let adapter = await MainActor.run { self.makeAdapter() }

        let event = try await awaitFirstEvent(from: adapter) {
            try await adapter.setSubtitleVisible(false)
        }

        guard let event else {
            XCTFail("policyDowngraded 이벤트가 timeout 내 수신되지 않음")
            return
        }
        guard case .policyDowngraded(let reason) = event,
              case .custom(let message) = reason else {
            XCTFail("expected .policyDowngraded(.custom), got: \(event)")
            return
        }
        XCTAssertTrue(message.contains("자막 가시성"), "got: \(message)")
        XCTAssertTrue(message.contains("isVisible=false"), "got: \(message)")
    }

    func test_setCaptionFontSize_positive_emitsPolicyDowngraded() async throws {
        let adapter = await MainActor.run { self.makeAdapter() }

        let event = try await awaitFirstEvent(from: adapter) {
            try await adapter.setCaptionFontSize(20)
        }

        guard let event else {
            XCTFail("policyDowngraded 이벤트가 timeout 내 수신되지 않음")
            return
        }
        guard case .policyDowngraded(let reason) = event,
              case .custom(let message) = reason else {
            XCTFail("expected .policyDowngraded(.custom), got: \(event)")
            return
        }
        XCTAssertTrue(message.contains("폰트 크기"), "got: \(message)")
        XCTAssertTrue(message.contains("20pt"), "got: \(message)")
    }

    // MARK: - playerView nil guards

    func test_addBookmarkWithTitle_throwsWhenPlayerViewMissing() async {
        let adapter = await MainActor.run { self.makeAdapter() }

        do {
            try await adapter.addBookmark(at: 10, title: "chapter")
            XCTFail("Expected engineError when playerView is missing")
        } catch let PlayerError.engineError(message) {
            XCTAssertTrue(message.contains("playerView가 준비되지 않았습니다"), "got: \(message)")
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func test_removeBookmark_throwsWhenPlayerViewMissing() async {
        let adapter = await MainActor.run { self.makeAdapter() }

        do {
            try await adapter.removeBookmark(at: 10)
            XCTFail("Expected engineError when playerView is missing")
        } catch let PlayerError.engineError(message) {
            XCTAssertTrue(message.contains("playerView가 준비되지 않았습니다"), "got: \(message)")
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func test_selectSubtitleFile_throwsWhenPlayerViewMissing() async {
        let adapter = await MainActor.run { self.makeAdapter() }

        do {
            try await adapter.selectSubtitleFile(URL(string: "file:///tmp/a.srt"))
            XCTFail("Expected engineError when playerView is missing")
        } catch let PlayerError.engineError(message) {
            XCTAssertTrue(message.contains("playerView가 준비되지 않았습니다"), "got: \(message)")
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func test_currentBookmarks_emptyWhenPlayerViewMissing() async {
        let adapter = await MainActor.run { self.makeAdapter() }

        let bookmarks = await adapter.currentBookmarks()
        XCTAssertTrue(bookmarks.isEmpty, "playerView 미준비 시 currentBookmarks()는 [] 여야 한다")
    }
}

#endif
