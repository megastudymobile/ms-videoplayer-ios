//
//  KollusObserverForwardingTests.swift
//  VideoPlayerModuleTests
//
//  Created by 모바일개발팀_정준영 on 2026/05/15.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

#if canImport(UIKit) && canImport(KollusSDKBinary)

import Foundation
import Testing
import VideoPlayerCore
@testable import VideoPlayerEngineKollus

/// Phase 5 T031 — DRM/LMS observer forwarding 검증.
///
/// `KollusDelegateBridge.handleDRMResponse` / `handleLMSPost`가 정확한 payload로
/// `KollusObserver`에 도달하는지, observer가 nil일 때는 no-op으로 처리되는지,
/// 그리고 `KollusStorageEventReceiving.storageDidCompleteStoredLMS`가
/// fake storage의 `emitStoredLMSComplete` 호출에서 그대로 전달되는지를 검증한다.
@MainActor
@Suite("Kollus DRM/LMS observer forwarding")
struct KollusObserverForwardingTests {

    // MARK: - Fixtures

    private final class FakeObserver: KollusObserver {
        var drmCalls: [(request: [String: Any], response: [String: Any], errorCode: Int?)] = []
        var lmsCalls: [(data: String, result: [String: Any])] = []
        var storedLMSCalls: [(success: Int, failure: Int)] = []

        func kollus(didResolveDRM request: [String: Any], response: [String: Any], error: Error?) {
            drmCalls.append((request, response, (error as NSError?)?.code))
        }
        func kollus(didPostLMS data: String, result: [String: Any]) {
            lmsCalls.append((data, result))
        }
        func kollusStorage(didCompleteStoredLMS success: Int, failure: Int) {
            storedLMSCalls.append((success, failure))
        }
    }

    private final class FakeStorageEvents: KollusStorageEventReceiving {
        var lmsPosts: [KollusStorageLMSPost] = []
        var storedLMSComplete: [KollusStoredLMSCompletion] = []
        var contentsUpdates: [Int] = []
        var drmCalls: [KollusStorageDRMResolution] = []

        func storageDidUpdateContents(_ snapshots: [KollusContentSnapshot]) {
            contentsUpdates.append(snapshots.count)
        }
        func storageDidPostLMS(_ post: KollusStorageLMSPost) {
            lmsPosts.append(post)
        }
        func storageDidCompleteStoredLMS(_ completion: KollusStoredLMSCompletion) {
            storedLMSComplete.append(completion)
        }
        func storageDidResolveDRM(_ resolution: KollusStorageDRMResolution) {
            drmCalls.append(resolution)
        }
    }

    private func makeBridge(observer: KollusObserver?) -> KollusDelegateBridge {
        KollusDelegateBridge(
            onSignal: { _ in },
            onBookmarks: { _ in },
            observer: observer,
            diagnostics: nil
        )
    }

    // MARK: - DRM/LMS forwarding

    @Test("observer가 정확한 payload로 DRM 응답 수신")
    func observer_receivesDRMResponse_withExactPayload() {
        let observer = FakeObserver()
        let bridge = makeBridge(observer: observer)

        let request: [String: Any] = ["cid": "abc123", "deviceKey": "dk-7"]
        let response: [String: Any] = ["status": 200, "license": "xyz"]
        let error = NSError(domain: "kollus.drm", code: 11)

        bridge.handleDRMResponse(request: request, response: response, error: error)

        #expect(observer.drmCalls.count == 1)
        let call = observer.drmCalls[0]
        #expect(call.request["cid"] as? String == "abc123")
        #expect(call.request["deviceKey"] as? String == "dk-7")
        #expect(call.response["status"] as? Int == 200)
        #expect(call.response["license"] as? String == "xyz")
        #expect(call.errorCode == 11)
    }

    @Test("observer가 정확한 payload로 LMS post 수신")
    func observer_receivesLMSPost_withExactPayload() {
        let observer = FakeObserver()
        let bridge = makeBridge(observer: observer)

        let lmsData = "cmd=updateProgress&pos=42"
        let result: [String: Any] = ["ok": true, "saved": 1]

        bridge.handleLMSPost(data: lmsData, result: result)

        #expect(observer.lmsCalls.count == 1)
        let call = observer.lmsCalls[0]
        #expect(call.data == lmsData)
        #expect(call.result["ok"] as? Bool == true)
        #expect(call.result["saved"] as? Int == 1)
    }

    @Test("nil observer일 때 DRM/LMS는 no-op")
    func nilObserver_drmAndLMSAreNoOp() {
        let bridge = makeBridge(observer: nil)

        // Observer가 nil이어도 crash 없이 통과해야 한다.
        bridge.handleDRMResponse(
            request: ["k": "v"],
            response: ["r": "v"],
            error: nil
        )
        bridge.handleLMSPost(data: "x=1", result: ["ok": true])

        // 별도 부수효과 없음 — bridge가 살아있고 추가 호출 가능해야 한다.
        #expect(bridge != nil)
    }

    // MARK: - Storage event forwarding (KollusStorageEventReceiving)

    @Test("storage stored LMS 완료 이벤트 전달")
    func observer_storageStoredLMS_complete() {
        let storage = FakeKollusStorage()
        let storageEvents = FakeStorageEvents()
        storage.storageDelegate = storageEvents

        storage.emitStoredLMSComplete(success: 3, failure: 1)

        #expect(storageEvents.storedLMSComplete.count == 1)
        #expect(storageEvents.storedLMSComplete[0].successCount == 3)
        #expect(storageEvents.storedLMSComplete[0].failureCount == 1)
    }

    @Test("storage bridge가 DRM 응답을 observer로 전달")
    func storageBridge_forwardsStorageDRMResponseToObserver() {
        let observer = FakeObserver()
        let storage = FakeKollusStorage()
        var continuation: AsyncStream<[KollusContentSnapshot]>.Continuation?
        _ = AsyncStream<[KollusContentSnapshot]> {
            continuation = $0
        }
        let bridge = KollusStorageBridge(
            observer: observer,
            snapshotsContinuation: continuation!
        )
        let error = NSError(domain: "kollus.storage.drm", code: 12)

        bridge.storageDidResolveDRM(.init(
            request: ["kind": "download"],
            response: ["status": 200],
            error: error
        ))

        #expect(observer.drmCalls.count == 1)
        #expect(observer.drmCalls[0].request["kind"] as? String == "download")
        #expect(observer.drmCalls[0].response["status"] as? Int == 200)
        #expect(observer.drmCalls[0].errorCode == 12)
    }
}

#endif
