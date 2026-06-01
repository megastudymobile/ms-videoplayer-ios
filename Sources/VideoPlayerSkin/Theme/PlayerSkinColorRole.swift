//
//  PlayerSkinColorRole.swift
//  VideoPlayerSkin
//
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import UIKit

/// skin 색상의 "역할". 기본값 = 현 PlayerSkinControlView 하드코딩 값(parity).
public enum PlayerSkinColorRole: Hashable, Sendable {
    case controlTint        // 아이콘/버튼 tint
    case progressFill       // 진행 바 채움
    case progressTrack      // 진행 바 트랙
    case barBackground      // 상/하단 바 배경
    case timeText           // 현재/총 시간 라벨

    public var defaultColor: UIColor {
        switch self {
        case .controlTint:   return .white
        case .progressFill:  return UIColor(named: "primarySkyBlue") ?? .systemBlue
        case .progressTrack: return UIColor(named: "Line/grey-03") ?? UIColor.white.withAlphaComponent(0.35)
        case .barBackground: return UIColor.black.withAlphaComponent(0.52)
        case .timeText:      return UIColor.white.withAlphaComponent(0.9)
        }
    }
}
