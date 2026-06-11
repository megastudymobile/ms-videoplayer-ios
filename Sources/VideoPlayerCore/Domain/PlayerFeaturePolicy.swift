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
    /// host가 주입하는 허용 배속 목록 — 오름차순으로 정규화해 보관한다.
    /// UI(슬라이더/프리셋)와 명령 검증이 같은 목록을 공유한다.
    /// `Double` 고정. `Float`을 경유하면 `Double(Float(1.4))` 같은 이진 부동소수 오차로
    /// 허용값 비교가 어긋나므로, 검증은 `allowsPlaybackRate(_:)`의 오차 허용 비교를 쓴다.
    public let allowedPlaybackRates: [Double]
    public let allowsAutoplay: Bool
    public let skipInterval: TimeInterval
    public let nextEpisodeButtonLeadTime: TimeInterval
    /// 시킹 스크럽 프리뷰 모달 사용 여부 — 플레이어 생성 시 host가 결정한다.
    /// 엔진이 `EngineSeekPreviewAbility`을 지원해도 이 정책이 꺼져 있으면 표시하지 않는다.
    public let allowsSeekPreview: Bool

    public static let `default` = PlayerFeaturePolicy(
        allowsBackgroundPlayback: false,
        allowedPlaybackRates: [0.5, 0.8, 1.0, 1.2, 1.5, 2.0],
        allowsAutoplay: true,
        skipInterval: 10,
        nextEpisodeButtonLeadTime: 30
    )

    public init(
        allowsBackgroundPlayback: Bool,
        allowedPlaybackRates: [Double],
        allowsAutoplay: Bool,
        skipInterval: TimeInterval = 10,
        nextEpisodeButtonLeadTime: TimeInterval = 30,
        allowsSeekPreview: Bool = true
    ) {
        self.allowsBackgroundPlayback = allowsBackgroundPlayback
        // 양수만, 중복 제거 후 오름차순. 비면 1.0배속만 허용해 재생 자체는 항상 가능하게 한다.
        let normalized = Array(Set(allowedPlaybackRates.filter { $0 > 0 })).sorted()
        self.allowedPlaybackRates = normalized.isEmpty ? [1.0] : normalized
        self.allowsAutoplay = allowsAutoplay
        self.skipInterval = skipInterval > 0 ? skipInterval : 10
        self.nextEpisodeButtonLeadTime = max(0, nextEpisodeButtonLeadTime)
        self.allowsSeekPreview = allowsSeekPreview
    }

    /// Skin이 Float 슬라이더 값을 Double로 되돌려 보내므로 이진 부동소수 오차를 흡수해 비교한다.
    public func allowsPlaybackRate(_ rate: Double) -> Bool {
        allowedPlaybackRates.contains { abs($0 - rate) < 0.001 }
    }

    /// 정책이 이 기능의 UI 노출을 허용하는가.
    /// default 없는 switch — 새 feature 추가 시 정책 판단을 컴파일러가 강제한다.
    public func allows(_ feature: PlayerFeature) -> Bool {
        switch feature {
        case .seekPreview:
            return allowsSeekPreview
        case .playbackRate, .subtitles, .externalSubtitles, .bookmarks,
             .titledBookmarks, .zoom, .scroll, .adaptiveStreaming,
             .pictureInPicture, .displayScaling, .displayLock:
            return true
        }
    }
}
