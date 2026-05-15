//
//  KollusSessionBootstrapper.swift
//  VideoPlayerModule
//
//  Created by 모바일개발팀_정준영 on 2026/05/15.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

import Foundation
import VideoPlayerCore

#if canImport(KollusSDKBinary)
import KollusSDKBinary
#endif

actor KollusSessionBootstrapper {
    typealias StorageFactory = @Sendable @MainActor () -> KollusStorageProtocol

    private let environment: KollusEnvironment
    private let storageFactory: StorageFactory
    private var cachedStorage: KollusStorageProtocol?
    private var inFlightTask: Task<KollusStorageProtocol, Error>?

    init(environment: KollusEnvironment) {
        self.environment = environment
        self.storageFactory = Self.defaultStorageFactory
    }

    init(
        environment: KollusEnvironment,
        storageFactory: @escaping StorageFactory
    ) {
        self.environment = environment
        self.storageFactory = storageFactory
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
        storage.keychainGroup = environment.keychainGroup

        if let size = environment.cacheSizeMB {
            storage.setCacheSize(megabytes: size)
        }

        storage.setBackgroundDownload(environment.backgroundDownload)

        if let seconds = environment.networkTimeoutSeconds {
            storage.setNetworkTimeOut(seconds: seconds, retry: environment.networkRetry ?? 0)
        }

        do {
            try storage.startStorage()
        } catch {
            throw PlayerError.engineError("KollusStorage startStorage 실패: \(error.localizedDescription)")
        }

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
