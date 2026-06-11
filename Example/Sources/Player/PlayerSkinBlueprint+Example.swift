//
//  PlayerSkinBlueprint+Example.swift
//  VideoPlayerExample
//
//  Created by JunyoungJung on 2026/06/05.
//
//  Example 전용 skin 조립 — default blueprint에 의존하지 않고 전체 배치를 직접 선언한다.
//  어떤 블록이 어디에, 어느 모드에 보이는지가 이 파일 한 곳에 전부 드러난다.
//  노출 조건(requiredFeatures)은 각 블록 타입이 신고한다 — 예: BookmarkButtonBlock.
//

import VideoPlayerSkin

extension PlayerSkinBlueprint {
    @MainActor
    static var example: PlayerSkinBlueprint {
        PlayerSkinBlueprint(
            blocks: [
                .topLeading: [{ CloseButtonBlock() }],
                .topCenter: [
                    { TitleBlock() },
                    { LiveBadgeBlock() }
                ],
                .topTrailing: [
                    { BookmarkButtonBlock() },
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
                    .topCenter,
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
