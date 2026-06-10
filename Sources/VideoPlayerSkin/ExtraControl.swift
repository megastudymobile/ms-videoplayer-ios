//
//  ExtraControl.swift
//  SmartPlayer
//
//  Created by 모바일팀_정준영 on 2026/05/29.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import Foundation

/// 재생기 skin 에 host(강의 등)가 주입하는 추가 버튼.
///
/// 재생기는 "id 를 가진 버튼이 있다" 만 알고, 그 버튼이 강의 무엇인지(북마크/인덱스)는
/// 모른다. 의미·tap 처리는 host 가 보유.
public struct ExtraControl: Equatable {
    /// skin 상 배치 슬롯.
    public enum Placement: Equatable {
        /// 상단 우측 메뉴 (Q&A 작성 등).
        case topMenu
        /// 가로 fullscreen / split 좌측 vertical 메뉴 (sectionRepeat 와 setting 사이).
        case leftMenu
        /// bottomBar 위 영상 우측 floating (다음 강의 등). title 버튼으로 렌더.
        case floating
    }

    public let id: String
    /// `.leftMenu` 는 아이콘 버튼(Asset Catalog 이름). `.floating` 은 빈 문자열 + `title` 사용.
    public let iconName: String
    public let selectedIconName: String?
    public let title: String
    public let placement: Placement
    public var isSelected: Bool

    public init(
        id: String,
        iconName: String,
        selectedIconName: String? = nil,
        title: String,
        placement: Placement,
        isSelected: Bool = false
    ) {
        self.id = id
        self.iconName = iconName
        self.selectedIconName = selectedIconName
        self.title = title
        self.placement = placement
        self.isSelected = isSelected
    }
}
