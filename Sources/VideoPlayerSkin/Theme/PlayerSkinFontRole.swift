//
//  PlayerSkinFontRole.swift
//  VideoPlayerSkin
//
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import UIKit

/// skin 폰트의 "역할". 기본값 = 현 하드코딩 값(parity).
public enum PlayerSkinFontRole: Hashable, Sendable {
    case title              // 상단 제목
    case time               // 시간 라벨 (monospaced)
    case rateLabel          // 배속 버튼
    case skipInterval       // seek "10" 오버레이
    case extraControlTitle  // floating 추가버튼 ("다음 강의")

    public var defaultFont: UIFont {
        switch self {
        case .title:             return .systemFont(ofSize: 16, weight: .regular)
        case .time:              return .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        case .rateLabel:         return .systemFont(ofSize: 13, weight: .semibold)
        case .skipInterval:      return .systemFont(ofSize: 12, weight: .semibold)
        case .extraControlTitle: return .systemFont(ofSize: 13, weight: .semibold)
        }
    }
}
