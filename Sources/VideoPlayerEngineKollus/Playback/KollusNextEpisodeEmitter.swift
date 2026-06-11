//
//  KollusNextEpisodeEmitter.swift
//  VideoPlayerModule
//
//  Created by 모바일팀_정준영 on 2026/06/10.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import Foundation
import VideoPlayerCore

/// 다음 회차(next episode) 진입 시점 감시기.
///
/// 메타데이터는 `.readyToPlay` 시 MainActor에서 1회 캐시(arm)된다 — positionChanged
/// hot path가 매 신호마다 MainActor를 왕복하면 단일 FIFO consumer가 막혀 currentTime
/// 발행이 지연되기 때문. `takeDueInfo`는 동기·산술 전용이며 1회만 발화한다.
struct KollusNextEpisodeEmitter: Sendable {
    private struct Meta: Sendable {
        let showAt: TimeInterval
        let callbackURL: URL?
        let params: [String: String]
        let showsButton: Bool
    }

    private var meta: Meta?
    private var hasEmitted = false

    /// `.readyToPlay` 시 메타 캐시 + 발화 플래그 리셋.
    /// `showAt <= 0`(엔진 next-episode 없음)이면 비무장 — hot path 즉시 단락.
    mutating func arm(
        showAt: TimeInterval,
        callbackURL: URL?,
        params: [String: String],
        showsButton: Bool
    ) {
        hasEmitted = false
        guard showAt > 0 else {
            meta = nil
            return
        }
        meta = Meta(showAt: showAt, callbackURL: callbackURL, params: params, showsButton: showsButton)
    }

    /// 진입 시간 도달 시 1회 NextEpisodeInfo 반환, 그 외 nil. 동기·산술 전용.
    mutating func takeDueInfo(currentTime: TimeInterval) -> NextEpisodeInfo? {
        guard !hasEmitted, let meta else { return nil }
        guard currentTime >= meta.showAt else { return nil }
        guard let url = meta.callbackURL else { return nil }
        hasEmitted = true
        return NextEpisodeInfo(
            showAt: meta.showAt,
            callbackURL: url,
            callbackParameters: meta.params,
            showsButton: meta.showsButton
        )
    }
}
