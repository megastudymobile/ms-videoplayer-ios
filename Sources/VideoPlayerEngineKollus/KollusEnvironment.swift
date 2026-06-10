//
//  KollusEnvironment.swift
//  VideoPlayerModule
//
//  Created by 모바일개발팀_정준영 on 2026/05/15.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

import Foundation

public struct KollusEnvironment: Sendable {
    public let applicationKey: String
    public let applicationBundleID: String
    public let applicationExpireDate: Date
    public let keychainGroup: String?

    public let storagePath: URL?
    public let cacheSizeMB: Int?
    public let proxyPort: Int?
    public let backgroundDownload: Bool
    public let networkTimeoutSeconds: Int?
    public let networkRetry: Int?

    public let aiPlaybackRateEnabled: Bool
    public let hardwareDecoderPreferred: Bool
    public let customSkinJSON: String?
    public let pauseOnForeground: Bool
    public let audioBackgroundPlayPolicy: Bool

    public let drm: KollusDRMConfiguration

    public let observer: KollusObserver?
    public let diagnostics: KollusDiagnosticsSink?

    public init(
        applicationKey: String,
        applicationBundleID: String,
        applicationExpireDate: Date,
        keychainGroup: String? = nil,
        storagePath: URL? = nil,
        cacheSizeMB: Int? = nil,
        proxyPort: Int? = nil,
        backgroundDownload: Bool = false,
        networkTimeoutSeconds: Int? = nil,
        networkRetry: Int? = nil,
        aiPlaybackRateEnabled: Bool = false,
        hardwareDecoderPreferred: Bool = true,
        customSkinJSON: String? = nil,
        pauseOnForeground: Bool = false,
        audioBackgroundPlayPolicy: Bool = false,
        drm: KollusDRMConfiguration = KollusDRMConfiguration(),
        observer: KollusObserver? = nil,
        diagnostics: KollusDiagnosticsSink? = nil
    ) {
        self.applicationKey = applicationKey
        self.applicationBundleID = applicationBundleID
        self.applicationExpireDate = applicationExpireDate
        self.keychainGroup = keychainGroup
        self.storagePath = storagePath
        self.cacheSizeMB = cacheSizeMB
        self.proxyPort = proxyPort
        self.backgroundDownload = backgroundDownload
        self.networkTimeoutSeconds = networkTimeoutSeconds
        self.networkRetry = networkRetry
        self.aiPlaybackRateEnabled = aiPlaybackRateEnabled
        self.hardwareDecoderPreferred = hardwareDecoderPreferred
        self.customSkinJSON = customSkinJSON
        self.pauseOnForeground = pauseOnForeground
        self.audioBackgroundPlayPolicy = audioBackgroundPlayPolicy
        self.drm = drm
        self.observer = observer
        self.diagnostics = diagnostics
    }

    public func validate(now: Date = Date()) throws {
        guard !applicationKey.isEmpty else {
            throw KollusEnvironmentError.missingApplicationKey
        }
        guard !applicationBundleID.isEmpty else {
            throw KollusEnvironmentError.missingBundleID
        }
        guard applicationExpireDate > now else {
            throw KollusEnvironmentError.expiredApplicationKey(expireDate: applicationExpireDate, now: now)
        }
        if let cacheSizeMB, cacheSizeMB <= 0 {
            throw KollusEnvironmentError.invalidCacheSize(cacheSizeMB)
        }
        if let proxyPort, proxyPort <= 0 {
            throw KollusEnvironmentError.invalidProxyPort(proxyPort)
        }
        if let storagePath {
            var isDirectory: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: storagePath.path, isDirectory: &isDirectory)
            if !exists || !isDirectory.boolValue {
                throw KollusEnvironmentError.invalidStoragePath(storagePath)
            }
        }
    }
}

public enum KollusEnvironmentError: Error, Equatable, Sendable {
    case missingApplicationKey
    case missingBundleID
    case expiredApplicationKey(expireDate: Date, now: Date)
    case invalidCacheSize(Int)
    case invalidProxyPort(Int)
    case invalidStoragePath(URL)
}
