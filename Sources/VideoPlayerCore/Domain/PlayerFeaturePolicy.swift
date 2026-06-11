//
//  PlayerFeaturePolicy.swift
//  VideoPlayerModule
//
//  Created by 모바일팀_정준영 on 2026/04/17.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import Foundation

public struct PlayerFeaturePolicy: Equatable, Sendable {
    public let allowsBackgroundPlayback: Bool
    /// `Double` 고정. `Float`을 경유하면 `Double(Float(1.4))` 같은 이진 부동소수 오차로
    /// 정책 상한 경계(1.4·1.6 등) 비교가 어긋난다.
    public let maxPlaybackRate: Double
    public let allowsAutoplay: Bool
    public let skipInterval: TimeInterval
    public let nextEpisodeButtonLeadTime: TimeInterval
    /// 시킹 스크럽 프리뷰 모달 사용 여부 — 플레이어 생성 시 host가 결정한다.
    /// 엔진이 `PlayerSeekPreviewEngine`을 지원해도 이 정책이 꺼져 있으면 표시하지 않는다.
    public let allowsSeekPreview: Bool

    public static let `default` = PlayerFeaturePolicy(
        allowsBackgroundPlayback: false,
        maxPlaybackRate: 2.0,
        allowsAutoplay: true,
        skipInterval: 10,
        nextEpisodeButtonLeadTime: 30
    )

    public init(
        allowsBackgroundPlayback: Bool,
        maxPlaybackRate: Double,
        allowsAutoplay: Bool,
        skipInterval: TimeInterval = 10,
        nextEpisodeButtonLeadTime: TimeInterval = 30,
        allowsSeekPreview: Bool = true
    ) {
        self.allowsBackgroundPlayback = allowsBackgroundPlayback
        self.maxPlaybackRate = maxPlaybackRate
        self.allowsAutoplay = allowsAutoplay
        self.skipInterval = skipInterval > 0 ? skipInterval : 10
        self.nextEpisodeButtonLeadTime = max(0, nextEpisodeButtonLeadTime)
        self.allowsSeekPreview = allowsSeekPreview
    }
}
