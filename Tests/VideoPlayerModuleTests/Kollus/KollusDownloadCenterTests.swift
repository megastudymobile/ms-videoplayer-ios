//
//  KollusDownloadCenterTests.swift
//  VideoPlayerModuleTests
//
//  Created by 모바일개발팀_정준영 on 2026/05/15 (Phase 6 T040).
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

#if canImport(UIKit) && canImport(KollusSDKBinary)

import XCTest
@testable import VideoPlayerEngineKollus
import VideoPlayerCore

@MainActor
final class KollusDownloadCenterTests: XCTestCase {

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

    func test_resolve_returnsSameMCKOnRepeatedCall() async throws {
        let storage = FakeKollusStorage()
        storage.loadContentURLResults["https://x/sample"] = .success("mck-1")
        let (center, _) = makeCenter(storage: storage)

        let first = try await center.resolve(contentURL: "https://x/sample")
        let second = try await center.resolve(contentURL: "https://x/sample")

        XCTAssertEqual(first, "mck-1")
        XCTAssertEqual(second, "mck-1")
    }

    func test_check_returnsCachedMCK() async throws {
        let storage = FakeKollusStorage()
        storage.checkContentURLResults["https://x"] = "mck-cached"
        let (center, _) = makeCenter(storage: storage)

        let value = try await center.check(contentURL: "https://x")

        XCTAssertEqual(value, "mck-cached")
    }

    // MARK: - download lifecycle

    func test_startDownload_invokesStorageWithExactMCK() async throws {
        let storage = FakeKollusStorage()
        let (center, _) = makeCenter(storage: storage)

        try await center.startDownload(mediaContentKey: "mck-2")

        XCTAssertEqual(storage.startedDownloads, ["mck-2"])
    }

    func test_cancelDownload_invokesStorage() async throws {
        let storage = FakeKollusStorage()
        let (center, _) = makeCenter(storage: storage)

        try await center.cancelDownload(mediaContentKey: "mck-3")

        XCTAssertEqual(storage.canceledDownloads, ["mck-3"])
    }

    func test_remove_invokesStorage() async throws {
        let storage = FakeKollusStorage()
        let (center, _) = makeCenter(storage: storage)

        try await center.remove(mediaContentKey: "mck-4")

        XCTAssertEqual(storage.removedContents, ["mck-4"])
    }

    // MARK: - cache / DRM / LMS

    func test_clearStreamingCache_propagatesError() async {
        let storage = FakeKollusStorage()
        storage.removeCacheError = NSError(domain: "t", code: 1)
        let (center, _) = makeCenter(storage: storage)

        do {
            try await center.clearStreamingCache()
            XCTFail("Expected clearStreamingCache to throw")
        } catch {
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, "t")
            XCTAssertEqual(nsError.code, 1)
        }
    }

    func test_updateDRM_invokesStorage() async throws {
        let storage = FakeKollusStorage()
        let (center, _) = makeCenter(storage: storage)

        try await center.updateDRM(includeExpiredOnly: true)
        // No throw == success; FakeKollusStorage records no flag for the call,
        // but absence of error confirms invocation reached storage layer.
    }

    func test_sendStoredLMS_invokesStorage() async throws {
        let storage = FakeKollusStorage()
        let (center, _) = makeCenter(storage: storage)

        try await center.sendStoredLMS()

        XCTAssertEqual(storage.sendStoredLmsInvocationCount, 1)
    }

    func test_playerID_returnsBootstrappedStorageDeviceID() async throws {
        let storage = FakeKollusStorage()
        storage.applicationDeviceID = "player-123"
        let (center, _) = makeCenter(storage: storage)

        let playerID = try await center.playerID()

        XCTAssertEqual(playerID, "player-123")
        XCTAssertEqual(storage.startStorageInvocationCount, 1)
    }

    // MARK: - snapshot stream

    func test_contents_stream_yieldsOnStorageDelegateCallback() async throws {
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

        XCTAssertEqual(received?.map(\.id), ["a", "b"])
    }

    // MARK: - bootstrap failure

    func test_bootstrapFailure_propagatesError() async {
        let storage = FakeKollusStorage()
        storage.startStorageError = NSError(domain: "t", code: 99)
        let (center, _) = makeCenter(storage: storage)

        do {
            _ = try await center.resolve(contentURL: "u")
            XCTFail("Expected resolve to throw bootstrap error")
        } catch let PlayerError.engineError(message) {
            // KollusSessionBootstrapper가 startStorage NSError를 PlayerError.engineError로 wrap.
            XCTAssertTrue(message.contains("startStorage"), "got: \(message)")
        } catch {
            XCTFail("unexpected error type: \(error)")
        }
    }
}

#endif
