//
//  PlayerSkinBlueprint.swift
//  VideoPlayerSkin
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import UIKit

/// blueprint 에 등록되는 block 생성 함수.
/// UIKit view 는 한 부모에만 붙을 수 있으므로 blueprint 는 block 인스턴스가 아니라 factory 를 보관한다.
public typealias PlayerSkinBlockFactory = @MainActor () -> PlayerSkinBlock

/// 슬롯에 어떤 블럭을, 어떻게 배치하고, 어느 모드에 노출할지 정의.
public struct PlayerSkinBlueprint {
    public var blocks: [PlayerSkinSlot: [PlayerSkinBlockFactory]]
    public var layouts: [PlayerSkinSlot: PlayerSkinSlotLayout]
    public var visibleSlots: [PlayerSkinLayoutMode: Set<PlayerSkinSlot>]

    public init(blocks: [PlayerSkinSlot: [PlayerSkinBlockFactory]],
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
                .topLeading: [{ CloseButtonBlock() }],
                .topCenter: [{ TitleBlock() }],
                .topTrailing: [
                    { TopMenuExtraControlsBlock() },
                    { DisplayScaleBlock() },
                    { LockButtonBlock() },
                    { MoreButtonBlock() }
                ],
                .centerControls: [{ CenterPlaybackControlsBlock() }],
                .leftRail: [
                    { SectionRepeatBlock() },
                    { ExtraControlsRailBlock() },
                    { SettingButtonBlock() }
                ],
                .bottomBar: [{ ProgressBarBlock() }],
                .sectionRepeatRange: [{ SectionRepeatRangeBlock() }],
                .floatingCenterTrailing: [{ RateControlBlock() }],
                .floatingBottomTrailing: [{ ExtraFloatingBlock() }]
            ],
            layouts: [
                .topTrailing: .init(alignment: .center, spacing: 8),
                .centerControls: .init(alignment: .fill, spacing: 0),
                .leftRail: .init(alignment: .center, spacing: 0),
                .rightRail: .init(alignment: .center, spacing: 12)
            ],
            visibleSlots: [
                .verticalSplit: [
                    .topLeading,
                    .topTrailing,
                    .centerControls,
                    .bottomBar,
                    .floatingCenterTrailing,
                    .floatingBottomTrailing
                ],
                .horizontalSplit: [
                    .topLeading,
                    .topCenter,
                    .topTrailing,
                    .leftRail,
                    .centerControls,
                    .bottomBar,
                    .sectionRepeatRange,
                    .floatingCenterTrailing,
                    .floatingBottomTrailing
                ],
                .fullScreen: Set(PlayerSkinSlot.allCases)
            ]
        )
    }
}
