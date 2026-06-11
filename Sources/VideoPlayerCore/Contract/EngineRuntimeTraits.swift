//
//  EngineRuntimeTraits.swift
//  VideoPlayerModule
//
//  Created by 모바일팀_정준영 on 2026/06/11.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import Foundation

/// Core가 정책 판단에 쓰는 엔진 동작 특성. UI 기능 목록이 아니다 —
/// 그쪽은 ability protocol 채택을 조사하는 `PlayerFeature.available(for:)`가 담당한다.
public struct EngineRuntimeTraits: Equatable, Sendable {
    public let surface: EngineSurfaceRuntimeTraits
    public let stateAuthority: EngineStateEventAuthority

    public static let `default` = EngineRuntimeTraits()

    /// AVPlayer는 surface 분리 후에도 재생이 유지된다.
    public static let avPlayer = EngineRuntimeTraits(
        surface: EngineSurfaceRuntimeTraits(continuesWithoutSurface: true),
        stateAuthority: .commandSuccessClosesState
    )

    public static let kollus = EngineRuntimeTraits(
        stateAuthority: .engineEventsAreAuthoritative
    )

    public init(
        surface: EngineSurfaceRuntimeTraits = .default,
        stateAuthority: EngineStateEventAuthority = .commandSuccessClosesState
    ) {
        self.surface = surface
        self.stateAuthority = stateAuthority
    }

    /// 환경/정책이 surface 특성만 바꿔야 할 때 사용 — 나머지 trait는 보존한다.
    public func withSurface(continuesWithoutSurface: Bool) -> EngineRuntimeTraits {
        EngineRuntimeTraits(
            surface: EngineSurfaceRuntimeTraits(continuesWithoutSurface: continuesWithoutSurface),
            stateAuthority: stateAuthority
        )
    }
}

public struct EngineSurfaceRuntimeTraits: Equatable, Sendable {
    /// 렌더 surface가 분리(백그라운드 진입 등)되어도 재생이 유지되는가.
    public let continuesWithoutSurface: Bool

    public static let `default` = EngineSurfaceRuntimeTraits()

    public init(continuesWithoutSurface: Bool = false) {
        self.continuesWithoutSurface = continuesWithoutSurface
    }
}

/// 엔진 명령 성공 후 `PlaybackState`를 누가 확정하는가.
///
/// - `engineEventsAreAuthoritative`: Kollus처럼 `playStarted`/`pauseStarted` 등 권위 콜백이
///   상태를 만든다. Core는 command-origin 입력을 추가하지 않는다.
/// - `commandSuccessClosesState`: Native처럼 권위 콜백이 부족한 엔진이다. Core가 명령 성공 직후
///   command-origin `PlaybackStateInput`을 reducer에 넣어 상태를 닫는다.
public enum EngineStateEventAuthority: Equatable, Sendable {
    case engineEventsAreAuthoritative
    case commandSuccessClosesState
}
