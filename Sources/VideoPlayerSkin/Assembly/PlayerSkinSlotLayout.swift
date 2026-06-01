//
//  PlayerSkinSlotLayout.swift
//  VideoPlayerSkin
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import UIKit

/// 슬롯 내부 배치 미세조정.
public struct PlayerSkinSlotLayout: Equatable, Sendable {
    public enum Align: Sendable { case leading, center, trailing, fill }

    public var alignment: Align
    public var spacing: CGFloat
    public var insets: UIEdgeInsets

    public init(alignment: Align = .center, spacing: CGFloat = 12, insets: UIEdgeInsets = .zero) {
        self.alignment = alignment
        self.spacing = spacing
        self.insets = insets
    }
}
