//
//  PlayerEngineDescriptor.swift
//  VideoPlayerModule
//
//  Created by 모바일팀_정준영 on 2026/06/11.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import Foundation
import VideoPlayerCore

/// 엔진과 그 runtime traits를 한 단위로 묶는다.
/// traits를 별도 인자로 떠다니게 두면 엔진과 안 맞는 값을 넘길 수 있어, 조립 입력은 이 서술자로 받는다.
public struct PlayerEngineDescriptor: Sendable {
    public let engine: PlayerEngineAdapter
    public let runtimeTraits: EngineRuntimeTraits

    /// 환경/정책에 따라 엔진 타입 선언과 다른 traits를 쓰는 factory용
    /// (예: Kollus의 백그라운드 재생 정책이 `surface.continuesWithoutSurface`를 켠다).
    public init(engine: PlayerEngineAdapter, runtimeTraits: EngineRuntimeTraits) {
        self.engine = engine
        self.runtimeTraits = runtimeTraits
    }

    /// 엔진 타입이 선언한 traits를 그대로 쓰는 기본 서술자.
    public init(engine: PlayerEngineAdapter) {
        self.init(engine: engine, runtimeTraits: type(of: engine).runtimeTraits)
    }
}
