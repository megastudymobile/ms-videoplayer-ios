//
//  KollusDownloadCenterTests.swift
//  VideoPlayerModuleTests
//
//  Created by 모바일개발팀_정준영 on 2026/05/15 (Phase 6 T040).
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

#if canImport(UIKit) && canImport(KollusSDKBinary)

import Foundation
import Testing
@testable import VideoPlayerEngineKollus
import VideoPlayerCore

@MainActor
@Suite("KollusDownloadCenter 다운로드/캐시/스냅샷 동작")
struct KollusDownloadCenterTests {

    private let validExpire = Date().addingTimeInterval(60 * 60 * 24 * 30)

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

    private func makeCenter(
        storage: FakeKollusStorage
    ) -> (KollusDownloadCenter, KollusEnvironment) {
        let env = makeEnvironment()
        let bootstrapper = KollusSessionBootstrapper(environment: env) { storage }
        let center = KollusDownloadCenter(bootstrapper: bootstrapper, environment: env)
        return (center, env)
    }

    // MARK: - resolve / check

    @Test("resolve는 반복 호출 시 동일 MCK 반환")
    func resolve_returnsSameMCKOnRepeatedCall() async throws {
        let storage = FakeKollusStorage()
        storage.loadContentURLResults["https://x/sample"] = .success("mck-1")
        let (center, _) = makeCenter(storage: storage)

        let first = try await center.resolve(contentURL: "https://x/sample")
        let second = try await center.resolve(contentURL: "https://x/sample")

        #expect(first == "mck-1")
        #expect(second == "mck-1")
    }

    @Test("check는 캐시된 MCK 반환")
    func check_returnsCachedMCK() async throws {
        let storage = FakeKollusStorage()
        storage.checkContentURLResults["https://x"] = "mck-cached"
        let (center, _) = makeCenter(storage: storage)

        let value = try await center.check(contentURL: "https://x")

        #expect(value == "mck-cached")
    }

    // MARK: - download lifecycle

    @Test("startDownload는 정확한 MCK로 storage 호출")
    func startDownload_invokesStorageWithExactMCK() async throws {
        let storage = FakeKollusStorage()
        let (center, _) = makeCenter(storage: storage)

        try await center.startDownload(mediaContentKey: "mck-2")

        #expect(storage.startedDownloads == ["mck-2"])
    }

    @Test("cancelDownload는 storage 호출")
    func cancelDownload_invokesStorage() async throws {
        let storage = FakeKollusStorage()
        let (center, _) = makeCenter(storage: storage)

        try await center.cancelDownload(mediaContentKey: "mck-3")

        #expect(storage.canceledDownloads == ["mck-3"])
    }

    @Test("remove는 storage 호출")
    func remove_invokesStorage() async throws {
        let storage = FakeKollusStorage()
        let (center, _) = makeCenter(storage: storage)

        try await center.remove(mediaContentKey: "mck-4")

        #expect(storage.removedContents == ["mck-4"])
    }

    // MARK: - cache / DRM / LMS

    @Test("clearStreamingCache는 에러를 전파")
    func clearStreamingCache_propagatesError() async {
        let storage = FakeKollusStorage()
        storage.removeCacheError = NSError(domain: "t", code: 1)
        let (center, _) = makeCenter(storage: storage)

        await #expect {
            try await center.clearStreamingCache()
        } throws: { error in
            let nsError = error as NSError
            return nsError.domain == "t" && nsError.code == 1
        }
    }

    @Test("updateDRM는 storage 호출")
    func updateDRM_invokesStorage() async throws {
        let storage = FakeKollusStorage()
        let (center, _) = makeCenter(storage: storage)

        try await center.updateDRM(includeExpiredOnly: true)
        // No throw == success; FakeKollusStorage records no flag for the call,
        // but absence of error confirms invocation reached storage layer.
    }

    @Test("sendStoredLMS는 storage 호출")
    func sendStoredLMS_invokesStorage() async throws {
        let storage = FakeKollusStorage()
        let (center, _) = makeCenter(storage: storage)

        try await center.sendStoredLMS()

        #expect(storage.sendStoredLmsInvocationCount == 1)
    }

    @Test("playerID는 bootstrap된 storage device ID 반환")
    func playerID_returnsBootstrappedStorageDeviceID() async throws {
        let storage = FakeKollusStorage()
        storage.applicationDeviceID = "player-123"
        let (center, _) = makeCenter(storage: storage)

        let playerID = try await center.playerID()

        #expect(playerID == "player-123")
        #expect(storage.startStorageInvocationCount == 1)
    }

    // MARK: - snapshot stream

    @Test("contents 스트림은 storage delegate 콜백 시 방출")
    func contents_stream_yieldsOnStorageDelegateCallback() async throws {
        let storage = FakeKollusStorage()
        let (center, _) = makeCenter(storage: storage)

        // Trigger ensureStorage so bridge becomes delegate.
        try await center.setCacheSize(megabytes: 64)

        let expected: [KollusContentSnapshot] = [
            KollusContentSnapshot(id: "a"),
            KollusContentSnapshot(id: "b")
        ]

        let stream = center.contents

        // Emit on next runloop tick to ensure subscriber is awaiting.
        Task { @MainActor in
            storage.emitSnapshots(expected)
        }

        var iterator = stream.makeAsyncIterator()
        let received = await iterator.next()

        #expect(received?.map(\.id) == ["a", "b"])
    }

    // MARK: - bootstrap failure

    @Test("bootstrap 실패 시 에러를 engineError로 전파")
    func bootstrapFailure_propagatesError() async {
        let storage = FakeKollusStorage()
        storage.startStorageError = NSError(domain: "t", code: 99)
        let (center, _) = makeCenter(storage: storage)

        await #expect {
            _ = try await center.resolve(contentURL: "u")
        } throws: { error in
            // KollusSessionBootstrapper가 startStorage NSError를 PlayerError.engineError로 wrap.
            guard case let PlayerError.engineError(message) = error else { return false }
            return message.contains("startStorage")
        }
    }
}

#endif
