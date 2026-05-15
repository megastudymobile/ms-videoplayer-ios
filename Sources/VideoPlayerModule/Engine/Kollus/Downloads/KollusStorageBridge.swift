//
//  KollusStorageBridge.swift
//  VideoPlayerModule
//
//  Created by 모바일개발팀_정준영 on 2026/05/15 (Phase 6 T042).
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

import Foundation

/// KollusStorageEventReceiving 채택. KollusStorageProtocol delegate 콜백을
/// `KollusDownloadCenter.contents` AsyncStream으로 yield하고
/// LMS 콜백은 `KollusObserver`로 forward한다.
@MainActor
final class KollusStorageBridge: KollusStorageEventReceiving {
    private weak var observer: AnyObject?
    private let snapshotsContinuation: AsyncStream<[KollusContentSnapshot]>.Continuation
    private weak var storage: AnyObject?

    init(
        observer: KollusObserver?,
        snapshotsContinuation: AsyncStream<[KollusContentSnapshot]>.Continuation,
        storage: KollusStorageProtocol
    ) {
        self.observer = observer.map { $0 as AnyObject }
        self.snapshotsContinuation = snapshotsContinuation
        self.storage = storage as AnyObject
    }

    func storageDidUpdateContents(_ snapshots: [KollusContentSnapshot]) {
        snapshotsContinuation.yield(snapshots)
    }

    func storageDidPostLMS(data: String, result: [String: Any]) {
        if let observer = observer as? KollusObserver {
            observer.kollus(didPostLMS: data, result: result)
        }
    }

    func storageDidCompleteStoredLMS(success: Int, failure: Int) {
        if let observer = observer as? KollusObserver {
            observer.kollusStorage(didCompleteStoredLMS: success, failure: failure)
        }
    }
}
