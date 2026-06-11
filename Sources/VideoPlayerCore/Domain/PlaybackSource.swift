//
//  PlaybackSource.swift
//  VideoPlayerModule
//
//  Created by 모바일팀_정준영 on 2026/04/17.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import Foundation

/// 재생 소스. Core는 벤더를 모르고, 엔진 어댑터가 자신이 지원하는 `Kind`만 해석한다.
public struct PlaybackSource: Equatable, Sendable {
    /// 소스 식별 방식.
    public enum Kind: Equatable, Sendable {
        /// 일반 URL (로컬 파일, HLS, progressive)
        case url(URL)
        /// 엔진 고유 콘텐츠 키 (예: media content key). 해석은 엔진 어댑터 책임.
        case mediaKey(String)
    }

    public let kind: Kind
    /// 엔진별 부가 힌트. 엔진은 모르는 키를 무시한다.
    public let options: [String: String]

    public init(kind: Kind, options: [String: String] = [:]) {
        self.kind = kind
        self.options = options
    }

    public static func url(_ url: URL) -> PlaybackSource {
        PlaybackSource(kind: .url(url))
    }

    public static func mediaKey(_ key: String) -> PlaybackSource {
        PlaybackSource(kind: .mediaKey(key))
    }
}
