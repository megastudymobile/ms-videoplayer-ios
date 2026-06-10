//
//  KollusStorageProtocol.swift
//  VideoPlayerModule
//
//  Created by 모바일개발팀_정준영 on 2026/05/15.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

import CoreGraphics
import Foundation

struct KollusStorageDRMResolution {
    let request: [String: Any]
    let response: [String: Any]
    let error: Error?
}

struct KollusStorageLMSPost {
    let data: String
    let result: [String: Any]
}

struct KollusStoredLMSCompletion {
    let successCount: Int
    let failureCount: Int
}

@MainActor
protocol KollusStorageProtocol: AnyObject {
    var applicationKey: String? { get set }
    var applicationBundleID: String? { get set }
    var applicationExpireDate: Date? { get set }
    var keychainGroup: String? { get set }
    var applicationDeviceID: String? { get }
    var serverPort: Int? { get set }

    /// 다운로드된 컨텐츠 총 용량(byte). 저장 용량/캐시 화면 표시용.
    var storageSize: Int64 { get }
    /// 스트리밍 재생 시 누적된 캐시 용량(byte).
    var cacheDataSize: Int64 { get }
    /// Kollus SDK 버전 문자열.
    var applicationVersion: String? { get }

    func setKollusPath(_ path: String)
    func setCacheSize(megabytes: Int)
    func setBackgroundDownload(_ enabled: Bool)
    func setNetworkTimeOut(seconds: Int, retry: Int)
    func startStorage() throws

    func loadContentURL(_ url: String) async throws -> String
    func checkContentURL(_ url: String) -> String?
    func downloadContent(_ mediaContentKey: String) throws
    func downloadCancelContent(_ mediaContentKey: String) throws
    func removeContent(_ mediaContentKey: String) throws
    func removeCacheWithError() throws
    func updateDownloadDRMInfo(includeExpired: Bool) throws
    func sendStoredLms()

    var contentSnapshots: [KollusContentSnapshot] { get }
    var storageDelegate: KollusStorageEventReceiving? { get set }
}

@MainActor
protocol KollusStorageEventReceiving: AnyObject {
    func storageDidUpdateContents(_ snapshots: [KollusContentSnapshot])
    func storageDidResolveDRM(_ resolution: KollusStorageDRMResolution)
    func storageDidPostLMS(_ post: KollusStorageLMSPost)
    func storageDidCompleteStoredLMS(_ completion: KollusStoredLMSCompletion)
}
