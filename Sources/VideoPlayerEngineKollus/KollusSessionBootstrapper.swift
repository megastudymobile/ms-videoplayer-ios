//
//  KollusSessionBootstrapper.swift
//  VideoPlayerModule
//
//  Created by 모바일팀_정준영 on 2026/05/15.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import Foundation
import VideoPlayerCore

#if canImport(KollusSDKBinary)
import KollusSDKBinary
#endif

public actor KollusSessionBootstrapper {
    typealias StorageFactory = @Sendable @MainActor () -> KollusStorageProtocol

    private let environment: KollusEnvironment
    private let storageFactory: StorageFactory
    private var cachedStorage: KollusStorageProtocol?
    private var inFlightTask: Task<KollusStorageProtocol, Error>?

    public init(environment: KollusEnvironment) {
        self.environment = environment
        self.storageFactory = { Self.defaultStorageFactory() }
    }

    init(
        environment: KollusEnvironment,
        storageFactory: @escaping StorageFactory
    ) {
        self.environment = environment
        self.storageFactory = storageFactory
    }

    /// 캐시된 storage를 폐기해 다음 `resolveStorage()`가 재부트스트랩(재인증)하도록 한다.
    /// `applicationExpireDate` 만료/세션 손상/`removeCache` 후 강제 갱신 경로가 필요할 때 호출.
    /// 진행 중인 부트스트랩(`inFlightTask`)도 취소해 stale 결과가 캐시되지 않게 한다.
    /// vendor `KollusStorage`는 명시적 stop API가 없어 실제 정리는 ARC dealloc에 의존한다(참조 해제로 시점 앞당김).
    public func invalidate() {
        inFlightTask?.cancel()
        inFlightTask = nil
        cachedStorage = nil
    }

    func resolveStorage() async throws -> KollusStorageProtocol {
        if let cached = cachedStorage {
            return cached
        }

        if let task = inFlightTask {
            return try await task.value
        }

        let environment = self.environment
        let storageFactory = self.storageFactory

        let task = Task<KollusStorageProtocol, Error> {
            try await Self.bootstrap(environment: environment, storageFactory: storageFactory)
        }
        inFlightTask = task

        do {
            let storage = try await task.value
            cachedStorage = storage
            inFlightTask = nil
            return storage
        } catch {
            inFlightTask = nil
            throw error
        }
    }

    @MainActor
    private static func bootstrap(
        environment: KollusEnvironment,
        storageFactory: StorageFactory
    ) async throws -> KollusStorageProtocol {
        try environment.validate()

        let storage = storageFactory()

        if let path = environment.storagePath?.path {
            storage.setKollusPath(path)
        }

        storage.applicationKey = environment.applicationKey
        storage.applicationBundleID = environment.applicationBundleID
        storage.applicationExpireDate = environment.applicationExpireDate
        if let keychainGroup = environment.keychainGroup, keychainGroup.isEmpty == false {
            storage.keychainGroup = keychainGroup
        }

        do {
            try storage.startStorage()
        } catch {
            throw PlayerError.engineError("KollusStorage startStorage 실패: \(error.localizedDescription)")
        }

        if let seconds = environment.networkTimeoutSeconds {
            storage.setNetworkTimeOut(seconds: seconds, retry: environment.networkRetry ?? 0)
        }

        if let size = environment.cacheSizeMB {
            storage.setCacheSize(megabytes: size)
        }

        storage.setBackgroundDownload(environment.backgroundDownload)

        return storage
    }

    @MainActor
    private static func defaultStorageFactory() -> KollusStorageProtocol {
        #if canImport(KollusSDKBinary)
        return KollusStorageAdapter(storage: KollusStorage())
        #else
        preconditionFailure("KollusSDKBinary not available on this platform")
        #endif
    }
}
