//
//  KollusSessionBootstrapperTests.swift
//  VideoPlayerModuleTests
//
//  Created by 모바일개발팀_정준영 on 2026/05/15.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

#if canImport(UIKit)

import Foundation
import Testing
@testable import VideoPlayerEngineKollus

@Suite("KollusSessionBootstrapper resolveStorage 동작")
struct KollusSessionBootstrapperTests {

    private let validExpire = Date().addingTimeInterval(60 * 60 * 24 * 30)

    @MainActor
    private func makeEnvironment(
        applicationKey: String = "valid-key",
        cacheSizeMB: Int? = 128,
        proxyPort: Int? = 7501,
        backgroundDownload: Bool = true,
        networkTimeoutSeconds: Int? = 5
    ) -> KollusEnvironment {
        KollusEnvironment(
            applicationKey: applicationKey,
            applicationBundleID: "com.example.app",
            applicationExpireDate: validExpire,
            cacheSizeMB: cacheSizeMB,
            proxyPort: proxyPort,
            backgroundDownload: backgroundDownload,
            networkTimeoutSeconds: networkTimeoutSeconds,
            networkRetry: 3
        )
    }

    @MainActor
    @Test("두 번째 호출 시 동일 인스턴스 반환 및 설정 적용")
    func resolveStorage_returnsSameInstanceOnSecondCall() async throws {
        let storage = FakeKollusStorage()
        let env = makeEnvironment()
        let bootstrapper = KollusSessionBootstrapper(environment: env) { storage }

        let first = try await bootstrapper.resolveStorage()
        let second = try await bootstrapper.resolveStorage()

        #expect(first === second)
        #expect(storage.startStorageInvocationCount == 1)
        #expect(storage.applicationKey == "valid-key")
        #expect(storage.applicationBundleID == "com.example.app")
        #expect(storage.cacheSizeMB == 128)
        #expect(storage.serverPort == nil)
        #expect(storage.backgroundDownload)
        #expect(storage.networkTimeOut == 5)
        #expect(storage.networkRetry == 3)
        #expect(
            storage.callOrder ==
            ["startStorage", "setNetworkTimeOut", "setCacheSize", "setBackgroundDownload"]
        )
    }

    @MainActor
    @Test("동시 호출 시 startStorage는 한 번만 실행")
    func resolveStorage_concurrentCallsInvokeStartStorageOnce() async throws {
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
            #expect(result === results[0])
        }
        #expect(storage.startStorageInvocationCount == 1)
    }

    @MainActor
    @Test("첫 실패 후 재시도 가능")
    func resolveStorage_reattemptsAfterFirstFailure() async throws {
        let storage = FakeKollusStorage()
        storage.startStorageError = NSError(domain: "kollus.test", code: 1)

        let env = makeEnvironment()
        let bootstrapper = KollusSessionBootstrapper(environment: env) { storage }

        await #expect {
            _ = try await bootstrapper.resolveStorage()
        } throws: { _ in
            // expected
            true
        }
        #expect(storage.startStorageInvocationCount == 1)

        storage.startStorageError = nil
        let second = try await bootstrapper.resolveStorage()
        #expect(second === storage)
        #expect(storage.startStorageInvocationCount == 2)
    }

    @MainActor
    @Test("환경 검증 에러를 전파")
    func resolveStorage_propagatesEnvironmentValidationError() async {
        let env = makeEnvironment(applicationKey: "")
        let bootstrapper = KollusSessionBootstrapper(environment: env) { FakeKollusStorage() }

        await #expect {
            _ = try await bootstrapper.resolveStorage()
        } throws: { error in
            (error as? KollusEnvironmentError) == .missingApplicationKey
        }
    }
}

#endif
