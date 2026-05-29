//
//  PlayerCaptionState.swift
//  SmartPlayer
//
//  Created by 모바일팀_정준영 on 2026/05/19.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import CoreGraphics
import Foundation

public struct PlayerCaptionState: Equatable {
    public var primaryText: String
    public var secondaryText: String
    public var fontSize: CGFloat
    public var isVisible: Bool

    public init(
        primaryText: String,
        secondaryText: String,
        fontSize: CGFloat,
        isVisible: Bool
    ) {
        self.primaryText = primaryText
        self.secondaryText = secondaryText
        self.fontSize = fontSize
        self.isVisible = isVisible
    }

    public static let initial = PlayerCaptionState(
        primaryText: "",
        secondaryText: "",
        fontSize: 16,
        isVisible: true
    )

    public var hasPrimaryCaption: Bool {
        primaryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    public var hasSecondaryCaption: Bool {
        secondaryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    public func updating(text: String, isSecondary: Bool) -> PlayerCaptionState {
        var nextState = self
        if isSecondary {
            nextState.secondaryText = text
        } else {
            nextState.primaryText = text
        }
        return nextState
    }
}
