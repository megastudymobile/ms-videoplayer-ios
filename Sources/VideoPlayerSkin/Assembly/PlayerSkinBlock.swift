//
//  PlayerSkinBlock.swift
//  VideoPlayerSkin
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import UIKit

/// 슬롯에 끼우는 컨트롤 단위. 상태 반영 + 액션 방출.
@MainActor
public protocol PlayerSkinBlock: AnyObject {
    var view: UIView { get }
    var onAction: ((PlayerSkinAction) -> Void)? { get set }
    var theme: PlayerSkinTheme { get set }
    func didInjectTheme()
    func render(_ state: PlayerSkinState)
}

public extension PlayerSkinBlock {
    func didInjectTheme() {}
}
