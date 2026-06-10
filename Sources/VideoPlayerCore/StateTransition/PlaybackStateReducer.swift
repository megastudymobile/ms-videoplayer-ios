//
//  PlaybackStateReducer.swift
//  VideoPlayerModule
//
//  Created by 모바일개발팀_정준영 on 2026/06/04.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

import Foundation

/// 재생 상태 전이의 단일 진실원(single source of truth).
///
/// "현재 상태 + 입력 → 다음 상태 + 발행할 이벤트"를 계산하는 순수 함수다. SDK·actor·polling을
/// 전혀 모른다. 부수효과(continuation resume, position polling 등)는 reducer 밖에서 처리한다.
public struct PlaybackStateReducer: Sendable {
    public init() {}

    public func reduce(
        _ input: PlaybackStateInput,
        state: PlaybackState
    ) -> PlaybackStateReducerOutput {
        switch input {
        case .prepared(let snapshot):
            let next = state.updating(
                status: .readyToPlay,
                currentTime: snapshot.position,
                duration: snapshot.duration,
                isBuffering: false,
                isLive: snapshot.isLive,
                liveDuration: .some(snapshot.liveDuration)
            )
            return PlaybackStateReducerOutput(next: next, events: [.stateDidChange(next)])

        case .prepareFailed(let error):
            let next = state.updating(status: .failed(error), isBuffering: false)
            return PlaybackStateReducerOutput(next: next, events: [.stateDidChange(next), .didFail(error)])

        case .playStarted:
            let next = state.updating(status: .playing, isBuffering: false)
            return PlaybackStateReducerOutput(next: next, events: [.stateDidChange(next)])

        case .pauseStarted:
            let next = state.updating(status: .paused, isBuffering: false)
            return PlaybackStateReducerOutput(next: next, events: [.stateDidChange(next)])

        case .bufferingChanged(let buffering):
            return reduceBufferingChanged(buffering, state: state)

        case .stopped(let reason):
            return reduceStopped(reason, state: state)

        case .positionChanged(let time, let duration):
            return reducePositionChanged(time: time, duration: duration, state: state)

        case .seeking(let time):
            // seek: 목표 위치로 즉시 점프(위치만). 로딩 인디케이터/상태 변경 없음(YouTube 동작).
            // 영상 정지/재개는 Shell의 scrubBegan→pause / release→play가 담당하고,
            // 실제 버퍼링이 필요하면 SDK의 bufferingChanged가 로딩을 따로 구동한다.
            // terminal(.finished/.failed)에서는 무시.
            if case .finished = state.status {
                return PlaybackStateReducerOutput(next: state, events: [])
            }
            if case .failed = state.status {
                return PlaybackStateReducerOutput(next: state, events: [])
            }
            let next = state.updating(currentTime: time)
            return PlaybackStateReducerOutput(
                next: next,
                events: [.timeDidChange(currentTime: time, duration: next.duration)]
            )

        case .failed(let error):
            let next = state.updating(status: .failed(error), isBuffering: false)
            return PlaybackStateReducerOutput(next: next, events: [.stateDidChange(next), .didFail(error)])
        }
    }

    // MARK: - Private

    private func reducePositionChanged(
        time: TimeInterval,
        duration: TimeInterval?,
        state: PlaybackState
    ) -> PlaybackStateReducerOutput {
        // 미확정 duration(0)이 이미 확정된 duration을 덮어쓰지 않도록 보호.
        let resolvedDuration: TimeInterval
        if let duration, duration > 0 {
            resolvedDuration = duration
        } else {
            resolvedDuration = state.duration
        }
        // 위치 갱신만 한다(상태/버퍼링 불변). seek의 stale 위치 무시는 PlayerCore chase가 처리하고,
        // 실제 버퍼링 표시는 SDK의 bufferingChanged가 구동한다.
        let next = state.updating(currentTime: time, duration: resolvedDuration)
        return PlaybackStateReducerOutput(
            next: next,
            events: [.timeDidChange(currentTime: time, duration: resolvedDuration)]
        )
    }

    private func reduceBufferingChanged(
        _ buffering: Bool,
        state: PlaybackState
    ) -> PlaybackStateReducerOutput {
        // terminal 상태(.finished/.failed)는 늦게 도착한 buffering 이벤트로 되살리지 않는다.
        // 상태를 바꾸지 않고 bufferingDidChange 이벤트만 흘린다.
        if case .finished = state.status {
            return PlaybackStateReducerOutput(next: state, events: [.bufferingDidChange(isBuffering: buffering)])
        }
        if case .failed = state.status {
            return PlaybackStateReducerOutput(next: state, events: [.bufferingDidChange(isBuffering: buffering)])
        }

        // 일시정지/준비완료 중 버퍼링은 status를 유지한다(isBuffering 플래그만 변경).
        // buffering 종료 시 무조건 `.playing`으로 전이하면 일시정지가 재생으로 둔갑한다.
        // `.playing`에서 시작한 버퍼링만 `.buffering`으로 전이하고, 종료 시 `.playing`으로 복원한다.
        let nextStatus: PlaybackState.Status
        if buffering {
            if case .playing = state.status {
                nextStatus = .buffering
            } else {
                nextStatus = state.status
            }
        } else {
            if case .buffering = state.status {
                nextStatus = .playing
            } else {
                nextStatus = state.status
            }
        }

        let next = state.updating(status: nextStatus, isBuffering: buffering)
        // 상태는 갱신하되 stateDidChange가 아니라 bufferingDidChange만 발행한다.
        return PlaybackStateReducerOutput(next: next, events: [.bufferingDidChange(isBuffering: buffering)])
    }

    private func reduceStopped(
        _ reason: PlayerStopReason,
        state: PlaybackState
    ) -> PlaybackStateReducerOutput {
        let next: PlaybackState
        switch reason {
        case .finished:
            next = state.updating(status: .finished, isBuffering: false)
        case .userClosed, .replacedSource, .appLifecycle:
            next = .idle
        }
        let events: [PlayerEvent] = reason == .finished
            ? [.stateDidChange(next), .didFinish]
            : [.stateDidChange(next)]
        return PlaybackStateReducerOutput(next: next, events: events)
    }
}
