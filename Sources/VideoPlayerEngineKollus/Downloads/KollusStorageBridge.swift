//
//  KollusStorageBridge.swift
//  VideoPlayerModule
//
//  Created by 모바일개발팀_정준영 on 2026/05/15 (Phase 6 T042).
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

import Foundation
import VideoPlayerCore

/// KollusStorageEventReceiving 채택. KollusStorageProtocol delegate 콜백을
/// `KollusDownloadCenter`의 contents/events AsyncStream으로 yield하고
/// DRM/LMS 콜백은 `KollusObserver`로 forward한다.
@MainActor
final class KollusStorageBridge: KollusStorageEventReceiving {
    private weak var observer: AnyObject?
    private let contentsContinuation: AsyncStream<[DownloadedContent]>.Continuation
    private let eventsContinuation: AsyncStream<DownloadEvent>.Continuation
    private let errorChain: PlayerErrorClassifierChain
    /// 직전 download 상태 — completed 전이 감지용 (SDK는 완료 전용 콜백이 없다)
    private var lastDownloadStates: [String: DownloadedContent.DownloadStatus] = [:]

    init(
        observer: KollusObserver?,
        contentsContinuation: AsyncStream<[DownloadedContent]>.Continuation,
        eventsContinuation: AsyncStream<DownloadEvent>.Continuation,
        errorChain: PlayerErrorClassifierChain = PlayerErrorClassifierChain(classifiers: [KollusErrorClassifier()])
    ) {
        self.observer = observer.map { $0 as AnyObject }
        self.contentsContinuation = contentsContinuation
        self.eventsContinuation = eventsContinuation
        self.errorChain = errorChain
    }

    func storageDidUpdateContents(_ snapshots: [KollusContentSnapshot], failure: KollusStorageDownloadFailure?) {
        let contents = snapshots.map { $0.toDownloadedContent() }
        contentsContinuation.yield(contents)

        if let failure {
            eventsContinuation.yield(.failed(
                contentID: failure.mediaContentKey,
                error: errorChain.classify(failure.error, context: .download)
            ))
        }

        for content in contents {
            let previous = lastDownloadStates[content.id]
            if case .completed = content.download, previous != nil, previous != .completed {
                eventsContinuation.yield(.completed(contentID: content.id))
            }
            lastDownloadStates[content.id] = content.download
        }
    }

    func storageDidProgressLicenseRenewal(current: Int, total: Int, error: Error?) {
        if let error {
            eventsContinuation.yield(.licenseRenewalFailed(
                error: errorChain.classify(error, context: .licenseRenewal)
            ))
        } else {
            eventsContinuation.yield(.licenseRenewalProgressed(current: current, total: total))
        }
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
