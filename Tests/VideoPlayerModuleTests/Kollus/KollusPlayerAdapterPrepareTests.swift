//
//  KollusPlayerAdapterPrepareTests.swift
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

/// Phase 4 T028 — `KollusPlayerAdapter.prepare(source:)`가 `.url` / `.kollus` 양쪽 진입점에서
/// `KollusSessionBootstrapper`를 거치는지, 그리고 storage 미지원 / bootstrap 실패 시
/// 식별 가능한 `PlayerError.engineError`로 surfacing 되는지 검증한다.
///
/// 실제 `KollusPlayerView` 인스턴스 생성과 `.readyToPlay` 도달은 SDK 호출이라
/// **iOS Simulator + xcodebuild 통합 검증**(Phase 8 T065 quickstart)으로 이월된다.
final class KollusPlayerAdapterPrepareTests: XCTestCase {

    private let validExpire = Date().addingTimeInterval(60 * 60 * 24 * 30)

    @MainActor
    private func makeEnvironment() -> KollusEnvironment {
        KollusEnvironment(
            applicationKey: "valid-key",
            applicationBundleID: "com.example.app",
            applicationExpireDate: validExpire
        )
    }

    // MARK: - Bootstrapper error propagation (URL & MCK)

    @MainActor
    func test_prepareWithURL_propagatesBootstrapStartStorageFailure() async {
        let storage = FakeKollusStorage()
        storage.startStorageError = NSError(domain: "kollus.test", code: 7)
        let env = makeEnvironment()
        let bootstrapper = KollusSessionBootstrapper(environment: env) { storage }
        let adapter = KollusPlayerAdapter(bootstrapper: bootstrapper, environment: env)

        let url = URL(string: "https://example.com/sample.mp4")!

        do {
            try await adapter.prepare(source: .url(url))
            XCTFail("Expected throw")
        } catch let PlayerError.engineError(message) {
            XCTAssertTrue(message.contains("startStorage"), "got: \(message)")
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    @MainActor
    func test_prepareWithMCK_propagatesBootstrapStartStorageFailure() async {
        let storage = FakeKollusStorage()
        storage.startStorageError = NSError(domain: "kollus.test", code: 7)
        let env = makeEnvironment()
        let bootstrapper = KollusSessionBootstrapper(environment: env) { storage }
        let adapter = KollusPlayerAdapter(bootstrapper: bootstrapper, environment: env)

        do {
            try await adapter.prepare(source: .kollus(mediaContentKey: "mck-1"))
            XCTFail("Expected throw")
        } catch let PlayerError.engineError(message) {
            XCTAssertTrue(message.contains("startStorage"), "got: \(message)")
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    // MARK: - Storage protocol mismatch (URL & MCK)

    @MainActor
    func test_prepareWithURL_throwsWhenStorageIsNotKollusStorageAdapter() async {
        // FakeKollusStorage는 KollusStorageProtocol 구현이지만 KollusStorageAdapter는 아님 → 어댑터가 명시적 에러로 거부.
        let storage = FakeKollusStorage()
        let env = makeEnvironment()
        let bootstrapper = KollusSessionBootstrapper(environment: env) { storage }
        let adapter = KollusPlayerAdapter(bootstrapper: bootstrapper, environment: env)
        let url = URL(string: "https://example.com/sample.mp4")!

        do {
            try await adapter.prepare(source: .url(url))
            XCTFail("Expected throw")
        } catch let PlayerError.engineError(message) {
            XCTAssertTrue(message.contains("KollusStorageAdapter가 아닌"), "got: \(message)")
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    @MainActor
    func test_prepareWithMCK_throwsWhenStorageIsNotKollusStorageAdapter() async {
        let storage = FakeKollusStorage()
        let env = makeEnvironment()
        let bootstrapper = KollusSessionBootstrapper(environment: env) { storage }
        let adapter = KollusPlayerAdapter(bootstrapper: bootstrapper, environment: env)

        do {
            try await adapter.prepare(source: .kollus(mediaContentKey: "mck-1"))
            XCTFail("Expected throw")
        } catch let PlayerError.engineError(message) {
            XCTAssertTrue(message.contains("KollusStorageAdapter가 아닌"), "got: \(message)")
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    // MARK: - Environment validation propagation

    @MainActor
    func test_prepareWithURL_propagatesEnvironmentValidationError() async {
        let storage = FakeKollusStorage()
        let invalidEnv = KollusEnvironment(
            applicationKey: "",
            applicationBundleID: "com.example.app",
            applicationExpireDate: validExpire
        )
        let bootstrapper = KollusSessionBootstrapper(environment: invalidEnv) { storage }
        let adapter = KollusPlayerAdapter(bootstrapper: bootstrapper, environment: invalidEnv)
        let url = URL(string: "https://example.com/sample.mp4")!

        do {
            try await adapter.prepare(source: .url(url))
            XCTFail("Expected throw")
        } catch let error as KollusEnvironmentError {
            XCTAssertEqual(error, .missingApplicationKey)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    // MARK: - Regression guard: .url no longer hits legacy throw block

    @MainActor
    func test_prepareWithURL_doesNotThrowLegacyURLBlockedMessage() async {
        let storage = FakeKollusStorage()
        storage.startStorageError = NSError(domain: "kollus.test", code: 7)
        let env = makeEnvironment()
        let bootstrapper = KollusSessionBootstrapper(environment: env) { storage }
        let adapter = KollusPlayerAdapter(bootstrapper: bootstrapper, environment: env)
        let url = URL(string: "https://example.com/sample.mp4")!

        do {
            try await adapter.prepare(source: .url(url))
            XCTFail("Expected throw")
        } catch let PlayerError.engineError(message) {
            XCTAssertFalse(
                message.contains("kollus(mediaContentKey:)만 지원"),
                "T027 회귀: legacy URL 차단 메시지가 남아있음 — \(message)"
            )
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }
}

#endif
