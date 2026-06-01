//
//  PlayerSkinBlueprint.swift
//  VideoPlayerSkin
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import UIKit

/// 슬롯에 어떤 블럭을, 어떻게 배치하고, 어느 모드에 노출할지 정의.
public struct PlayerSkinBlueprint {
    public var blocks: [PlayerSkinSlot: [() -> PlayerSkinBlock]]
    public var layouts: [PlayerSkinSlot: PlayerSkinSlotLayout]
    public var visibleSlots: [PlayerSkinLayoutMode: Set<PlayerSkinSlot>]

    public init(blocks: [PlayerSkinSlot: [() -> PlayerSkinBlock]],
                layouts: [PlayerSkinSlot: PlayerSkinSlotLayout] = [:],
                visibleSlots: [PlayerSkinLayoutMode: Set<PlayerSkinSlot>]) {
        self.blocks = blocks; self.layouts = layouts; self.visibleSlots = visibleSlots
    }
}

public extension PlayerSkinBlueprint {
    /// 기본 = 현 PlayerSkinControlView 배치 1:1 (0-config 동일 룩).
    static var `default`: PlayerSkinBlueprint {
        PlayerSkinBlueprint(
            blocks: [
                .topLeading:             [{ CloseButtonBlock() }],
                .topCenter:              [{ TitleBlock() }],
                .topTrailing:            [{ DisplayScaleBlock() }, { LockButtonBlock() }, { MoreButtonBlock() }],
                .centerControls:         [{ SkipButtonBlock(.backward) }, { PlayButtonBlock() }, { SkipButtonBlock(.forward) }],
                .leftRail:               [{ SectionRepeatBlock() }, { ExtraControlsRailBlock() }, { SettingButtonBlock() }],
                .rightRail:              [{ RateStepBlock(.up) }, { RateStepBlock(.down) }],
                .bottomBar:              [{ ProgressBarBlock() }],
                .floatingCenterTrailing: [{ RateButtonBlock() }],
                .floatingBottomTrailing: [{ ExtraFloatingBlock() }]
            ],
            layouts: [
                .topTrailing:    .init(alignment: .center, spacing: 4),
                .centerControls: .init(alignment: .center, spacing: 56),
                .leftRail:       .init(alignment: .center, spacing: 12),
                .rightRail:      .init(alignment: .center, spacing: 12)
            ],
            visibleSlots: [
                .verticalSplit:   [.topLeading, .topTrailing, .centerControls, .bottomBar,
                                   .floatingCenterTrailing, .floatingBottomTrailing],
                .horizontalSplit: [.topLeading, .topCenter, .topTrailing, .leftRail, .centerControls,
                                   .bottomBar, .floatingCenterTrailing, .floatingBottomTrailing],
                .fullScreen:      Set(PlayerSkinSlot.allCases)
            ]
        )
    }
}
