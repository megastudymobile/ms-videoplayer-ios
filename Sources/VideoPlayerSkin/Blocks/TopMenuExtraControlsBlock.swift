//
//  TopMenuExtraControlsBlock.swift
//  VideoPlayerSkin
//
//  Created by 모바일팀_정준영 on 2026/06/02.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import UIKit

/// 상단 메뉴 앞쪽의 host 주입 버튼(placement .topMenu): Q&A 작성 등.
public final class TopMenuExtraControlsBlock: UIView, PlayerSkinBlock {
    public var view: UIView { self }
    public var onAction: ((PlayerSkinAction) -> Void)?

    private let stack = UIStackView()
    private var controls: [ExtraControl] = []
    private var buttons: [(id: String, button: UIButton)] = []
    private var needsRebuild = true

    public override init(frame: CGRect) {
        super.init(frame: frame)
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError() }

    public func setExtraControls(_ controls: [ExtraControl]) {
        self.controls = controls
        needsRebuild = true
    }

    public func render(_ state: PlayerSkinState, theme: PlayerSkinTheme) {
        rebuildButtonsIfNeeded(theme: theme)
        isHidden = state.isLocked || state.layoutMode != .fullScreen
        for entry in buttons {
            entry.button.isHidden = state.hiddenExtraControlIDs.contains(entry.id)
            entry.button.isEnabled = !state.isLocked
        }
    }

    private func rebuildButtonsIfNeeded(theme: PlayerSkinTheme) {
        guard needsRebuild else { return }
        buttons.forEach { $0.button.removeFromSuperview() }
        buttons.removeAll()

        for control in controls where control.placement == .topMenu {
            let button = PlayerSkinIconButtonFactory.make()
            PlayerSkinIconButtonFactory.apply(
                button,
                assetName: control.iconName,
                selectedAssetName: control.selectedIconName,
                isSelected: control.isSelected,
                fallbackTitle: control.title,
                theme: theme
            )
            button.accessibilityLabel = control.title
            button.accessibilityIdentifier = "lecturePlayer.skin.extra.\(control.id)"
            button.addTarget(self, action: #selector(tap(_:)), for: .touchUpInside)
            stack.addArrangedSubview(button)
            buttons.append((control.id, button))
        }
        needsRebuild = false
    }

    @objc private func tap(_ sender: UIButton) {
        guard let entry = buttons.first(where: { $0.button === sender }) else { return }
        onAction?(.extraControlTapped(id: entry.id))
    }
}
