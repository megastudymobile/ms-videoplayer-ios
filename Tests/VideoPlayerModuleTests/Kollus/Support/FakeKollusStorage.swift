//
//  FakeKollusStorage.swift
//  VideoPlayerModuleTests
//
//  Created by 모바일개발팀_정준영 on 2026/05/15.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

#if canImport(UIKit)

import Foundation
@testable import VideoPlayerEngineKollus

@MainActor
final class FakeKollusStorage: KollusStorageProtocol {
    var applicationKey: String?
    var applicationBundleID: String?
    var applicationExpireDate: Date?
    var keychainGroup: String?

    var kollusPath: String?
    var cacheSizeMB: Int?
    var backgroundDownload: Bool = false
    var networkTimeOut: Int?
    var networkRetry: Int?
    var startStorageInvocationCount = 0
    var startStorageError: Error?

    var loadContentURLResults: [String: Result<String, Error>] = [:]
    var checkContentURLResults: [String: String?] = [:]
    var startedDownloads: [String] = []
    var canceledDownloads: [String] = []
    var removedContents: [String] = []
    var removeCacheError: Error?
    var updateDRMError: Error?
    var sendStoredLmsInvocationCount = 0

    private var snapshots: [KollusContentSnapshot] = []
    weak var storageDelegate: KollusStorageEventReceiving?

    var contentSnapshots: [KollusContentSnapshot] {
        snapshots
    }

    func setKollusPath(_ path: String) {
        kollusPath = path
    }

    func setCacheSize(megabytes: Int) {
        cacheSizeMB = megabytes
    }

    func setBackgroundDownload(_ enabled: Bool) {
        backgroundDownload = enabled
    }

    func setNetworkTimeOut(seconds: Int, retry: Int) {
        networkTimeOut = seconds
        networkRetry = retry
    }

    func startStorage() throws {
        startStorageInvocationCount += 1
        if let startStorageError {
            throw startStorageError
        }
    }

    func loadContentURL(_ url: String) async throws -> String {
        switch loadContentURLResults[url] {
        case .success(let mck):
            return mck
        case .failure(let error):
            throw error
        case .none:
            return UUID().uuidString
        }
    }

    func checkContentURL(_ url: String) -> String? {
        checkContentURLResults[url] ?? nil
    }

    func downloadContent(_ mediaContentKey: String) throws {
        startedDownloads.append(mediaContentKey)
    }

    func downloadCancelContent(_ mediaContentKey: String) throws {
        canceledDownloads.append(mediaContentKey)
    }

    func removeContent(_ mediaContentKey: String) throws {
        removedContents.append(mediaContentKey)
    }

    func removeCacheWithError() throws {
        if let removeCacheError {
            throw removeCacheError
        }
    }

    func updateDownloadDRMInfo(includeExpired: Bool) throws {
        if let updateDRMError {
            throw updateDRMError
        }
    }

    func sendStoredLms() {
        sendStoredLmsInvocationCount += 1
    }

    // MARK: - Test driving

    func emitSnapshots(_ snapshots: [KollusContentSnapshot]) {
        self.snapshots = snapshots
        storageDelegate?.storageDidUpdateContents(snapshots)
    }

    func emitDRMResponse(request: [String: Any], response: [String: Any], error: Error?) {
        storageDelegate?.storageDidResolveDRM(.init(request: request, response: response, error: error))
    }

    func emitLMSPost(data: String, result: [String: Any]) {
        storageDelegate?.storageDidPostLMS(.init(data: data, result: result))
    }

    func emitStoredLMSComplete(success: Int, failure: Int) {
        storageDelegate?.storageDidCompleteStoredLMS(.init(successCount: success, failureCount: failure))
    }
}

#endif
