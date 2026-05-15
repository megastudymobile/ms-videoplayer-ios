//
//  KollusPlayerAdapterSignalTests.swift
//  VideoPlayerModuleTests
//
//  Created by 모바일개발팀_정준영 on 2026/05/15.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

#if canImport(UIKit) && canImport(KollusSDKBinary)

import Foundation
import XCTest
import VideoPlayerCore
@testable import VideoPlayerEngineKollus

@MainActor
final class KollusPlayerAdapterSignalTests: XCTestCase {

    private let validExpire = Date().addingTimeInterval(60 * 60 * 24 * 30)

    private func makeAdapter() -> KollusPlayerAdapter {
        let env = KollusEnvironment(
            applicationKey: "valid-key",
            applicationBundleID: "com.example.app",
            applicationExpireDate: validExpire
        )
        let storage = FakeKollusStorage()
        let bootstrapper = KollusSessionBootstrapper(environment: env) { storage }
        return KollusPlayerAdapter(bootstrapper: bootstrapper, environment: env)
    }

    func test_playStarted_withError_transitionsToFailedAndPublishesDidFail() async {
        let adapter = makeAdapter()
        let stream = await adapter.eventStream
        let error = NSError(domain: "kollus.play", code: 10, userInfo: [
            NSLocalizedDescriptionKey: "play denied"
        ])

        await adapter.handleSignal(.playStarted(userInteraction: true, error: error))

        let state = await adapter.currentState
        guard case .failed(let playerError) = state.status else {
            return XCTFail("Expected failed state, got \(state.status)")
        }
        XCTAssertEqual(playerError, .engineError("Kollus play 실패: play denied"))

        var iterator = stream.makeAsyncIterator()
        guard case .stateDidChange(let emittedState)? = await iterator.next() else {
            return XCTFail("Expected stateDidChange")
        }
        XCTAssertEqual(emittedState.status, state.status)
        guard case .didFail(let emittedError)? = await iterator.next() else {
            return XCTFail("Expected didFail")
        }
        XCTAssertEqual(emittedError, playerError)
    }

    func test_bufferingChanged_withError_doesNotEmitBufferingSuccess() async {
        let adapter = makeAdapter()
        let stream = await adapter.eventStream
        let error = NSError(domain: "kollus.buffer", code: 11, userInfo: [
            NSLocalizedDescriptionKey: "buffer failed"
        ])

        await adapter.handleSignal(.bufferingChanged(buffering: true, prepared: false, error: error))

        let state = await adapter.currentState
        guard case .failed(let playerError) = state.status else {
            return XCTFail("Expected failed state, got \(state.status)")
        }
        XCTAssertFalse(state.isBuffering)
        XCTAssertEqual(playerError, .engineError("Kollus buffering 실패: buffer failed"))

        var iterator = stream.makeAsyncIterator()
        guard case .stateDidChange? = await iterator.next() else {
            return XCTFail("Expected stateDidChange")
        }
        guard case .didFail(let emittedError)? = await iterator.next() else {
            return XCTFail("Expected didFail")
        }
        XCTAssertEqual(emittedError, playerError)
    }

    func test_stopWithFinishedReason_transitionsToFinishedAndPublishesDidFinish() async throws {
        let adapter = makeAdapter()
        let stream = await adapter.eventStream

        try await adapter.stop(reason: .finished)

        let state = await adapter.currentState
        XCTAssertEqual(state.status, .finished)

        var iterator = stream.makeAsyncIterator()
        guard case .stateDidChange(let emittedState)? = await iterator.next() else {
            return XCTFail("Expected stateDidChange")
        }
        XCTAssertEqual(emittedState.status, .finished)
        guard case .didFinish? = await iterator.next() else {
            return XCTFail("Expected didFinish")
        }
    }
}

#endif
