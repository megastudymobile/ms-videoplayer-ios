//
//  KollusDownloadCenter.swift
//  VideoPlayerModule
//
//  Created by 모바일팀_정준영 on 2026/05/15.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import Foundation
import VideoPlayerCore

/// `PlayerDownloadCenter` 계약의 Kollus 구현. host는 계약 타입(`any PlayerDownloadCenter`)만 의존하고,
/// Kollus 전용 운영 API(아래 "Kollus 전용" 섹션)는 조립 지점에서만 접근한다.
public actor KollusDownloadCenter: PlayerDownloadCenter {
    private let bootstrapper: KollusSessionBootstrapper
    private let environment: KollusEnvironment
    private let contentsContinuation: AsyncStream<[DownloadedContent]>.Continuation
    private let eventsContinuation: AsyncStream<DownloadEvent>.Continuation
    private let errorChain = PlayerErrorClassifierChain(classifiers: [KollusErrorClassifier()])

    public nonisolated let contents: AsyncStream<[DownloadedContent]>
    public nonisolated let events: AsyncStream<DownloadEvent>

    private var storageProto: KollusStorageProtocol?
    private var bridge: KollusStorageBridge?

    public init(
        bootstrapper: KollusSessionBootstrapper,
        environment: KollusEnvironment
    ) {
        self.bootstrapper = bootstrapper
        self.environment = environment

        var contentsCont: AsyncStream<[DownloadedContent]>.Continuation?
        self.contents = AsyncStream<[DownloadedContent]>(bufferingPolicy: .bufferingNewest(8)) {
            contentsCont = $0
        }
        self.contentsContinuation = contentsCont!

        var eventsCont: AsyncStream<DownloadEvent>.Continuation?
        // 실패/완료 이벤트는 델타라 유실되면 안 된다 — unbounded.
        self.events = AsyncStream<DownloadEvent>(bufferingPolicy: .unbounded) {
            eventsCont = $0
        }
        self.eventsContinuation = eventsCont!
    }

    deinit {
        contentsContinuation.finish()
        eventsContinuation.finish()
    }

    // MARK: - PlayerDownloadCenter

    public func resolve(contentURL: String) async throws -> String {
        let storage = try await ensureStorage()
        do {
            return try await storage.loadContentURL(contentURL)
        } catch {
            throw errorChain.classify(error, context: .resolve)
        }
    }

    public func check(contentURL: String) async throws -> String? {
        let storage = try await ensureStorage()
        do {
            return try await storage.checkContentURL(contentURL)
        } catch {
            // SDK는 미등록 URL을 에러로 알린다 — 코드 상수가 비공개라 구분할 수 없으므로
            // 가이드 샘플과 동일하게 조회 실패 전체를 "미다운로드"로 해석한다.
            return nil
        }
    }

    public func startDownload(contentID: String) async throws {
        let storage = try await ensureStorage()
        do {
            try await storage.downloadContent(contentID)
        } catch {
            throw errorChain.classify(error, context: .download)
        }
    }

    public func cancelDownload(contentID: String) async throws {
        let storage = try await ensureStorage()
        do {
            try await storage.downloadCancelContent(contentID)
        } catch {
            throw errorChain.classify(error, context: .download)
        }
    }

    public func remove(contentID: String) async throws {
        let storage = try await ensureStorage()
        do {
            try await storage.removeContent(contentID)
        } catch {
            throw errorChain.classify(error, context: .removal)
        }
    }

    public func clearStreamingCache() async throws {
        let storage = try await ensureStorage()
        do {
            try await storage.removeCacheWithError()
        } catch {
            throw errorChain.classify(error, context: .removal)
        }
    }

    public func renewLicenses(scope: LicenseRenewalScope) async throws {
        let storage = try await ensureStorage()
        do {
            try await storage.updateDownloadDRMInfo(renewAll: scope == .all)
        } catch {
            throw errorChain.classify(error, context: .licenseRenewal)
        }
    }

    public func currentContents() async throws -> [DownloadedContent] {
        let storage = try await ensureStorage()
        return await storage.contentSnapshots.map { $0.toDownloadedContent() }
    }

    public func storageMetrics() async throws -> StorageMetrics {
        let storage = try await ensureStorage()
        return await StorageMetrics(
            downloadedBytes: storage.storageSize,
            streamingCacheBytes: storage.cacheDataSize
        )
    }

    // MARK: - Kollus 전용 (계약 밖 — 조립 지점/진단 화면에서만 접근)

    public func sendStoredLMS() async throws {
        let storage = try await ensureStorage()
        await storage.sendStoredLms()
    }

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

    /// Kollus device ID. 진단 화면 표시용.
    public func playerID() async throws -> String? {
        let storage = try await ensureStorage()
        return await storage.applicationDeviceID
    }

    /// Kollus SDK 버전 문자열. 진단 화면 표시용.
    public func playerVersion() async throws -> String? {
        let storage = try await ensureStorage()
        return await storage.applicationVersion
    }

    // MARK: - Internal

    /// 오프라인 재생 사전 검증용 — 어댑터가 prepare 직전에 조회한다.
    func downloadedContent(for contentID: String) async throws -> DownloadedContent? {
        let storage = try await ensureStorage()
        return await storage.contentSnapshots
            .first { $0.id == contentID }?
            .toDownloadedContent()
    }

    private func ensureStorage() async throws -> KollusStorageProtocol {
        if let storageProto {
            return storageProto
        }
        let resolved = try await bootstrapper.resolveStorage()
        let contentsCont = contentsContinuation
        let eventsCont = eventsContinuation
        let observer = environment.observer
        let newBridge = await MainActor.run { () -> KollusStorageBridge in
            let bridge = KollusStorageBridge(
                observer: observer,
                contentsContinuation: contentsCont,
                eventsContinuation: eventsCont
            )
            resolved.storageDelegate = bridge
            return bridge
        }
        self.bridge = newBridge
        self.storageProto = resolved
        return resolved
    }
}
