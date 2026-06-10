//
//  KollusPlayerAdapterSignalTests.swift
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

@MainActor
@Suite("KollusPlayerAdapter signal 처리 및 상태 전이")
struct KollusPlayerAdapterSignalTests {

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

    @Test("playStarted 에러는 failed 전이 및 didFail 방출")
    func playStarted_withError_transitionsToFailedAndPublishesDidFail() async {
        let adapter = makeAdapter()
        let stream = await adapter.eventStream
        let error = NSError(domain: "kollus.play", code: 10, userInfo: [
            NSLocalizedDescriptionKey: "play denied"
        ])

        await adapter.handleSignal(.playStarted(userInteraction: true, error: error))

        let state = await adapter.currentState
        guard case .failed(let playerError) = state.status else {
            Issue.record("Expected failed state, got \(state.status)")
            return
        }
        #expect(playerError == .engineError("play denied"))

        var iterator = stream.makeAsyncIterator()
        guard case .stateDidChange(let emittedState)? = await iterator.next() else {
            Issue.record("Expected stateDidChange")
            return
        }
        #expect(emittedState.status == state.status)
        guard case .didFail(let emittedError)? = await iterator.next() else {
            Issue.record("Expected didFail")
            return
        }
        #expect(emittedError == playerError)
    }

    @Test("bufferingChanged 에러는 buffering 성공을 방출하지 않음")
    func bufferingChanged_withError_doesNotEmitBufferingSuccess() async {
        let adapter = makeAdapter()
        let stream = await adapter.eventStream
        let error = NSError(domain: "kollus.buffer", code: 11, userInfo: [
            NSLocalizedDescriptionKey: "buffer failed"
        ])

        await adapter.handleSignal(.bufferingChanged(buffering: true, prepared: false, error: error))

        let state = await adapter.currentState
        guard case .failed(let playerError) = state.status else {
            Issue.record("Expected failed state, got \(state.status)")
            return
        }
        #expect(!(state.isBuffering))
        #expect(playerError == .engineError("buffer failed"))

        var iterator = stream.makeAsyncIterator()
        guard case .stateDidChange? = await iterator.next() else {
            Issue.record("Expected stateDidChange")
            return
        }
        guard case .didFail(let emittedError)? = await iterator.next() else {
            Issue.record("Expected didFail")
            return
        }
        #expect(emittedError == playerError)
    }

    // 플래그 소진까지만 검증 — 이어지는 SDK play 호출은 시뮬레이터 스텁으로 확인 불가(실기기 항목).
    @Test("시스템 pause 후 buffering 해소 시 재개 플래그를 소진")
    func systemPauseBeforeBuffering_isClearedWhenBufferingEnds() async {
        let adapter = makeAdapter()

        await adapter.handleSignal(.pauseStarted(userInteraction: false, error: nil))
        #expect(await adapter.systemPausedBeforeBuffering)

        await adapter.handleSignal(.bufferingChanged(buffering: true, prepared: true, error: nil))
        #expect(await adapter.systemPausedBeforeBuffering)

        await adapter.handleSignal(.bufferingChanged(buffering: false, prepared: true, error: nil))
        #expect(await adapter.systemPausedBeforeBuffering == false)
    }

    @Test("배속 설정은 콘텐츠 최대 배속으로 clamp")
    func playbackRateClampsToContentMaximum() {
        #expect(KollusPlayerAdapter.clampedPlaybackRate(2.5, maxPlaybackRate: 2) == 2.0)
        #expect(KollusPlayerAdapter.clampedPlaybackRate(1.5, maxPlaybackRate: 2) == 1.5)
        #expect(KollusPlayerAdapter.clampedPlaybackRate(2.5, maxPlaybackRate: 0) == 2.5)
    }

    @Test("finished 사유 stop은 finished 전이 및 didFinish 방출")
    func stopWithFinishedReason_transitionsToFinishedAndPublishesDidFinish() async throws {
        let adapter = makeAdapter()
        let stream = await adapter.eventStream

        try await adapter.stop(reason: .finished)

        let state = await adapter.currentState
        #expect(state.status == .finished)

        var iterator = stream.makeAsyncIterator()
        guard case .stateDidChange(let emittedState)? = await iterator.next() else {
            Issue.record("Expected stateDidChange")
            return
        }
        #expect(emittedState.status == .finished)
        guard case .didFinish? = await iterator.next() else {
            Issue.record("Expected didFinish")
            return
        }
    }
}

#endif
