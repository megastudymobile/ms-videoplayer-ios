//
//  PlayerEngineOutputContractTests.swift
//  VideoPlayerModuleTests
//
//  Created by 모바일개발팀_정준영 on 2026/06/04.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

import Foundation
import Testing
@testable import VideoPlayerCore

/// `PlayerPlaybackEngine.outputStream` 계약 검증.
///
/// 핵심: outputStream은 `PlaybackStateInput`을 델타로 싣기 때문에 손실이 영구 상태 desync를
/// 만든다. 따라서 버스트 입력이 하나도 누락되지 않아야 하고(= `.unbounded`),
/// teardown 시 스트림이 finish해 소비 루프가 종료되어야 한다.
@Suite("PlayerEngineOutput contract")
struct PlayerEngineOutputContractTests {
    @Test("outputStream은 버스트 입력을 하나도 누락하지 않는다(.unbounded 계약)")
    func outputStreamDoesNotDropBurst() async {
        let engine = ContractFakeEngine()
        let stream = await engine.outputStream

        // bufferingNewest(8)이면 50개 중 다수가 drop된다. .unbounded여야 전수 도착.
        let burst = 50
        for index in 0..<burst {
            await engine.emitStateInput(.positionChanged(time: TimeInterval(index), duration: nil))
        }
        await engine.finishOutput()

        var received = 0
        for await output in stream {
            if case .stateInput(.positionChanged) = output {
                received += 1
            }
        }

        #expect(received == burst)
    }

    @Test("outputStream은 finish 후 소비 루프가 종료된다")
    func outputStreamFinishesOnTeardown() async {
        let engine = ContractFakeEngine()
        let stream = await engine.outputStream

        await engine.emitStateInput(.playStarted)
        await engine.finishOutput()

        var terminated = false
        for await _ in stream {}
        terminated = true

        #expect(terminated)
    }

    @Test("stateInput과 event passthrough가 순서대로 보존된다")
    func preservesOrderAcrossKinds() async {
        let engine = ContractFakeEngine()
        let stream = await engine.outputStream

        await engine.emitStateInput(.playStarted)
        await engine.emitEvent(.bitrateDidChange(1_000))
        await engine.emitStateInput(.bufferingChanged(true))
        await engine.finishOutput()

        var kinds: [String] = []
        for await output in stream {
            switch output {
            case .stateInput: kinds.append("input")
            case .event: kinds.append("event")
            }
        }

        #expect(kinds == ["input", "event", "input"])
    }
}

/// `outputStream` 계약을 만족하는 최소 fake. 스트림은 단일 장수명 인스턴스 + `.unbounded`.
private actor ContractFakeEngine: PlayerPlaybackEngine {
    nonisolated static let capabilities: EngineCapabilities = [.continuesWithoutSurface]

    let outputStream: AsyncStream<PlayerEngineOutput>

    private let outputContinuation: AsyncStream<PlayerEngineOutput>.Continuation

    init() {
        var outputContinuation: AsyncStream<PlayerEngineOutput>.Continuation?
        outputStream = AsyncStream(bufferingPolicy: .unbounded) { outputContinuation = $0 }
        self.outputContinuation = outputContinuation!
    }

    deinit {
        outputContinuation.finish()
    }

    func prepare(source: PlaybackSource) async throws {}
    func play() async throws {}
    func pause() async throws {}
    func seek(to time: TimeInterval) async throws {}
    func stop(reason: PlayerStopReason) async throws {}

    func emitStateInput(_ input: PlaybackStateInput) {
        outputContinuation.yield(.stateInput(input))
    }

    func emitEvent(_ event: PlayerEvent) {
        outputContinuation.yield(.event(event))
    }

    func finishOutput() {
        outputContinuation.finish()
    }
}
