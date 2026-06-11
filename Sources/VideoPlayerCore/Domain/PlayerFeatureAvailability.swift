//
//  PlayerFeatureAvailability.swift
//  VideoPlayerModule
//
//  Created by 모바일팀_정준영 on 2026/06/10.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import Foundation

/// 현재 엔진이 실제로 지원하는 기능 집합. init 시점에 엔진의 optional protocol
/// 채택 여부로 산출된다 — UI는 명령 실패를 기다리지 않고 버튼 노출을 사전 결정한다.
public struct PlayerFeatureAvailability: OptionSet, Sendable, Equatable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let playbackRate      = PlayerFeatureAvailability(rawValue: 1 << 0)
    public static let subtitles         = PlayerFeatureAvailability(rawValue: 1 << 1)
    public static let externalSubtitles = PlayerFeatureAvailability(rawValue: 1 << 2)
    public static let bookmarks         = PlayerFeatureAvailability(rawValue: 1 << 3)
    public static let titledBookmarks   = PlayerFeatureAvailability(rawValue: 1 << 4)
    public static let zoom              = PlayerFeatureAvailability(rawValue: 1 << 5)
    public static let scroll            = PlayerFeatureAvailability(rawValue: 1 << 6)
    public static let adaptiveStreaming = PlayerFeatureAvailability(rawValue: 1 << 7)
    public static let pictureInPicture  = PlayerFeatureAvailability(rawValue: 1 << 8)
    public static let displayScaling    = PlayerFeatureAvailability(rawValue: 1 << 9)
    public static let displayLock       = PlayerFeatureAvailability(rawValue: 1 << 10)
    public static let seekPreview       = PlayerFeatureAvailability(rawValue: 1 << 11)
}

public extension PlayerFeatureAvailability {
    /// 엔진 인스턴스의 optional protocol 채택 여부를 조사해 가용 기능을 산출한다.
    /// 엔진 구현체가 별도 신고 없이 protocol 채택만으로 협상에 참여하게 한다.
    static func probe(_ engine: any PlayerPlaybackEngine) -> PlayerFeatureAvailability {
        var features: PlayerFeatureAvailability = []
        if engine is any EnginePlaybackRateAbility { features.insert(.playbackRate) }
        if engine is any EngineSubtitleAbility { features.insert(.subtitles) }
        if engine is any EngineExternalSubtitleAbility { features.insert(.externalSubtitles) }
        if engine is any EngineBookmarkAbility { features.insert(.bookmarks) }
        if engine is any EngineTitledBookmarkAbility { features.insert(.titledBookmarks) }
        if engine is any EngineScrollAbility { features.insert(.scroll) }
        if engine is any EngineAdaptiveStreamingAbility { features.insert(.adaptiveStreaming) }
        if engine is any EnginePiPAbility { features.insert(.pictureInPicture) }
        if engine is any EngineDisplayScalingAbility { features.insert(.displayScaling) }
        if engine is any EngineDisplayLockAbility { features.insert(.displayLock) }
        #if canImport(UIKit)
        if engine is any EngineZoomAbility { features.insert(.zoom) }
        if engine is any EngineSeekPreviewAbility { features.insert(.seekPreview) }
        #endif
        return features
    }
}
