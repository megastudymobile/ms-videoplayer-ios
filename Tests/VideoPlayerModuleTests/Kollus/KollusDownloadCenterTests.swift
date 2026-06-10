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

    @Test("check는 조회 에러를 미다운로드(nil)로 해석")
    func check_returnsNilForUnregisteredURL() async throws {
        let storage = FakeKollusStorage()
        // SDK는 코드 상수를 공개하지 않으므로 코드값과 무관하게 nil이어야 한다.
        storage.checkContentURLErrors["https://x/unregistered"] = NSError(
            domain: "kollus.storage",
            code: 404,
            userInfo: [NSLocalizedDescriptionKey: "content not found"]
        )
        storage.checkContentURLErrors["https://x/opaque-error"] = NSError(
            domain: "kollus.storage",
            code: -1,
            userInfo: nil
        )
        storage.checkContentURLResults["https://x/registered"] = "mck-registered"
        let (center, _) = makeCenter(storage: storage)

        let missing = try await center.check(contentURL: "https://x/unregistered")
        let opaque = try await center.check(contentURL: "https://x/opaque-error")
        let registered = try await center.check(contentURL: "https://x/registered")

        #expect(missing == nil)
        #expect(opaque == nil)
        #expect(registered == "mck-registered")
    }

    // MARK: - download lifecycle

    @Test("startDownload는 정확한 contentID로 storage 호출")
    func startDownload_invokesStorageWithExactContentID() async throws {
        let storage = FakeKollusStorage()
        let (center, _) = makeCenter(storage: storage)

        try await center.startDownload(contentID: "mck-2")

        #expect(storage.startedDownloads == ["mck-2"])
    }

    @Test("cancelDownload는 storage 호출")
    func cancelDownload_invokesStorage() async throws {
        let storage = FakeKollusStorage()
        let (center, _) = makeCenter(storage: storage)

        try await center.cancelDownload(contentID: "mck-3")

        #expect(storage.canceledDownloads == ["mck-3"])
    }

    @Test("remove는 storage 호출")
    func remove_invokesStorage() async throws {
        let storage = FakeKollusStorage()
        let (center, _) = makeCenter(storage: storage)

        try await center.remove(contentID: "mck-4")

        #expect(storage.removedContents == ["mck-4"])
    }

    // MARK: - cache / DRM / LMS

    @Test("clearStreamingCache는 에러를 PlayerError로 분류해 전파")
    func clearStreamingCache_propagatesClassifiedError() async {
        let storage = FakeKollusStorage()
        storage.removeCacheError = NSError(
            domain: "t",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "cache removal failed"]
        )
        let (center, _) = makeCenter(storage: storage)

        await #expect {
            try await center.clearStreamingCache()
        } throws: { error in
            // 분류기 체인 통과 — 미분류 도메인은 .unknown으로 수렴하되 메시지 보존.
            guard case let PlayerError.unknown(message) = error else { return false }
            return message == "cache removal failed"
        }
    }

    @Test("renewLicenses는 scope를 SDK bAll 의미로 전달")
    func renewLicenses_mapsScopeToRenewAllFlag() async throws {
        let storage = FakeKollusStorage()
        let (center, _) = makeCenter(storage: storage)

        try await center.renewLicenses(scope: .all)
        try await center.renewLicenses(scope: .expiredOnly)

        #expect(storage.renewAllValues == [true, false])
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

    @Test("contents 스트림은 storage delegate 콜백 시 중립 모델로 방출")
    func contents_stream_yieldsNeutralModelOnStorageDelegateCallback() async throws {
        let storage = FakeKollusStorage()
        let (center, _) = makeCenter(storage: storage)

        // Trigger ensureStorage so bridge becomes delegate.
        try await center.setCacheSize(megabytes: 64)

        let emitted: [KollusContentSnapshot] = [
            KollusContentSnapshot(id: "a"),
            KollusContentSnapshot(id: "b")
        ]

        let stream = center.contents

        // Emit on next runloop tick to ensure subscriber is awaiting.
        Task { @MainActor in
            storage.emitSnapshots(emitted)
        }

        var iterator = stream.makeAsyncIterator()
        let received = await iterator.next()

        #expect(received?.map(\.id) == ["a", "b"])
    }

    // MARK: - events stream

    @Test("다운로드 실패는 events 스트림으로 분류되어 전파")
    func downloadFailure_isDeliveredOnEventsStream() async throws {
        let storage = FakeKollusStorage()
        let (center, _) = makeCenter(storage: storage)

        try await center.setCacheSize(megabytes: 64)

        let stream = center.events

        Task { @MainActor in
            storage.emitDownloadFailure(
                mediaContentKey: "mck-9",
                error: NSError(
                    domain: "kollus.download",
                    code: 42,
                    userInfo: [NSLocalizedDescriptionKey: "disk write failed"]
                )
            )
        }

        var iterator = stream.makeAsyncIterator()
        let event = await iterator.next()

        guard case .failed(let contentID, let error) = event else {
            Issue.record("failed 이벤트가 아님: \(String(describing: event))")
            return
        }
        #expect(contentID == "mck-9")
        #expect(error.errorDescription == "disk write failed")
    }

    @Test("라이선스 갱신 진행은 events 스트림으로 전파")
    func licenseRenewalProgress_isDeliveredOnEventsStream() async throws {
        let storage = FakeKollusStorage()
        let (center, _) = makeCenter(storage: storage)

        try await center.setCacheSize(megabytes: 64)

        let stream = center.events

        Task { @MainActor in
            storage.emitLicenseRenewalProgress(current: 2, total: 5)
        }

        var iterator = stream.makeAsyncIterator()
        let event = await iterator.next()

        guard case .licenseRenewalProgressed(let current, let total) = event else {
            Issue.record("licenseRenewalProgressed 이벤트가 아님: \(String(describing: event))")
            return
        }
        #expect(current == 2)
        #expect(total == 5)
    }

    @Test("DRM 강제 삭제 응답은 최신 contents를 다시 방출")
    func forcedDRMDeletion_republishesContentsStream() async throws {
        let storage = FakeKollusStorage()
        let (center, _) = makeCenter(storage: storage)

        try await center.setCacheSize(megabytes: 64)

        let stream = center.contents
        Task { @MainActor in
            storage.emitDRMResponse(
                request: ["path": "drm"],
                response: ["kind": 2],
                error: nil,
                snapshots: [KollusContentSnapshot(id: "remaining")]
            )
        }

        var iterator = stream.makeAsyncIterator()
        let received = await iterator.next()

        #expect(received?.map(\.id) == ["remaining"])
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
