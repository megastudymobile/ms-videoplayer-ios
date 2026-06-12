//
//  PlayerPlaybackEngine.swift
//  VideoPlayerModule
//
//  Created by 모바일팀_정준영 on 2026/06/11.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import Foundation

/// 모든 재생 엔진의 필수 계약.
///
/// ## 용어
/// - `PlayerPlaybackEngine`: 단일 명령 싱크와 `outputStream`을 제공하는 필수 재생 계약
/// - `EngineRuntimeTraits`: Core가 정책 판단(백그라운드 유지, 명령 후 상태 확정 책임 등)에 쓰는
///   구조화된 엔진 동작 특성 — UI 기능 목록이 아니다
/// - `PlayerFeature`: 엔진의 `supports(_:)` 신고를 조사해(`available(for:)`) 산출하는
///   가용 기능 식별자 — Host/UI가 버튼 노출 결정에 쓴다
public protocol PlayerPlaybackEngine: Actor {
    nonisolated static var runtimeTraits: EngineRuntimeTraits { get }

    /// 엔진의 유일한 출력. Core가 소비해 reducer로 `PlaybackState`를 만든다.
    ///
    /// - Important: `outputStream`은 adapter lifetime 동안 **동일한 장수명 인스턴스**여야 하고,
    ///   teardown/deinit에서 `finish()`되어야 한다. 또한 `PlaybackStateInput`을 델타로 싣기 때문에
    ///   버퍼링은 **`.unbounded`**여야 한다. `bufferingNewest`로 두면 입력 손실이 영구 상태 desync를
    ///   만든다.
    var outputStream: AsyncStream<PlayerEngineOutput> { get }

    /// 단일 명령 싱크. 구현체는 모든 `PlaybackCommand` case를 명시 처리한다.
    /// 미지원 명령은 `PlayerError.unsupportedCommand`를 던진다.
    func handle(_ command: PlaybackCommand) async throws

    /// Host/UI 버튼 노출용 기능 지원 신고.
    nonisolated func supports(_ feature: PlayerFeature) -> Bool
}
