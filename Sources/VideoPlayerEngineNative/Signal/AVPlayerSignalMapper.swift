//
//  AVPlayerSignalMapper.swift
//  VideoPlayerModule
//
//  Created by 모바일팀_정준영 on 2026/06/04.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import AVFoundation
import Foundation
import VideoPlayerCore

/// AVPlayer KVO/Notification/periodic observer가 만드는 사건. `AVPlayerAdapter`의 내부
/// `ObserverEvent`와 같은 의미이며, 매퍼 단위 테스트를 위해 공유 가능한 형태로 분리했다.
enum AVPlayerSignal: Sendable {
    case failed(PlayerError)
    case timeControl(AVPlayer.TimeControlStatus)
    case didFinish
    case periodicTime(seconds: Double)
}

/// AVPlayer observer 신호를 Core가 이해하는 `PlayerEngineOutput`으로 번역하는 순수 매퍼.
///
/// Native는 play/pause/seek/prepare를 observer가 아니라 **명령 결과**로 보고한다(권위 콜백 없음).
/// 따라서 그 경로는 매퍼가 아니라 Core command-origin으로 닫는다. 매퍼는 observer가
/// 실제로 만드는 신호(실패, 버퍼링 상태, 종료, 주기 위치)만 다룬다.
///
/// - Note: `.timeControl(.paused)`는 무시한다(`nil`). AVPlayer는 stop/finish 뒤에도 paused를
///   늦게 통지할 수 있어, 이를 상태 입력으로 바꾸면 종료된 재생을 되살릴 수 있다.
enum AVPlayerSignalMapper {
    static func normalize(_ signal: AVPlayerSignal) -> PlayerEngineOutput? {
        switch signal {
        case .failed(let error):
            return .stateInput(.failed(error))

        case .timeControl(let status):
            switch status {
            case .paused:
                return nil
            case .waitingToPlayAtSpecifiedRate:
                return .stateInput(.bufferingChanged(true))
            case .playing:
                return .stateInput(.bufferingChanged(false))
            @unknown default:
                return nil
            }

        case .didFinish:
            return .stateInput(.stopped(.finished))

        case .periodicTime(let seconds):
            return .stateInput(.positionChanged(time: seconds, duration: nil))
        }
    }
}
