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
final class KollusStorageAdapter: NSObject, KollusStorageProtocol, KollusStorageDelegate {
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
        var nsError: NSError?
        let ok = withUnsafeMutablePointer(to: &nsError) { ptr -> Bool in
            storage.startStorage(AutoreleasingUnsafeMutablePointer<NSError?>(ptr))
        }
        if !ok {
            throw nsError ?? PlayerError.engineError("KollusStorage startStorage 실패: unknown")
        }
    }

    // MARK: - Phase 6 surface (T043 will implement)

    func loadContentURL(_ url: String) async throws -> String {
        throw PlayerError.engineError("loadContentURL not implemented in Phase 3 (T043, Phase 6)")
    }

    func checkContentURL(_ url: String) -> String? {
        nil
    }

    func downloadContent(_ mediaContentKey: String) throws {
        throw PlayerError.engineError("downloadContent not implemented in Phase 3 (T043, Phase 6)")
    }

    func downloadCancelContent(_ mediaContentKey: String) throws {
        throw PlayerError.engineError("downloadCancelContent not implemented in Phase 3 (T043, Phase 6)")
    }

    func removeContent(_ mediaContentKey: String) throws {
        throw PlayerError.engineError("removeContent not implemented in Phase 3 (T043, Phase 6)")
    }

    func removeCacheWithError() throws {
        throw PlayerError.engineError("removeCacheWithError not implemented in Phase 3 (T043, Phase 6)")
    }

    func updateDownloadDRMInfo(includeExpired: Bool) throws {
        storage.updateDownloadDRMInfo(includeExpired)
    }

    func sendStoredLms() {
        storage.sendStoredLms()
    }

    var contentSnapshots: [KollusContentSnapshot] {
        []
    }

    // MARK: - KollusStorageDelegate (forwards to storageDelegate as snapshot refresh)

    func kollusStorage(_ kollusStorage: KollusStorage, downloadContent content: KollusContent, error: Error?) {
        storageDelegate?.storageDidUpdateContents(contentSnapshots)
    }

    func kollusStorage(_ kollusStorage: KollusStorage, request: [AnyHashable: Any], json: [AnyHashable: Any], error: Error?) {
        // Storage 측 DRM 콜백은 다운로드 플로용. Phase 6에서 처리.
    }

    func kollusStorage(_ kollusStorage: KollusStorage, cur: Int32, count: Int32, error: Error?) {
        storageDelegate?.storageDidUpdateContents(contentSnapshots)
    }

    func kollusStorage(_ kollusStorage: KollusStorage, lmsData: String, resultJson: [AnyHashable: Any]) {
        let normalized = Dictionary(uniqueKeysWithValues: resultJson.compactMap { key, value -> (String, Any)? in
            guard let stringKey = key as? String else { return nil }
            return (stringKey, value)
        })
        storageDelegate?.storageDidPostLMS(data: lmsData, result: normalized)
    }

    func onSendCompleteStoredLms(_ successCount: Int32, failCount: Int32) {
        storageDelegate?.storageDidCompleteStoredLMS(success: Int(successCount), failure: Int(failCount))
    }
}

#endif
