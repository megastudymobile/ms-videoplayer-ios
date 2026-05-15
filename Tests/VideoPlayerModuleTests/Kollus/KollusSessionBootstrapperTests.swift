//
//  KollusSessionBootstrapperTests.swift
//  VideoPlayerModuleTests
//
//  Created by 모바일개발팀_정준영 on 2026/05/15.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

#if canImport(UIKit)

import XCTest
@testable import VideoPlayerEngineKollus

final class KollusSessionBootstrapperTests: XCTestCase {

    private let validExpire = Date().addingTimeInterval(60 * 60 * 24 * 30)

    @MainActor
    private func makeEnvironment(
        applicationKey: String = "valid-key",
        cacheSizeMB: Int? = 128,
        backgroundDownload: Bool = true,
        networkTimeoutSeconds: Int? = 5
    ) -> KollusEnvironment {
        KollusEnvironment(
            applicationKey: applicationKey,
            applicationBundleID: "com.example.app",
            applicationExpireDate: validExpire,
            cacheSizeMB: cacheSizeMB,
            backgroundDownload: backgroundDownload,
            networkTimeoutSeconds: networkTimeoutSeconds,
            networkRetry: 3
        )
    }

    @MainActor
    func test_resolveStorage_returnsSameInstanceOnSecondCall() async throws {
        let storage = FakeKollusStorage()
        let env = makeEnvironment()
        let bootstrapper = KollusSessionBootstrapper(environment: env) { storage }

        let first = try await bootstrapper.resolveStorage()
        let second = try await bootstrapper.resolveStorage()

        XCTAssertTrue(first === second)
        XCTAssertEqual(storage.startStorageInvocationCount, 1)
        XCTAssertEqual(storage.applicationKey, "valid-key")
        XCTAssertEqual(storage.applicationBundleID, "com.example.app")
        XCTAssertEqual(storage.cacheSizeMB, 128)
        XCTAssertTrue(storage.backgroundDownload)
        XCTAssertEqual(storage.networkTimeOut, 5)
        XCTAssertEqual(storage.networkRetry, 3)
    }

    @MainActor
    func test_resolveStorage_concurrentCallsInvokeStartStorageOnce() async throws {
        let storage = FakeKollusStorage()
        let env = makeEnvironment()
        let bootstrapper = KollusSessionBootstrapper(environment: env) { storage }

        async let r1 = bootstrapper.resolveStorage()
        async let r2 = bootstrapper.resolveStorage()
        async let r3 = bootstrapper.resolveStorage()
        async let r4 = bootstrapper.resolveStorage()
        async let r5 = bootstrapper.resolveStorage()

        let results = try await [r1, r2, r3, r4, r5]
        for result in results {
            XCTAssertTrue(result === results[0])
        }
        XCTAssertEqual(storage.startStorageInvocationCount, 1)
    }

    @MainActor
    func test_resolveStorage_reattemptsAfterFirstFailure() async throws {
        let storage = FakeKollusStorage()
        storage.startStorageError = NSError(domain: "kollus.test", code: 1)

        let env = makeEnvironment()
        let bootstrapper = KollusSessionBootstrapper(environment: env) { storage }

        do {
            _ = try await bootstrapper.resolveStorage()
            XCTFail("Expected first resolveStorage to throw")
        } catch {
            // expected
        }
        XCTAssertEqual(storage.startStorageInvocationCount, 1)

        storage.startStorageError = nil
        let second = try await bootstrapper.resolveStorage()
        XCTAssertTrue(second === storage)
        XCTAssertEqual(storage.startStorageInvocationCount, 2)
    }

    @MainActor
    func test_resolveStorage_propagatesEnvironmentValidationError() async {
        let env = makeEnvironment(applicationKey: "")
        let bootstrapper = KollusSessionBootstrapper(environment: env) { FakeKollusStorage() }

        do {
            _ = try await bootstrapper.resolveStorage()
            XCTFail("Expected validation throw")
        } catch let error as KollusEnvironmentError {
            XCTAssertEqual(error, .missingApplicationKey)
        } catch {
            XCTFail("unexpected error type: \(error)")
        }
    }
}

#endif
