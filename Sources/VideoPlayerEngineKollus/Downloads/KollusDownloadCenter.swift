//
//  KollusDownloadCenter.swift
//  VideoPlayerModule
//
//  Created by 모바일개발팀_정준영 on 2026/05/15 (Phase 6 T043).
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

import Foundation
import VideoPlayerCore

/// KollusStorage 위에 다운로드/오프라인 라이프사이클을 actor-based facade로 노출한다.
/// Shell은 `KollusStorage`를 직접 import하지 않고도 모든 다운로드 운영 동작을 수행할 수 있다.
public actor KollusDownloadCenter {
    private let bootstrapper: KollusSessionBootstrapper
    private let environment: KollusEnvironment
    private let snapshotsContinuation: AsyncStream<[KollusContentSnapshot]>.Continuation
    public nonisolated let contents: AsyncStream<[KollusContentSnapshot]>

    private var storageProto: KollusStorageProtocol?
    private var bridge: KollusStorageBridge?

    public init(
        bootstrapper: KollusSessionBootstrapper,
        environment: KollusEnvironment
    ) {
        self.bootstrapper = bootstrapper
        self.environment = environment

        var continuation: AsyncStream<[KollusContentSnapshot]>.Continuation?
        self.contents = AsyncStream<[KollusContentSnapshot]>(bufferingPolicy: .bufferingNewest(8)) {
            continuation = $0
        }
        self.snapshotsContinuation = continuation!
    }

    deinit {
        snapshotsContinuation.finish()
    }

    // MARK: - Resolve / check

    public func resolve(contentURL: String) async throws -> String {
        let storage = try await ensureStorage()
        return try await storage.loadContentURL(contentURL)
    }

    public func check(contentURL: String) async throws -> String? {
        let storage = try await ensureStorage()
        return await storage.checkContentURL(contentURL)
    }

    // MARK: - Download lifecycle

    public func startDownload(mediaContentKey: String) async throws {
        let storage = try await ensureStorage()
        try await storage.downloadContent(mediaContentKey)
    }

    public func cancelDownload(mediaContentKey: String) async throws {
        let storage = try await ensureStorage()
        try await storage.downloadCancelContent(mediaContentKey)
    }

    public func remove(mediaContentKey: String) async throws {
        let storage = try await ensureStorage()
        try await storage.removeContent(mediaContentKey)
    }

    // MARK: - Cache / DRM / LMS

    public func clearStreamingCache() async throws {
        let storage = try await ensureStorage()
        try await storage.removeCacheWithError()
    }

    public func updateDRM(includeExpiredOnly: Bool) async throws {
        let storage = try await ensureStorage()
        try await storage.updateDownloadDRMInfo(includeExpired: includeExpiredOnly)
    }

    public func sendStoredLMS() async throws {
        let storage = try await ensureStorage()
        await storage.sendStoredLms()
    }

    // MARK: - Operational policy

    public func setCacheSize(megabytes: Int) async throws {
        let storage = try await ensureStorage()
        await storage.setCacheSize(megabytes: megabytes)
    }

    public func setBackgroundDownload(enabled: Bool) async throws {
        let storage = try await ensureStorage()
        await storage.setBackgroundDownload(enabled)
    }

    public func setNetworkTimeout(seconds: Int, retry: Int) async throws {
        let storage = try await ensureStorage()
        await storage.setNetworkTimeOut(seconds: seconds, retry: retry)
    }

    public func playerID() async throws -> String? {
        let storage = try await ensureStorage()
        return await storage.applicationDeviceID
    }

    /// 다운로드된 컨텐츠 총 용량(byte). 저장 용량/캐시 화면 표시용.
    public func storageSize() async throws -> Int64 {
        let storage = try await ensureStorage()
        return await storage.storageSize
    }

    /// 스트리밍 재생 시 누적된 캐시 용량(byte).
    public func cacheDataSize() async throws -> Int64 {
        let storage = try await ensureStorage()
        return await storage.cacheDataSize
    }

    /// Kollus SDK 버전 문자열.
    public func playerVersion() async throws -> String? {
        let storage = try await ensureStorage()
        return await storage.applicationVersion
    }

    // MARK: - Snapshot

    public func currentSnapshots() async throws -> [KollusContentSnapshot] {
        let storage = try await ensureStorage()
        return await storage.contentSnapshots
    }

    // MARK: - Internal

    private func ensureStorage() async throws -> KollusStorageProtocol {
        if let storageProto {
            return storageProto
        }
        let resolved = try await bootstrapper.resolveStorage()
        let continuation = snapshotsContinuation
        let observer = environment.observer
        let newBridge = await MainActor.run { () -> KollusStorageBridge in
            let bridge = KollusStorageBridge(
                observer: observer,
                snapshotsContinuation: continuation
            )
            resolved.storageDelegate = bridge
            return bridge
        }
        self.bridge = newBridge
        self.storageProto = resolved
        return resolved
    }
}
