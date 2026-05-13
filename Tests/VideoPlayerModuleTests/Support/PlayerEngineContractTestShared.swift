#if canImport(UIKit)

//
//  PlayerEngineContractTestShared.swift
//  SmartPlayer
//
//  Created by 모바일개발팀_정준영 on 2026/04/20.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import XCTest
@testable import VideoPlayerModule

/// Adapter 구현 간 diff 0 증명 기반.
/// AVPlayer/Kollus 양쪽에 동일 assertion을 수행시키기 위한 generic 공유 베이스.
/// 각 concrete test class는 이 class를 typealias 없이 상속만 하면 XCTest가 inherited test 메서드를 자동 수집한다.
class PlayerEngineContractTestShared<AdapterFactory: PlayerEngineAdapterContractTestable>: XCTestCase {

    // MARK: Environment

    func test_isSupportedInCurrentEnvironment_isDecidableWithoutThrow() {
        _ = AdapterFactory.isSupportedInCurrentEnvironment
    }

    // MARK: Initial state

    func test_initialState_isIdle() async throws {
        try skipIfUnsupported()
        let adapter = AdapterFactory.makeTestAdapter()
        defer { Task { await AdapterFactory.cleanupTestAdapter(adapter) } }

        let state = await adapter.currentState
        XCTAssertEqual(state.status, .idle)
        XCTAssertEqual(state.currentTime, 0)
        XCTAssertFalse(state.isBuffering)
    }

    // MARK: Capabilities

    func test_capabilities_matchExpectation() throws {
        try skipIfUnsupported()
        XCTAssertEqual(type(of: AdapterFactory.makeTestAdapter()).capabilities, AdapterFactory.expectedCapabilities)
    }

    // MARK: Lifecycle safety (§6.3.5 계약 4)

    func test_stop_fromIdle_doesNotCrash() async throws {
        try skipIfUnsupported()
        let adapter = AdapterFactory.makeTestAdapter()
        defer { Task { await AdapterFactory.cleanupTestAdapter(adapter) } }

        await adapter.stop()
        await adapter.stop()

        let state = await adapter.currentState
        XCTAssertEqual(state.status, .idle)
    }

    func test_unbindRenderSurface_withoutBind_doesNotCrash() async throws {
        try skipIfUnsupported()
        let adapter = AdapterFactory.makeTestAdapter()
        defer { Task { await AdapterFactory.cleanupTestAdapter(adapter) } }

        await adapter.unbindRenderSurface()
        await adapter.unbindRenderSurface()

        let state = await adapter.currentState
        XCTAssertEqual(state.status, .idle)
    }

    // MARK: Event stream

    func test_eventStream_isAvailable() async throws {
        try skipIfUnsupported()
        let adapter = AdapterFactory.makeTestAdapter()
        defer { Task { await AdapterFactory.cleanupTestAdapter(adapter) } }

        let stream = await adapter.eventStream
        // 검증 포인트: eventStream property 접근에서 isolation 문제 없이 AsyncStream 획득.
        _ = stream
    }

    // MARK: Helpers

    private func skipIfUnsupported(file: StaticString = #filePath, line: UInt = #line) throws {
        if !AdapterFactory.isSupportedInCurrentEnvironment {
            throw XCTSkip("Adapter가 현재 환경에서 지원되지 않음. (simulator에서 Kollus 등)")
        }
    }
}

#endif
