//
//  PlaybackStateLiveFieldsTests.swift
//  VideoPlayerModuleTests
//
//  Created by 모바일개발팀_정준영 on 2026/05/15.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

import XCTest
@testable import VideoPlayerCore

/// Phase 7 T048 — `PlaybackState`의 라이브 스트리밍 필드(`isLive`, `liveDuration`)가
/// 기본값/명시값/`updating(...)` 통과/덮어쓰기 시 어떻게 동작하는지 검증.
///
/// 이 테스트는 Core 도메인만 다루므로 macOS 호스트에서도 실행 가능하다(가드 없음).
final class PlaybackStateLiveFieldsTests: XCTestCase {

    // MARK: - init defaults

    /// 기본 init 인자만 사용하면 `isLive == false`, `liveDuration == nil` 이어야 한다.
    func test_init_defaults_isLiveFalse_liveDurationNil() {
        let state = PlaybackState(
            status: .idle,
            currentTime: 0,
            duration: 0,
            isBuffering: false
        )

        XCTAssertFalse(state.isLive, "기본값은 VOD(isLive=false) 이어야 한다")
        XCTAssertNil(state.liveDuration, "기본값은 liveDuration=nil 이어야 한다")
    }

    /// init에 라이브 필드를 전달하면 그대로 보유한다.
    func test_init_withLiveFields_propagates() {
        let state = PlaybackState(
            status: .playing,
            currentTime: 30,
            duration: 0,
            isBuffering: false,
            isLive: true,
            liveDuration: 600
        )

        XCTAssertTrue(state.isLive)
        XCTAssertEqual(state.liveDuration, 600)
    }

    // MARK: - updating(...) preservation

    /// `updating(...)`에 라이브 필드를 전달하지 않으면 기존 값을 그대로 보존해야 한다.
    func test_updating_preservesLiveFields_whenNotPassed() {
        let original = PlaybackState(
            status: .playing,
            currentTime: 0,
            duration: 0,
            isBuffering: false,
            isLive: true,
            liveDuration: 120
        )

        let next = original.updating(status: .paused)

        XCTAssertEqual(next.status, .paused)
        XCTAssertTrue(next.isLive, "isLive는 명시되지 않았으면 보존되어야 한다")
        XCTAssertEqual(next.liveDuration, 120, "liveDuration은 명시되지 않았으면 보존되어야 한다")
    }

    // MARK: - updating(...) override

    /// `updating(isLive:)`에 값을 전달하면 새 값으로 덮어쓴다.
    func test_updating_overridesIsLive_whenPassed() {
        let original = PlaybackState(
            status: .playing,
            currentTime: 0,
            duration: 0,
            isBuffering: false,
            isLive: true,
            liveDuration: 120
        )

        let next = original.updating(isLive: false)

        XCTAssertFalse(next.isLive, "isLive=false가 명시되면 덮어써야 한다")
        XCTAssertEqual(next.liveDuration, 120, "liveDuration은 명시되지 않았으면 보존되어야 한다")
    }

    /// `updating(liveDuration: .some(value))`에 새 값이 전달되면 새 값으로 덮어쓴다.
    /// `TimeInterval??`(이중 옵션) 시그니처 덕분에 outer `.some(_)`이 explicit override 신호로 해석된다.
    func test_updating_overridesLiveDuration_withConcreteValue() {
        let original = PlaybackState(
            status: .playing,
            currentTime: 0,
            duration: 0,
            isBuffering: false,
            isLive: true,
            liveDuration: 120
        )

        let next = original.updating(liveDuration: .some(900))

        XCTAssertEqual(next.liveDuration, 900, "liveDuration이 명시되면 새 값으로 덮어써야 한다")
        XCTAssertTrue(next.isLive, "isLive는 명시되지 않았으면 보존되어야 한다")
    }

    /// `updating(liveDuration: .some(nil))`로 explicit `nil` 덮어쓰기 시
    /// `PlaybackState.updating`이 `nil`을 그대로 반영하는지 검증.
    func test_updating_explicitNilLiveDuration_honorsTheOverride() {
        let original = PlaybackState(
            status: .playing,
            currentTime: 0,
            duration: 0,
            isBuffering: false,
            isLive: true,
            liveDuration: 120
        )

        // `Optional<TimeInterval?>.some(nil)` — outer Some + inner nil.
        let explicitNil: TimeInterval?? = .some(nil)
        let next = original.updating(liveDuration: explicitNil)

        XCTAssertNil(next.liveDuration, "explicit nil 덮어쓰기 시 liveDuration은 nil이어야 한다")
    }
}
