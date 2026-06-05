//
//  LiveBadgeBlock.swift
//  VideoPlayerExample
//
//  Created by JunyoungJung on 2026/06/05.
//
//  라이브 스트림 표시 배지 — 기존 Blocks 19종에 없는 Example 커스텀 블록.
//  PlayerSkinBlock 3요소(view/onAction/render)만 구현, 상태는 갖지 않는다.
//

import UIKit
import VideoPlayerSkin

@MainActor
final class LiveBadgeBlock: PlayerSkinBlock {
    private let label = UILabel()

    var view: UIView { label }
    var onAction: ((PlayerSkinAction) -> Void)?

    init() {
        label.text = "LIVE"
        label.font = .systemFont(ofSize: 12, weight: .bold)
        label.textColor = .systemRed
        label.isHidden = true
    }

    func render(_ state: PlayerSkinState, theme: PlayerSkinTheme) {
        // isSeekEnabled=false = 라이브(또는 duration 미해석). 로딩 중 오표시는 isLoading으로 차단.
        label.isHidden = state.isSeekEnabled || state.isLoading
    }
}
