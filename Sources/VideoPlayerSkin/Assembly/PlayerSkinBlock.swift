//
//  PlayerSkinBlock.swift
//  VideoPlayerSkin
//
//  Created by 모바일팀_정준영 on 2026/06/11.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import UIKit
import VideoPlayerCore

/// 슬롯에 끼우는 컨트롤 단위. 상태 반영 + 액션 방출.
@MainActor
public protocol PlayerSkinBlock: AnyObject {
    var view: UIView { get }
    var onAction: ((PlayerSkinAction) -> Void)? { get set }
    /// 이 블록 노출에 필요한 feature 집합. 전부 충족해야 노출된다.
    /// 기본값 [] = 조건 없음 — apply(availableFeatures:) 게이팅 대상에서 제외.
    ///
    /// 계약:
    /// - 조립 후 값이 변하지 않아야 한다 (`let` 구현 권장) —
    ///   apply 는 호출 시점 값으로 게이팅하므로 런타임에 변하면 조용히 어긋난다.
    /// - 빈 집합이 아닌 값을 신고한 블록은 view.isHidden 을 직접 제어하지 않는다 —
    ///   소유권이 skin(apply)에 있다. 자체 가시성 연출이 필요하면 alpha 나 내부 subview 로.
    var requiredFeatures: Set<PlayerFeature> { get }
    func render(_ state: PlayerSkinState, theme: PlayerSkinTheme)
}

public extension PlayerSkinBlock {
    /// 대부분의 블록은 feature 무관 — 조건 있는 블록만 override 한다.
    var requiredFeatures: Set<PlayerFeature> { [] }
}

@MainActor
protocol PlayerSkinPlaybackControlBlock: PlayerSkinBlock {
    func renderPlaybackState(_ state: PlayerSkinState, theme: PlayerSkinTheme)
}
