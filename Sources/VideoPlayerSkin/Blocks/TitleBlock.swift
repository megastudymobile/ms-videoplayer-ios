//
//  TitleBlock.swift
//  VideoPlayerSkin
//
//  Created by 모바일팀_정준영 on 2026/06/11.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import UIKit

public final class TitleBlock: UIView, PlayerSkinBlock {
    public var view: UIView { self }
    public var onAction: ((PlayerSkinAction) -> Void)?
    private let label = UILabel()
    public override init(frame: CGRect) {
        super.init(frame: frame)
        label.lineBreakMode = .byTruncatingTail; label.numberOfLines = 1; label.textAlignment = .left
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor),
            label.trailingAnchor.constraint(equalTo: trailingAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)])
    }
    @available(*, unavailable) public required init?(coder: NSCoder) { fatalError() }
    public func setTitle(_ title: String) { label.text = title }

    public func render(_ state: PlayerSkinState, theme: PlayerSkinTheme) {
        label.textColor = theme.color(.controlTint)
        label.font = theme.font(.title)
    }
}
