//
//  KollusStorageProtocol.swift
//  VideoPlayerModule
//
//  Created by 모바일팀_정준영 on 2026/05/15.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import CoreGraphics
import Foundation

struct KollusStorageDRMResolution {
    let request: [String: Any]
    let response: [String: Any]
    let error: Error?
    let snapshots: [KollusContentSnapshot]

    init(
        request: [String: Any],
        response: [String: Any],
        error: Error?,
        snapshots: [KollusContentSnapshot] = []
    ) {
        self.request = request
        self.response = response
        self.error = error
        self.snapshots = snapshots
    }
}

struct KollusStorageLMSPost {
    let data: String
    let result: [String: Any]
}

struct KollusStoredLMSCompletion {
    let successCount: Int
    let failureCount: Int
}

/// 다운로드 진행 delegate가 전달한 실패. SDK error 파라미터를 버리지 않고 동반 전파한다.
struct KollusStorageDownloadFailure {
    let mediaContentKey: String
    let error: Error
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
    /// 미등록 URL은 nil. 조회 자체 실패(네트워크/저장소)는 throw — 두 경우를 구분한다.
    func checkContentURL(_ url: String) throws -> String?
    func downloadContent(_ mediaContentKey: String) throws
    func downloadCancelContent(_ mediaContentKey: String) throws
    func removeContent(_ mediaContentKey: String) throws
    func removeCacheWithError() throws
    func updateDownloadDRMInfo(renewAll: Bool) throws
    func sendStoredLms()

    var contentSnapshots: [KollusContentSnapshot] { get }
    var storageDelegate: KollusStorageEventReceiving? { get set }
}

@MainActor
protocol KollusStorageEventReceiving: AnyObject {
    /// 콘텐츠 목록 갱신. 다운로드 실패가 원인이면 `failure`에 SDK 에러가 동반된다.
    func storageDidUpdateContents(_ snapshots: [KollusContentSnapshot], failure: KollusStorageDownloadFailure?)
    /// 라이선스 일괄 갱신 진행 콜백 (updateDownloadDRMInfo 응답, cur/count).
    func storageDidProgressLicenseRenewal(current: Int, total: Int, error: Error?)
    func storageDidResolveDRM(_ resolution: KollusStorageDRMResolution)
    func storageDidPostLMS(_ post: KollusStorageLMSPost)
    func storageDidCompleteStoredLMS(_ completion: KollusStoredLMSCompletion)
}
