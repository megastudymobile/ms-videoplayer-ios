//
//  KollusSignalMapper.swift
//  VideoPlayerModule
//
//  Created by 모바일팀_정준영 on 2026/06/04.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import Foundation
import VideoPlayerCore

/// Kollus SDK 신호를 Core가 이해하는 `PlayerEngineOutput`으로 번역하는 순수 매퍼.
///
/// 상태를 움직이는 신호는 `.stateInput(PlaybackStateInput)`으로, 상태와 무관한 신호는
/// `.event(PlayerEvent)` passthrough로 바꾼다. 상태도 이벤트도 만들지 않는 신호(scroll/zoom 등)는
/// `nil`을 반환한다. 상태 전이 자체는 매퍼가 결정하지 않고 Core의 `PlaybackStateReducer`가 한다.
///
/// polling 시작/정지, prepare continuation resume, next-episode 검사 같은 부수효과는 매퍼가 아니라
/// `KollusPlayerAdapter`가 수행한다.
enum KollusSignalMapper {
    /// - Parameters:
    ///   - signal: vendor 신호.
    ///   - preparedSnapshot: prepare 완료 시 SDK에서 position/duration/live를 조회해 채우는 클로저.
    ///   - mapError: vendor `Error`를 `PlayerError`로 변환하는 클로저. 경계 밖으로 `Error`를
    ///     내보내지 않기 위해 매퍼 내부에서 즉시 변환한다(Sendable-clean).
    static func normalize(
        _ signal: KollusEngineSignal,
        currentTime: TimeInterval = 0,
        duration: TimeInterval = 0,
        preparedSnapshot: () async -> PlaybackPreparedSnapshot,
        mapError: (Error, String) -> PlayerError
    ) async -> PlayerEngineOutput? {
        switch signal {
        case .prepareToPlayCompleted(let error):
            if let error {
                return .stateInput(.prepareFailed(mapError(error, "prepareToPlay")))
            }
            return .stateInput(.prepared(await preparedSnapshot()))

        case .playStarted(_, let error):
            if let error {
                return .stateInput(.failed(mapError(error, "play")))
            }
            return .stateInput(.playStarted)

        case .pauseStarted(_, let error):
            if let error {
                return .stateInput(.failed(mapError(error, "pause")))
            }
            return .stateInput(.pauseStarted)

        case .bufferingChanged(let buffering, _, let error):
            if let error {
                return .stateInput(.failed(mapError(error, "buffering")))
            }
            return .stateInput(.bufferingChanged(buffering))

        case .stopStarted(let userInteraction, let error):
            if let error {
                return .stateInput(.failed(mapError(error, "stop")))
            }
            return .stateInput(.stopped(stopReason(
                userInteraction: userInteraction,
                currentTime: currentTime,
                duration: duration
            )))

        case .positionChanged(let time, let isSeeking):
            guard !isSeeking else { return nil }
            return .stateInput(.positionChanged(time: time, duration: nil))

        case .unknownError(let error):
            return .stateInput(.failed(mapError(error, "unknown")))

        // MARK: - 상태를 움직이지 않는 passthrough 이벤트

        case .captionUpdated(_, let caption):
            return .event(.captionDidUpdate(text: caption, isSecondary: false))

        case .subCaptionUpdated(_, let caption):
            return .event(.captionDidUpdate(text: caption, isSecondary: true))

        case .naturalSizeResolved(let size):
            return .event(.naturalSizeDidResolve(size))

        case .contentFrameChanged(let frame):
            return .event(.videoFrameDidChange(frame))

        case .framerateResolved(let framerate):
            return .event(.framerateDidResolve(framerate))

        case .externalOutputEnabledChanged(let enabled):
            return .event(.externalOutputDidChange(enabled: enabled))

        case .devicePolicyLocked:
            return .event(.deviceLockPolicyChanged(locked: true))

        case .hlsHeightChanged(let height):
            return .event(.heightDidChange(height))

        case .hlsBitrateChanged(let bitrate):
            return .event(.bitrateDidChange(bitrate))

        // MARK: - 상태도 이벤트도 만들지 않는 신호

        case .scrollChanged,
             .zoomChanged,
             .contentModeChanged,
             .playbackRateChanged,
             .repeatChanged,
             .thumbnailReady,
             .mediaContentKeyResolved:
            return nil
        }
    }

    static func stopReason(
        userInteraction: Bool,
        currentTime: TimeInterval,
        duration: TimeInterval
    ) -> PlayerStopReason {
        guard userInteraction == false else { return .userClosed }
        guard duration > 0 else { return .finished }
        return currentTime >= duration - 0.5 ? .finished : .appLifecycle
    }
}
