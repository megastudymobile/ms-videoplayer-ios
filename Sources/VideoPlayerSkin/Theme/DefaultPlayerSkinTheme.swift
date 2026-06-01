//
//  DefaultPlayerSkinTheme.swift
//  VideoPlayerSkin
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import UIKit

/// 현 PlayerSkinControlView 의 하드코딩 룩 = 기본 테마.
/// 색/폰트는 protocol extension 기본값 사용. 아이콘은 패키지 번들(.module) → host 앱(.main) fallback
/// 으로 self-contained + 앱 커스텀 에셋 둘 다 지원.
public struct DefaultPlayerSkinTheme: PlayerSkinTheme {
    public init() {}

    public func image(assetName: String) -> UIImage? {
        UIImage(named: assetName, in: .module, with: nil)   // 패키지 기본 아이콘
            ?? UIImage(named: assetName)                     // host 앱 카탈로그 fallback
    }
}
