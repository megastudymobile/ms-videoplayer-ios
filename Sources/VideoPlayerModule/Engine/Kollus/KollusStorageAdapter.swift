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

    // MARK: - Phase 6 surface (T043 implementation)

    func loadContentURL(_ url: String) async throws -> String {
        var nsError: NSError?
        let mck = withUnsafeMutablePointer(to: &nsError) { ptr -> String? in
            storage.loadContentURL(url, error: AutoreleasingUnsafeMutablePointer<NSError?>(ptr))
        }
        if let nsError {
            throw nsError
        }
        guard let mck else {
            throw PlayerError.engineError("loadContentURL이 nil mediaContentKey를 반환했습니다. url=\(url)")
        }
        return mck
    }

    func checkContentURL(_ url: String) -> String? {
        var nsError: NSError?
        return withUnsafeMutablePointer(to: &nsError) { ptr -> String? in
            storage.checkContentURL(url, error: AutoreleasingUnsafeMutablePointer<NSError?>(ptr))
        }
    }

    func downloadContent(_ mediaContentKey: String) throws {
        var nsError: NSError?
        let ok = withUnsafeMutablePointer(to: &nsError) { ptr -> Bool in
            storage.downloadContent(mediaContentKey, error: AutoreleasingUnsafeMutablePointer<NSError?>(ptr))
        }
        if !ok {
            throw nsError ?? PlayerError.engineError("downloadContent 실패: \(mediaContentKey)")
        }
    }

    func downloadCancelContent(_ mediaContentKey: String) throws {
        var nsError: NSError?
        let ok = withUnsafeMutablePointer(to: &nsError) { ptr -> Bool in
            storage.downloadCancelContent(mediaContentKey, error: AutoreleasingUnsafeMutablePointer<NSError?>(ptr))
        }
        if !ok {
            throw nsError ?? PlayerError.engineError("downloadCancelContent 실패: \(mediaContentKey)")
        }
    }

    func removeContent(_ mediaContentKey: String) throws {
        var nsError: NSError?
        let ok = withUnsafeMutablePointer(to: &nsError) { ptr -> Bool in
            storage.removeContent(mediaContentKey, error: AutoreleasingUnsafeMutablePointer<NSError?>(ptr))
        }
        if !ok {
            throw nsError ?? PlayerError.engineError("removeContent 실패: \(mediaContentKey)")
        }
    }

    func removeCacheWithError() throws {
        var nsError: NSError?
        let ok = withUnsafeMutablePointer(to: &nsError) { ptr -> Bool in
            storage.removeCache(withError: AutoreleasingUnsafeMutablePointer<NSError?>(ptr))
        }
        if !ok {
            throw nsError ?? PlayerError.engineError("removeCache 실패")
        }
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
        let drmStatus: KollusContentSnapshot.DRMStatus
        if content.drmExpired {
            drmStatus = .expired
        } else if content.drmExpireDate != nil {
            let remaining = Int(content.drmExpireCountMax - content.drmExpireCount)
            drmStatus = .valid(
                expiresAt: content.drmExpireDate,
                playCountRemaining: remaining > 0 ? remaining : nil
            )
        } else {
            drmStatus = .unknown
        }

        return KollusContentSnapshot(
            id: content.mediaContentKey ?? "",
            title: content.title ?? "",
            course: content.course ?? "",
            teacher: content.teacher ?? "",
            synopsis: content.synopsis,
            thumbnailPath: content.thumbnail,
            snapshotPath: content.snapshot,
            descriptionURL: content.descriptionURL.flatMap { URL(string: $0) },
            naturalSize: content.naturalSize,
            duration: content.duration,
            position: content.position,
            contentType: .streaming,
            drm: drmStatus,
            download: .notDownloaded,
            fileSize: 0,
            downloadedAt: nil
        )
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
