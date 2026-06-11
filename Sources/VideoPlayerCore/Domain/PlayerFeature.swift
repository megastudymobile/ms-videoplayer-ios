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
/// 새 기능 추가 시 case만 추가하면 `isSupported(by:)` / `PlayerFeaturePolicy.allows(_:)`의
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
    /// 엔진의 ability protocol 채택 여부 — 엔진 구현체가 별도 신고 없이
    /// protocol 채택만으로 협상에 참여하게 한다.
    /// default 없는 switch라 case 누락이 컴파일 에러로 드러난다.
    func isSupported(by engine: any PlayerPlaybackEngine) -> Bool {
        switch self {
        case .playbackRate:
            return engine is any EnginePlaybackRateAbility
        case .subtitles:
            return engine is any EngineSubtitleAbility
        case .externalSubtitles:
            return engine is any EngineExternalSubtitleAbility
        case .bookmarks:
            return engine is any EngineBookmarkAbility
        case .titledBookmarks:
            return engine is any EngineTitledBookmarkAbility
        case .scroll:
            return engine is any EngineScrollAbility
        case .adaptiveStreaming:
            return engine is any EngineAdaptiveStreamingAbility
        case .pictureInPicture:
            return engine is any EnginePiPAbility
        case .displayScaling:
            return engine is any EngineDisplayScalingAbility
        case .displayLock:
            return engine is any EngineDisplayLockAbility
        case .zoom:
            #if canImport(UIKit)
            return engine is any EngineZoomAbility
            #else
            return false
            #endif
        case .seekPreview:
            #if canImport(UIKit)
            return engine is any EngineSeekPreviewAbility
            #else
            return false
            #endif
        }
    }

    /// 엔진 인스턴스의 가용 기능 집합을 산출한다 — 전체 case 순회라 누락이 불가능하다.
    /// UI는 명령 실패를 기다리지 않고 이 값으로 버튼 노출을 사전 결정한다.
    static func available(for engine: any PlayerPlaybackEngine) -> Set<PlayerFeature> {
        Set(allCases.filter { $0.isSupported(by: engine) })
    }
}
