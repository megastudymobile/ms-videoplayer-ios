//
//  PlaybackStateReducerTests.swift
//  VideoPlayerModuleTests
//
//  Created by 모바일개발팀_정준영 on 2026/06/04.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

import Foundation
import Testing
@testable import VideoPlayerCore

/// US1 T010/T011 — 순수 `PlaybackStateReducer`가 SDK/actor 없이 전 입력에서
/// 올바른 다음 상태와 이벤트를 만드는지 전수 검증한다. (설계 §8 1단계)
@Suite("PlaybackStateReducer")
struct PlaybackStateReducerTests {
    private let reducer = PlaybackStateReducer()

    private func makeState(
        status: PlaybackState.Status,
        currentTime: TimeInterval = 0,
        duration: TimeInterval = 0,
        isBuffering: Bool = false,
        isLive: Bool = false,
        liveDuration: TimeInterval? = nil
    ) -> PlaybackState {
        PlaybackState(
            status: status,
            currentTime: currentTime,
            duration: duration,
            isBuffering: isBuffering,
            isLive: isLive,
            liveDuration: liveDuration
        )
    }

    // MARK: - prepared

    @Test("prepared는 readyToPlay로 전이하고 스냅샷 필드를 반영한다")
    func preparedSetsReadyToPlay() {
        let snapshot = PlaybackPreparedSnapshot(position: 5, duration: 120, isLive: false, liveDuration: nil)
        let output = reducer.reduce(.prepared(snapshot), state: .idle)

        #expect(output.next.status == .readyToPlay)
        #expect(output.next.currentTime == 5)
        #expect(output.next.duration == 120)
        #expect(output.next.isBuffering == false)
        #expect(output.next.isLive == false)
        #expect(output.events == [.stateDidChange(output.next)])
    }

    @Test("prepared는 라이브 스냅샷의 isLive/liveDuration을 반영한다")
    func preparedReflectsLiveFields() {
        let snapshot = PlaybackPreparedSnapshot(position: 0, duration: 0, isLive: true, liveDuration: 30)
        let output = reducer.reduce(.prepared(snapshot), state: .idle)

        #expect(output.next.isLive == true)
        #expect(output.next.liveDuration == 30)
    }

    @Test("prepared의 liveDuration nil은 기존 liveDuration을 지운다")
    func preparedClearsLiveDurationWhenNil() {
        let state = makeState(status: .preparing, isLive: true, liveDuration: 99)
        let snapshot = PlaybackPreparedSnapshot(position: 0, duration: 10, isLive: false, liveDuration: nil)
        let output = reducer.reduce(.prepared(snapshot), state: state)

        #expect(output.next.liveDuration == nil)
    }

    // MARK: - prepareFailed / failed

    @Test("prepareFailed는 failed로 전이하고 stateDidChange+didFail을 발행한다")
    func prepareFailedEmitsDidFail() {
        let error = PlayerError.engineError("prepare boom")
        let output = reducer.reduce(.prepareFailed(error), state: makeState(status: .preparing))

        #expect(output.next.status == .failed(error))
        #expect(output.next.isBuffering == false)
        #expect(output.events == [.stateDidChange(output.next), .didFail(error)])
    }

    @Test("failed는 failed로 전이하고 stateDidChange+didFail을 발행한다")
    func failedEmitsDidFail() {
        let error = PlayerError.networkError("net down")
        let output = reducer.reduce(.failed(error), state: makeState(status: .playing))

        #expect(output.next.status == .failed(error))
        #expect(output.events == [.stateDidChange(output.next), .didFail(error)])
    }

    // MARK: - play / pause

    @Test("playStarted는 playing으로 전이하고 버퍼링을 끈다")
    func playStarted() {
        let output = reducer.reduce(.playStarted, state: makeState(status: .buffering, isBuffering: true))

        #expect(output.next.status == .playing)
        #expect(output.next.isBuffering == false)
        #expect(output.events == [.stateDidChange(output.next)])
    }

    @Test("pauseStarted는 paused로 전이한다")
    func pauseStarted() {
        let output = reducer.reduce(.pauseStarted, state: makeState(status: .playing))

        #expect(output.next.status == .paused)
        #expect(output.events == [.stateDidChange(output.next)])
    }

    // MARK: - bufferingChanged

    @Test("bufferingChanged(true)는 buffering으로 전이하고 bufferingDidChange만 발행한다")
    func bufferingTrue() {
        let output = reducer.reduce(.bufferingChanged(true), state: makeState(status: .playing))

        #expect(output.next.status == .buffering)
        #expect(output.next.isBuffering == true)
        #expect(output.events == [.bufferingDidChange(isBuffering: true)])
    }

    @Test("bufferingChanged(false)는 readyToPlay에서 readyToPlay를 유지한다")
    func bufferingFalseKeepsReadyToPlay() {
        let output = reducer.reduce(.bufferingChanged(false), state: makeState(status: .readyToPlay))

        #expect(output.next.status == .readyToPlay)
        #expect(output.next.isBuffering == false)
        #expect(output.events == [.bufferingDidChange(isBuffering: false)])
    }

    @Test("bufferingChanged(false)는 buffering에서 playing으로 복귀한다")
    func bufferingFalseResumesPlaying() {
        let output = reducer.reduce(.bufferingChanged(false), state: makeState(status: .buffering, isBuffering: true))

        #expect(output.next.status == .playing)
        #expect(output.next.isBuffering == false)
    }

    @Test("bufferingChanged는 finished를 되살리지 않고 이벤트만 발행한다")
    func bufferingGuardsFinished() {
        let state = makeState(status: .finished)
        let output = reducer.reduce(.bufferingChanged(true), state: state)

        #expect(output.next == state)
        #expect(output.events == [.bufferingDidChange(isBuffering: true)])
    }

    @Test("bufferingChanged는 failed를 되살리지 않고 이벤트만 발행한다")
    func bufferingGuardsFailed() {
        let state = makeState(status: .failed(.engineError("x")))
        let output = reducer.reduce(.bufferingChanged(false), state: state)

        #expect(output.next == state)
        #expect(output.events == [.bufferingDidChange(isBuffering: false)])
    }

    @Test("bufferingChanged(false)는 paused에서도 playing으로 되살아난다(의도적 보존 quirk)")
    func bufferingFalseFromPausedRevivesToPlaying() {
        // 설계 §5.2 잠재버그 보존: paused 중 buffering 종료 시 playing으로 전이.
        // 이는 기존 consume/handleSignal과 동일한 행위를 의도적으로 보존한 것이다.
        let output = reducer.reduce(.bufferingChanged(false), state: makeState(status: .paused))

        #expect(output.next.status == .playing)
    }

    // MARK: - stopped (4 reason 전수)

    @Test("stopped(.finished)는 finished로 전이하고 stateDidChange+didFinish를 발행한다")
    func stoppedFinished() {
        let output = reducer.reduce(.stopped(.finished), state: makeState(status: .playing))

        #expect(output.next.status == .finished)
        #expect(output.next.isBuffering == false)
        #expect(output.events == [.stateDidChange(output.next), .didFinish])
    }

    @Test("stopped(.userClosed)는 idle로 전이하고 stateDidChange만 발행한다")
    func stoppedUserClosed() {
        let output = reducer.reduce(.stopped(.userClosed), state: makeState(status: .playing))

        #expect(output.next == .idle)
        #expect(output.events == [.stateDidChange(.idle)])
    }

    @Test("stopped(.replacedSource)는 idle로 전이한다")
    func stoppedReplacedSource() {
        let output = reducer.reduce(.stopped(.replacedSource), state: makeState(status: .playing))

        #expect(output.next == .idle)
        #expect(output.events == [.stateDidChange(.idle)])
    }

    @Test("stopped(.appLifecycle)는 idle로 전이한다")
    func stoppedAppLifecycle() {
        let output = reducer.reduce(.stopped(.appLifecycle), state: makeState(status: .paused))

        #expect(output.next == .idle)
        #expect(output.events == [.stateDidChange(.idle)])
    }

    // MARK: - positionChanged

    @Test("positionChanged는 currentTime을 갱신하고 timeDidChange만 발행한다")
    func positionChangedUpdatesTime() {
        let state = makeState(status: .playing, currentTime: 10, duration: 120)
        let output = reducer.reduce(.positionChanged(time: 42, duration: 120), state: state)

        #expect(output.next.currentTime == 42)
        #expect(output.next.duration == 120)
        #expect(output.next.status == .playing)
        #expect(output.events == [.timeDidChange(currentTime: 42, duration: 120)])
    }

    @Test("positionChanged는 미확정 duration(nil/0)이 확정 duration을 덮어쓰지 않는다")
    func positionChangedKeepsResolvedDuration() {
        let state = makeState(status: .playing, currentTime: 10, duration: 120)

        let nilOutput = reducer.reduce(.positionChanged(time: 50, duration: nil), state: state)
        #expect(nilOutput.next.duration == 120)
        #expect(nilOutput.events == [.timeDidChange(currentTime: 50, duration: 120)])

        let zeroOutput = reducer.reduce(.positionChanged(time: 50, duration: 0), state: state)
        #expect(zeroOutput.next.duration == 120)
    }
}
