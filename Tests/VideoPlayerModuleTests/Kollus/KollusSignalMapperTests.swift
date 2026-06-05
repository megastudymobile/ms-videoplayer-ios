//
//  KollusSignalMapperTests.swift
//  VideoPlayerModuleTests
//
//  Created by 모바일개발팀_정준영 on 2026/06/04.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

#if canImport(UIKit) && canImport(KollusSDKBinary)

import Foundation
import Testing
@testable import VideoPlayerCore
@testable import VideoPlayerEngineKollus

/// US2 T022/T024 — `KollusSignalMapper`가 vendor 신호를 올바른 `PlayerEngineOutput`으로
/// 번역하는지 검증한다. 매퍼는 순수하므로 SDK/actor 없이 전수 검증 가능. (설계 §8 4단계)
@Suite("KollusSignalMapper")
struct KollusSignalMapperTests {
    private let snapshot = PlaybackPreparedSnapshot(position: 3, duration: 100, isLive: false, liveDuration: nil)

    private func mapError(_ error: Error, _ operation: String) -> PlayerError {
        .engineError("\(operation): \(error.localizedDescription)")
    }

    private func normalize(_ signal: KollusEngineSignal) async -> PlayerEngineOutput? {
        await KollusSignalMapper.normalize(
            signal,
            preparedSnapshot: { snapshot },
            mapError: mapError
        )
    }

    private struct StubError: Error {}

    // MARK: - prepare

    @Test("prepareToPlayCompleted(nil)은 prepared 입력으로 번역된다")
    func prepareSuccess() async {
        let output = await normalize(.prepareToPlayCompleted(error: nil))
        guard case .stateInput(.prepared(let snap)) = output else {
            Issue.record("expected .stateInput(.prepared), got \(String(describing: output))")
            return
        }
        #expect(snap == snapshot)
    }

    @Test("prepareToPlayCompleted(error)는 prepareFailed 입력으로 번역된다")
    func prepareFailure() async {
        let output = await normalize(.prepareToPlayCompleted(error: StubError()))
        guard case .stateInput(.prepareFailed) = output else {
            Issue.record("expected .stateInput(.prepareFailed), got \(String(describing: output))")
            return
        }
    }

    // MARK: - play / pause / buffering

    @Test("playStarted(nil)은 playStarted 입력으로 번역된다")
    func playSuccess() async {
        let output = await normalize(.playStarted(userInteraction: true, error: nil))
        guard case .stateInput(.playStarted) = output else {
            Issue.record("got \(String(describing: output))")
            return
        }
    }

    @Test("playStarted(error)는 failed 입력으로 번역된다")
    func playFailure() async {
        let output = await normalize(.playStarted(userInteraction: true, error: StubError()))
        guard case .stateInput(.failed) = output else {
            Issue.record("got \(String(describing: output))")
            return
        }
    }

    @Test("pauseStarted(nil)은 pauseStarted 입력으로 번역된다")
    func pauseSuccess() async {
        let output = await normalize(.pauseStarted(userInteraction: true, error: nil))
        guard case .stateInput(.pauseStarted) = output else {
            Issue.record("got \(String(describing: output))")
            return
        }
    }

    @Test("bufferingChanged(false)는 bufferingChanged(false) 입력으로 번역된다")
    func bufferingFalse() async {
        let output = await normalize(.bufferingChanged(buffering: false, prepared: true, error: nil))
        guard case .stateInput(.bufferingChanged(let buffering)) = output else {
            Issue.record("got \(String(describing: output))")
            return
        }
        #expect(buffering == false)
    }

    // MARK: - stop (userInteraction 분기)

    @Test("stopStarted(userInteraction: true)는 stopped(.userClosed)로 번역된다")
    func stopUser() async {
        let output = await normalize(.stopStarted(userInteraction: true, error: nil))
        guard case .stateInput(.stopped(.userClosed)) = output else {
            Issue.record("got \(String(describing: output))")
            return
        }
    }

    @Test("stopStarted(userInteraction: false)는 stopped(.finished)로 번역된다")
    func stopFinished() async {
        let output = await normalize(.stopStarted(userInteraction: false, error: nil))
        guard case .stateInput(.stopped(.finished)) = output else {
            Issue.record("got \(String(describing: output))")
            return
        }
    }

    // MARK: - position (isSeeking guard)

    @Test("positionChanged(isSeeking: false)는 positionChanged 입력으로 번역된다")
    func positionPlaying() async {
        let output = await normalize(.positionChanged(time: 42, isSeeking: false))
        guard case .stateInput(.positionChanged(let time, let duration)) = output else {
            Issue.record("got \(String(describing: output))")
            return
        }
        #expect(time == 42)
        #expect(duration == nil)
    }

    @Test("positionChanged(isSeeking: true)는 무시(nil)된다")
    func positionSeekingIgnored() async {
        let output = await normalize(.positionChanged(time: 42, isSeeking: true))
        #expect(output == nil)
    }

    // MARK: - passthrough events

    @Test("caption/subCaption은 captionDidUpdate 이벤트로 passthrough된다")
    func captionPassthrough() async {
        let main = await normalize(.captionUpdated(charset: nil, caption: "hi"))
        guard case .event(.captionDidUpdate(let text, let isSecondary)) = main else {
            Issue.record("got \(String(describing: main))")
            return
        }
        #expect(text == "hi")
        #expect(isSecondary == false)

        let sub = await normalize(.subCaptionUpdated(charset: nil, caption: "sub"))
        guard case .event(.captionDidUpdate(_, let secondary)) = sub else {
            Issue.record("got \(String(describing: sub))")
            return
        }
        #expect(secondary == true)
    }

    @Test("hlsHeight/hlsBitrate는 이벤트로 passthrough된다")
    func hlsPassthrough() async {
        let height = await normalize(.hlsHeightChanged(height: 720))
        guard case .event(.heightDidChange(720)) = height else {
            Issue.record("got \(String(describing: height))")
            return
        }
        let bitrate = await normalize(.hlsBitrateChanged(bitrate: 5_000))
        guard case .event(.bitrateDidChange(5_000)) = bitrate else {
            Issue.record("got \(String(describing: bitrate))")
            return
        }
    }

    // MARK: - 무시 신호

    @Test("scroll/zoom/playbackRate 등은 nil로 무시된다")
    func nonStateNonEventIgnored() async {
        #expect(await normalize(.scrollChanged(distance: .zero)) == nil)
        #expect(await normalize(.zoomChanged(value: 1)) == nil)
        #expect(await normalize(.playbackRateChanged(rate: 1.5)) == nil)
        #expect(await normalize(.repeatChanged(enabled: true)) == nil)
    }
}

#endif
