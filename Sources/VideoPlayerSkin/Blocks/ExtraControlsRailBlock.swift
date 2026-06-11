//
//  ExtraControlsRailBlock.swift
//  VideoPlayerSkin
//
//  Created by 모바일팀_정준영 on 2026/06/11.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import UIKit

/// leftRail 의 host 주입 추가버튼들(placement .leftMenu): 강의 인덱스/해설/북마크 등.
/// fullscreen 에서만 표시되며 hiddenExtraControlIDs 로 개별 숨김.
public final class ExtraControlsRailBlock: UIView, PlayerSkinBlock {
    public var view: UIView { self }
    public var onAction: ((PlayerSkinAction) -> Void)?

    private let stack = UIStackView()
    private var controls: [ExtraControl] = []
    private var buttons: [(id: String, button: UIButton)] = []
    private var needsRebuild = true

    public override init(frame: CGRect) {
        super.init(frame: frame)
        stack.axis = .vertical; stack.alignment = .center; stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }
    @available(*, unavailable) public required init?(coder: NSCoder) { fatalError() }

    /// host 주입 ExtraControl 중 placement == .leftMenu 만 buttons 로 구성.
    public func setExtraControls(_ controls: [ExtraControl]) {
        self.controls = controls
        needsRebuild = true
    }

    public func render(_ state: PlayerSkinState, theme: PlayerSkinTheme) {
        rebuildButtonsIfNeeded(theme: theme)
        stack.spacing = traitCollection.userInterfaceIdiom == .pad ? 10 : 0
        isHidden = state.isLocked || state.layoutMode != .fullScreen
        for entry in buttons {
            entry.button.isHidden = state.hiddenExtraControlIDs.contains(entry.id)
            entry.button.isEnabled = !state.isLocked
        }
    }

    private func rebuildButtonsIfNeeded(theme: PlayerSkinTheme) {
        guard needsRebuild else { return }
        buttons.forEach { $0.button.removeFromSuperview() }; buttons.removeAll()
        for control in controls where control.placement == .leftMenu {
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
            button.accessibilityIdentifier = "videoPlayer.skin.extra.\(control.id)"
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
