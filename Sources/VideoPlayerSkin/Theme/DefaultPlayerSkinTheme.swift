//
//  DefaultPlayerSkinTheme.swift
//  VideoPlayerSkin
//
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import UIKit

/// 현 PlayerSkinControlView 의 하드코딩 룩 = 기본 테마.
/// 전부 protocol extension 기본값 사용 → 빈 구현으로 기존 동작 유지.
public struct DefaultPlayerSkinTheme: PlayerSkinTheme {
    public init() {}
}
