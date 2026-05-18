//
//  KollusStorageAdapter.swift
//  VideoPlayerModule
//
//  Created by 모바일개발팀_정준영 on 2026/05/15.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

#if canImport(KollusSDKBinary)

import Foundation
import KollusSDKBinary
import VideoPlayerCore

@MainActor
final class KollusStorageAdapter: NSObject, KollusStorageProtocol, @preconcurrency KollusStorageDelegate {
    let storage: KollusStorage
    weak var storageDelegate: KollusStorageEventReceiving?

    init(storage: KollusStorage) {
        self.storage = storage
        super.init()
        self.storage.delegate = self
    }

    var applicationKey: String? {
        get { storage.applicationKey }
        set { storage.applicationKey = newValue ?? "" }
    }

    var applicationBundleID: String? {
        get { storage.applicationBundleID }
        set { storage.applicationBundleID = newValue ?? "" }
    }

    var applicationExpireDate: Date? {
        get { storage.applicationExpireDate }
        set { storage.applicationExpireDate = newValue ?? Date.distantFuture }
    }

    var keychainGroup: String? {
        get { storage.keychainGroup }
        set { storage.keychainGroup = newValue ?? "" }
    }

    var applicationDeviceID: String? {
        storage.applicationDeviceID
    }

    var serverPort: Int? {
        get { storage.serverPort }
        set { storage.serverPort = newValue ?? 0 }
    }

    func setKollusPath(_ path: String) {
        _ = storage.setKollusPath(path)
    }

    func setCacheSize(megabytes: Int) {
        storage.setCacheSize(megabytes)
    }

    func setBackgroundDownload(_ enabled: Bool) {
        storage.setBackgroundDownload(enabled)
    }

    func setNetworkTimeOut(seconds: Int, retry: Int) {
        storage.setNetworkTimeOut(seconds, retry: retry)
    }

    func startStorage() throws {
        // KollusSDK `NS_SWIFT_NAME(start())`로 명명 변경됨 — `start()` throws로 import.
        try storage.start()
    }

    // MARK: - Phase 6 surface (T043 implementation)

    func loadContentURL(_ url: String) async throws -> String {
        let mck = try storage.loadContentURL(url)
        return mck
    }

    func checkContentURL(_ url: String) -> String? {
        try? storage.checkContentURL(url)
    }

    func downloadContent(_ mediaContentKey: String) throws {
        try storage.downloadContent(mediaContentKey)
    }

    func downloadCancelContent(_ mediaContentKey: String) throws {
        try storage.downloadCancelContent(mediaContentKey)
    }

    func removeContent(_ mediaContentKey: String) throws {
        try storage.removeContent(mediaContentKey)
    }

    func removeCacheWithError() throws {
        try storage.removeCache()
    }

    func updateDownloadDRMInfo(includeExpired: Bool) throws {
        storage.updateDownloadDRMInfo(includeExpired)
    }

    func sendStoredLms() {
        storage.sendStoredLms()
    }

    var contentSnapshots: [KollusContentSnapshot] {
        guard let raw = storage.contents() as? [KollusContent] else {
            return []
        }
        return raw.map(Self.snapshot(from:))
    }

    private static func snapshot(from content: KollusContent) -> KollusContentSnapshot {
        KollusContentSnapshot.fromSDKContent(content)
    }

    // MARK: - KollusStorageDelegate (forwards to storageDelegate as snapshot refresh)

    func kollusStorage(_ kollusStorage: KollusStorage, downloadContent content: KollusContent, error: Error?) {
        storageDelegate?.storageDidUpdateContents(contentSnapshots)
    }

    func kollusStorage(_ kollusStorage: KollusStorage, request: [AnyHashable: Any], json: [AnyHashable: Any], error: Error?) {
        storageDelegate?.storageDidResolveDRM(.init(
            request: Self.normalize(request),
            response: Self.normalize(json),
            error: error
        ))
    }

    func kollusStorage(_ kollusStorage: KollusStorage, cur: Int32, count: Int32, error: Error?) {
        storageDelegate?.storageDidUpdateContents(contentSnapshots)
    }

    func kollusStorage(_ kollusStorage: KollusStorage, lmsData: String, resultJson: [AnyHashable: Any]) {
        storageDelegate?.storageDidPostLMS(.init(data: lmsData, result: Self.normalize(resultJson)))
    }

    func onSendCompleteStoredLms(_ successCount: Int32, failCount: Int32) {
        storageDelegate?.storageDidCompleteStoredLMS(.init(
            successCount: Int(successCount),
            failureCount: Int(failCount)
        ))
    }

    private static func normalize(_ dict: [AnyHashable: Any]) -> [String: Any] {
        Dictionary(uniqueKeysWithValues: dict.compactMap { key, value -> (String, Any)? in
            guard let stringKey = key as? String else { return nil }
            return (stringKey, value)
        })
    }
}

#endif
