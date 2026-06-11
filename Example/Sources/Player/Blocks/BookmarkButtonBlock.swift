//
//  BookmarkButtonBlock.swift
//  VideoPlayerExample
//
//  Created by JunyoungJung on 2026/06/11.
//
//  북마크 버튼 — requiredFeatures 신고로 .bookmarks 지원 엔진에서만 노출된다.
//  동작은 host route(_:)가 처리.
//

import UIKit
import VideoPlayerCore
import VideoPlayerSkin

@MainActor
final class BookmarkButtonBlock: PlayerSkinBlock {
    /// route(_:) 분기용 식별자 — 문자열 상수가 블록과 한 몸이라 분산되지 않는다.
    static let actionID = "bookmark"

    /// 기본값 [] override — 노출 조건이 blueprint 등록부와 무관하게 타입에 붙어 다닌다.
    let requiredFeatures: Set<PlayerFeature> = [.bookmarks]

    private let button = UIButton(type: .system)

    var view: UIView { button }
    var onAction: ((PlayerSkinAction) -> Void)?

    init() {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "bookmark"), for: .normal)
        button.tintColor = .white
        button.accessibilityLabel = "북마크"
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 44),
            button.heightAnchor.constraint(equalToConstant: 44)
        ])
        button.addAction(UIAction { [weak self] _ in
            self?.onAction?(.extraControlTapped(id: Self.actionID))
        }, for: .touchUpInside)
    }

    func render(_ state: PlayerSkinState, theme: PlayerSkinTheme) {
        // topTrailing 슬롯은 잠금 중에도 보이는 슬롯 — 버튼만 비활성 처리.
        button.isEnabled = state.isLocked == false
    }
}
