//
//  KollusStorageProtocol.swift
//  VideoPlayerModule
//
//  Created by 모바일개발팀_정준영 on 2026/05/15.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

import CoreGraphics
import Foundation

@MainActor
protocol KollusStorageProtocol: AnyObject {
    var applicationKey: String? { get set }
    var applicationBundleID: String? { get set }
    var applicationExpireDate: Date? { get set }
    var keychainGroup: String? { get set }

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
    func storageDidPostLMS(data: String, result: [String: Any])
    func storageDidCompleteStoredLMS(success: Int, failure: Int)
}
