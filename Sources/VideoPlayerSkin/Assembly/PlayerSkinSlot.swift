//
//  PlayerSkinSlot.swift
//  VideoPlayerSkin
//  Copyright © 2026 megastudyedu. All rights reserved.
//

/// 스켈레톤의 고정 영역. 위치는 패키지가 소유, 내용물은 blueprint 가 채운다.
public enum PlayerSkinSlot: Hashable, Sendable, CaseIterable {
    case topLeading, topCenter, topTrailing
    case centerControls                 // 영상 중앙 재생 클러스터 (backward/play/forward)
    case leftRail, rightRail            // 세로 메뉴 (fullscreen/split)
    case bottomBar                      // 진행 바 영역
    case floatingCenterTrailing         // 영상 중앙-우측 floating (배속)
    case floatingBottomTrailing         // bottomBar 위 우측 floating (다음 강의 등)
}
