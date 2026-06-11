//
//  EngineRuntimeTraits.swift
//  VideoPlayerModule
//
//  Created by 모바일팀_정준영 on 2026/06/11.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import Foundation

/// Core가 정책 판단에 쓰는 엔진 동작 특성. UI 기능 목록이 아니다 —
/// 그쪽은 ability protocol 채택을 조사하는 `PlayerFeatureAvailability`가 담당한다.
public struct EngineRuntimeTraits: OptionSet, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let continuesWithoutSurface = EngineRuntimeTraits(rawValue: 1 << 0)
    public static let seamlessSurfaceSwap = EngineRuntimeTraits(rawValue: 1 << 1)
    public static let nativePiP = EngineRuntimeTraits(rawValue: 1 << 2)

    /// 엔진이 play/pause/seek 성공을 별도 observer 신호(권위 콜백)로 다시 통지하는가.
    ///
    /// - Kollus = `true`: `playStarted`/`pauseStarted` 등 콜백이 상태를 만든다. Core는 명령 성공 후
    ///   상태를 만들지 않고 outputStream의 `.stateInput`만 신뢰한다.
    /// - Native = `false`: `timeControlStatus(.playing)`은 play-started 상태 입력을 만들지 않으므로,
    ///   Core가 명령 성공 직후 command-origin `PlaybackStateInput`을 reducer에 넣어야 한다.
    ///
    /// 이 비트가 없으면 Native에서 play 성공 후 status가 `.playing`에 도달하지 못한다.
    public static let emitsAuthoritativeStateEvents = EngineRuntimeTraits(rawValue: 1 << 3)
}
