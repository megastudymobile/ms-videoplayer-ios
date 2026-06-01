//
//  PlayerSkinColorRole.swift
//  VideoPlayerSkin
//
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import UIKit

/// skin 색상의 "역할". 기본값은 `PlayerSkinTheme.default` 가 소유한다.
public enum PlayerSkinColorRole: Hashable, Sendable {
    case controlTint        // 아이콘/버튼 tint
    case progressFill       // 진행 바 채움
    case progressTrack      // 진행 바 트랙
    case barBackground      // 상/하단 바 배경
    case timeText           // 현재/총 시간 라벨
}
