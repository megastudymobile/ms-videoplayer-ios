//
//  PlayerSkinBlueprint+Example.swift
//  VideoPlayerExample
//
//  Created by JunyoungJung on 2026/06/05.
//
//  Example 전용 skin 조립 — default blueprint(기존 블록 19종 배치) 기반에
//  커스텀 블록만 추가한다 (OCP: AssembledPlayerSkin 수정 없음).
//  세로/가로 노출 슬롯은 default의 verticalSplit/fullScreen 정의를 그대로 사용.
//

import VideoPlayerSkin

extension PlayerSkinBlueprint {
    @MainActor
    static var example: PlayerSkinBlueprint {
        var blueprint = PlayerSkinBlueprint.default
        // 라이브 배지 — topCenter 슬롯(제목 옆)에 추가.
        blueprint.blocks[.topCenter, default: []].append { LiveBadgeBlock() }
        return blueprint
    }
}
