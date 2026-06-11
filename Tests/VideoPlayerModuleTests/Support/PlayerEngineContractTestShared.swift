#if canImport(UIKit)

//
//  PlayerEngineContractTestShared.swift
//  SmartPlayer
//
//  Created by 모바일개발팀_정준영 on 2026/04/20.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import Testing
@testable import VideoPlayerCore
@testable import VideoPlayerShellSupport

/// Adapter 구현 간 diff 0 증명 기반.
/// AVPlayer/Kollus 양쪽에 동일 assertion을 수행시키기 위한 generic 공유 계약.
///
/// XCTest의 상속 기반 test 수집 대신, Swift Testing에서는 이 generic enum의 static
/// assertion 함수를 각 엔진별 `@Suite`가 호출한다. 지원되지 않는 환경(simulator의 Kollus 등)은
/// 각 `@Suite`에 `.enabled(if: Factory.isSupportedInCurrentEnvironment)` trait로 건너뛴다.
enum PlayerEngineContract<Factory: PlayerEngineAdapterContractTestable> {

    // MARK: Environment

    static func isSupportedInCurrentEnvironmentIsDecidableWithoutThrow() {
        _ = Factory.isSupportedInCurrentEnvironment
    }

    // MARK: Capabilities

    static func capabilitiesMatchExpectation() {
        #expect(type(of: Factory.makeTestAdapter()).capabilities == Factory.expectedCapabilities)
    }

    // MARK: Lifecycle safety (§6.3.5 계약 4)

    static func stopFromIdleDoesNotCrash() async throws {
        let adapter = Factory.makeTestAdapter()
        defer { Task { await Factory.cleanupTestAdapter(adapter) } }

        try await adapter.stop(reason: .userClosed)
        try await adapter.stop(reason: .userClosed)
    }

    static func stopWithFinishedReasonEmitsFinishedOutput() async throws {
        let adapter = Factory.makeTestAdapter()
        defer { Task { await Factory.cleanupTestAdapter(adapter) } }
        let stream = await adapter.outputStream

        try await adapter.stop(reason: .finished)

        let didEmitFinished = await containsFinishedStopOutput(in: stream)
        #expect(didEmitFinished)
    }

    static func unbindRenderSurfaceWithoutBindDoesNotCrash() async throws {
        let adapter = Factory.makeTestAdapter()
        defer { Task { await Factory.cleanupTestAdapter(adapter) } }

        await adapter.unbindRenderSurface()
        await adapter.unbindRenderSurface()
    }

    // MARK: Output stream

    static func outputStreamIsAvailable() async throws {
        let adapter = Factory.makeTestAdapter()
        defer { Task { await Factory.cleanupTestAdapter(adapter) } }

        let stream = await adapter.outputStream
        // 검증 포인트: outputStream property 접근에서 isolation 문제 없이 AsyncStream 획득.
        _ = stream
    }

    private static func containsFinishedStopOutput(
        in stream: AsyncStream<PlayerEngineOutput>,
        timeoutNanoseconds: UInt64 = 1_000_000_000
    ) async -> Bool {
        await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                var iterator = stream.makeAsyncIterator()
                while let output = await iterator.next() {
                    if case .stateInput(.stopped(.finished)) = output {
                        return true
                    }
                }
                return false
            }

            group.addTask {
                try? await Task.sleep(nanoseconds: timeoutNanoseconds)
                return false
            }

            let result = await group.next() ?? false
            group.cancelAll()
            return result
        }
    }
}

#endif
