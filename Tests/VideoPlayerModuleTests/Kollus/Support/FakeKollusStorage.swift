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
    var applicationDeviceID: String?
    var serverPort: Int?

    var storageSize: Int64 = 0
    var cacheDataSize: Int64 = 0
    var applicationVersion: String?

    var kollusPath: String?
    var cacheSizeMB: Int?
    var backgroundDownload: Bool = false
    var networkTimeOut: Int?
    var networkRetry: Int?
    var startStorageInvocationCount = 0
    var startStorageError: Error?
    var callOrder: [String] = []

    var loadContentURLResults: [String: Result<String, Error>] = [:]
    var checkContentURLResults: [String: String?] = [:]
    var checkContentURLErrors: [String: Error] = [:]
    var checkContentURLError: Error?
    var startedDownloads: [String] = []
    var canceledDownloads: [String] = []
    var removedContents: [String] = []
    var removeCacheError: Error?
    var updateDRMError: Error?
    var renewAllValues: [Bool] = []
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
        callOrder.append("setCacheSize")
        cacheSizeMB = megabytes
    }

    func setBackgroundDownload(_ enabled: Bool) {
        callOrder.append("setBackgroundDownload")
        backgroundDownload = enabled
    }

    func setNetworkTimeOut(seconds: Int, retry: Int) {
        callOrder.append("setNetworkTimeOut")
        networkTimeOut = seconds
        networkRetry = retry
    }

    func startStorage() throws {
        callOrder.append("startStorage")
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

    func checkContentURL(_ url: String) throws -> String? {
        if let error = checkContentURLErrors[url] {
            throw error
        }
        if let checkContentURLError {
            throw checkContentURLError
        }
        return checkContentURLResults[url] ?? nil
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

    func updateDownloadDRMInfo(renewAll: Bool) throws {
        if let updateDRMError {
            throw updateDRMError
        }
        renewAllValues.append(renewAll)
    }

    func sendStoredLms() {
        sendStoredLmsInvocationCount += 1
    }

    // MARK: - Test driving

    func emitSnapshots(_ snapshots: [KollusContentSnapshot]) {
        self.snapshots = snapshots
        storageDelegate?.storageDidUpdateContents(snapshots, failure: nil)
    }

    func emitDownloadFailure(mediaContentKey: String, error: Error) {
        storageDelegate?.storageDidUpdateContents(
            snapshots,
            failure: .init(mediaContentKey: mediaContentKey, error: error)
        )
    }

    func emitLicenseRenewalProgress(current: Int, total: Int, error: Error? = nil) {
        storageDelegate?.storageDidProgressLicenseRenewal(current: current, total: total, error: error)
    }

    func emitDRMResponse(
        request: [String: Any],
        response: [String: Any],
        error: Error?,
        snapshots: [KollusContentSnapshot]? = nil
    ) {
        if let snapshots {
            self.snapshots = snapshots
        }
        storageDelegate?.storageDidResolveDRM(.init(
            request: request,
            response: response,
            error: error,
            snapshots: snapshots ?? self.snapshots
        ))
    }

    func emitLMSPost(data: String, result: [String: Any]) {
        storageDelegate?.storageDidPostLMS(.init(data: data, result: result))
    }

    func emitStoredLMSComplete(success: Int, failure: Int) {
        storageDelegate?.storageDidCompleteStoredLMS(.init(successCount: success, failureCount: failure))
    }
}

#endif
