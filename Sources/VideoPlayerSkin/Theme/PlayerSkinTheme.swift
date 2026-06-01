//
//  PlayerSkinTheme.swift
//  VideoPlayerSkin
//
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import UIKit

/// 재생기 skin 의 룩(색/폰트/아이콘) 토큰. Tier1 커스터마이즈 진입점.
///
/// ISP — 필요한 역할만 오버라이드하고 나머지는 기본값을 쓴다. 기본값 = 현 구현(parity).
/// 아이콘은 현 asset-name 기반(override 가능). 기본은 host 번들(Bundle.main)에서 로드.
public protocol PlayerSkinTheme {
    func color(_ role: PlayerSkinColorRole) -> UIColor
    func font(_ role: PlayerSkinFontRole) -> UIFont
    /// 의미 기반 아이콘 조회 (Tier1 교체점). 기본 = `defaultAssetName` → `image(assetName:)`.
    /// host 는 이것만 오버라이드해 built-in 아이콘을 재매핑한다(에셋 의존 역전).
    func icon(_ icon: PlayerSkinIcon) -> UIImage?
    /// host 주입 ExtraControl 등 동적 asset 이름 조회. nil 이면 호출부가 SF Symbol/텍스트 fallback.
    func image(assetName: String) -> UIImage?
}

public extension PlayerSkinTheme {
    func color(_ role: PlayerSkinColorRole) -> UIColor { role.defaultColor }
    func font(_ role: PlayerSkinFontRole) -> UIFont { role.defaultFont }
    func icon(_ icon: PlayerSkinIcon) -> UIImage? { image(assetName: icon.defaultAssetName) }
    func image(assetName: String) -> UIImage? { UIImage(named: assetName) }
}
