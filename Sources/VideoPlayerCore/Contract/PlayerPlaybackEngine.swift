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
/// - `PlayerPlaybackEngine`: prepare/play/pause/seek/stop과 `outputStream`을 제공하는 필수 재생 계약
/// - `EngineRuntimeTraits`: Core가 정책 판단(백그라운드 유지, 명령 후 상태 확정 방식 등)에 쓰는
///   엔진 동작 특성 — UI 기능 목록이 아니다
/// - Ability protocol (`EnginePlaybackRateAbility` 등): 배속/자막/북마크처럼 엔진이
///   선택적으로 채택하는 기능별 계약
/// - `PlayerFeature`: ability protocol 채택 여부를 조사해(`available(for:)`) 산출하는
///   가용 기능 식별자 — Host/UI가 버튼 노출 결정에 쓴다
public protocol PlayerPlaybackEngine: Actor {
    nonisolated static var runtimeTraits: EngineRuntimeTraits { get }

    func prepare(source: PlaybackSource) async throws
    func play() async throws
    func pause() async throws
    func seek(to time: TimeInterval) async throws
    func stop(reason: PlayerStopReason) async throws

    /// 엔진의 유일한 출력. Core가 소비해 reducer로 `PlaybackState`를 만든다.
    ///
    /// - Important: `outputStream`은 adapter lifetime 동안 **동일한 장수명 인스턴스**여야 하고,
    ///   teardown/deinit에서 `finish()`되어야 한다. 또한 `PlaybackStateInput`을 델타로 싣기 때문에
    ///   버퍼링은 **`.unbounded`**여야 한다. `bufferingNewest`로 두면 입력 손실이 영구 상태 desync를
    ///   만든다.
    var outputStream: AsyncStream<PlayerEngineOutput> { get }
}
