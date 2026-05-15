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
/// DRM/LMS 콜백은 `KollusObserver`로 forward한다.
@MainActor
final class KollusStorageBridge: KollusStorageEventReceiving {
    private weak var observer: AnyObject?
    private let snapshotsContinuation: AsyncStream<[KollusContentSnapshot]>.Continuation

    init(
        observer: KollusObserver?,
        snapshotsContinuation: AsyncStream<[KollusContentSnapshot]>.Continuation
    ) {
        self.observer = observer.map { $0 as AnyObject }
        self.snapshotsContinuation = snapshotsContinuation
    }

    func storageDidUpdateContents(_ snapshots: [KollusContentSnapshot]) {
        snapshotsContinuation.yield(snapshots)
    }

    func storageDidResolveDRM(_ resolution: KollusStorageDRMResolution) {
        if let observer = observer as? KollusObserver {
            observer.kollus(
                didResolveDRM: resolution.request,
                response: resolution.response,
                error: resolution.error
            )
        }
    }

    func storageDidPostLMS(_ post: KollusStorageLMSPost) {
        if let observer = observer as? KollusObserver {
            observer.kollus(didPostLMS: post.data, result: post.result)
        }
    }

    func storageDidCompleteStoredLMS(_ completion: KollusStoredLMSCompletion) {
        if let observer = observer as? KollusObserver {
            observer.kollusStorage(
                didCompleteStoredLMS: completion.successCount,
                failure: completion.failureCount
            )
        }
    }
}
