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
    /// Asset Catalog 이름으로 아이콘 조회. 커스텀 테마가 교체점. nil 이면 호출부가 SF Symbol/텍스트 fallback.
    func image(assetName: String) -> UIImage?
}

public extension PlayerSkinTheme {
    func color(_ role: PlayerSkinColorRole) -> UIColor { role.defaultColor }
    func font(_ role: PlayerSkinFontRole) -> UIFont { role.defaultFont }
    func image(assetName: String) -> UIImage? { UIImage(named: assetName) }
}
