//
//  PlayerSkinFontRole.swift
//  VideoPlayerSkin
//
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import UIKit

/// skin 폰트의 "역할". 기본값은 `PlayerSkinTheme.default` 가 소유한다.
public enum PlayerSkinFontRole: Hashable, Sendable {
    case title              // 상단 제목
    case time               // 시간 라벨 (monospaced)
    case rateLabel          // 배속 버튼
    case skipInterval       // seek "10" 오버레이
    case extraControlTitle  // floating 추가버튼 ("다음 강의")
    case sectionRepeatRange // 구간 반복 시작/끝 버튼
    case caption            // 영상 자막
}
