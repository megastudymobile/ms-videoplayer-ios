//
//  AVPlayerSignalMapperTests.swift
//  VideoPlayerModuleTests
//
//  Created by 모바일개발팀_정준영 on 2026/06/04.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

#if canImport(UIKit)

import AVFoundation
import Foundation
import Testing
@testable import VideoPlayerCore
@testable import VideoPlayerEngineNative

/// US3 T032 — `AVPlayerSignalMapper`가 observer 신호를 올바른 `PlayerEngineOutput`으로
/// 번역하는지 검증한다. (설계 §8 5단계) play/pause/seek/prepare는 observer가 아니라 명령 결과로
/// 닫히므로 매퍼 대상이 아니다.
@Suite("AVPlayerSignalMapper")
struct AVPlayerSignalMapperTests {
    @Test("failed는 failed 입력으로 번역된다")
    func failed() {
        let output = AVPlayerSignalMapper.normalize(.failed(.networkError("down")))
        guard case .stateInput(.failed) = output else {
            Issue.record("got \(String(describing: output))")
            return
        }
    }

    @Test("timeControl(.paused)는 무시(nil)된다 — 늦은 paused가 종료 상태를 되살리지 않도록")
    func pausedIgnored() {
        #expect(AVPlayerSignalMapper.normalize(.timeControl(.paused)) == nil)
    }

    @Test("timeControl(.waitingToPlayAtSpecifiedRate)는 bufferingChanged(true)로 번역된다")
    func waitingIsBuffering() {
        let output = AVPlayerSignalMapper.normalize(.timeControl(.waitingToPlayAtSpecifiedRate))
        guard case .stateInput(.bufferingChanged(let buffering)) = output else {
            Issue.record("got \(String(describing: output))")
            return
        }
        #expect(buffering == true)
    }

    @Test("timeControl(.playing)은 bufferingChanged(false)로 번역된다")
    func playingClearsBuffering() {
        let output = AVPlayerSignalMapper.normalize(.timeControl(.playing))
        guard case .stateInput(.bufferingChanged(let buffering)) = output else {
            Issue.record("got \(String(describing: output))")
            return
        }
        #expect(buffering == false)
    }

    @Test("didFinish는 stopped(.finished)로 번역된다")
    func didFinish() {
        let output = AVPlayerSignalMapper.normalize(.didFinish)
        guard case .stateInput(.stopped(.finished)) = output else {
            Issue.record("got \(String(describing: output))")
            return
        }
    }

    @Test("periodicTime은 positionChanged 입력으로 번역된다")
    func periodicTime() {
        let output = AVPlayerSignalMapper.normalize(.periodicTime(seconds: 12.5))
        guard case .stateInput(.positionChanged(let time, let duration)) = output else {
            Issue.record("got \(String(describing: output))")
            return
        }
        #expect(time == 12.5)
        #expect(duration == nil)
    }
}

#endif
