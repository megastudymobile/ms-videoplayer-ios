//
//  PlayerFeature.swift
//  VideoPlayerModule
//
//  Created by JunyoungJung on 2026/06/11.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import Foundation

/// 엔진이 제공할 수 있는 부가 기능의 식별자.
///
/// 새 기능 추가 시 case만 추가하면 각 엔진의 `supports(_:)` / `PlayerFeaturePolicy.allows(_:)`의
/// exhaustive switch가 컴파일 에러로 갱신 지점을 전부 안내한다.
public enum PlayerFeature: CaseIterable, Sendable, Hashable {
    case playbackRate
    case subtitles
    case externalSubtitles
    case bookmarks
    case titledBookmarks
    case zoom
    case scroll
    case adaptiveStreaming
    case pictureInPicture
    case displayScaling
    case displayLock
    case seekPreview
}

public extension PlayerFeature {
    /// 엔진 인스턴스의 가용 기능 집합을 산출한다 — 전체 case 순회라 누락이 불가능하다.
    /// UI는 명령 실패를 기다리지 않고 이 값으로 버튼 노출을 사전 결정한다.
    static func available(for engine: any PlayerPlaybackEngine) -> Set<PlayerFeature> {
        Set(allCases.filter { engine.supports($0) })
    }
}
