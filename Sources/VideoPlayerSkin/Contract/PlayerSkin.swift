//
//  PlayerSkin.swift
//  VideoPlayerSkin
//
//  Created by 모바일팀_정준영 on 2026/06/01.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import UIKit

/// 재생기 컨트롤 UI 의 최상위 렌더 계약.
///
/// `view` 를 제공해 UIView 상속 강제는 피하고, UIView / UIViewController wrapper 구현을 모두
/// 허용한다. host 는 이 프로토콜로 skin 을 통째로 교체할 수 있다(Tier3). 기본 제공 구현은
/// `PlayerSkinControlView`(추후 `AssembledPlayerSkin`).
///
/// spec-064 후속 — VideoPlayerSkin 커스터마이즈 아키텍처
/// (`docs/player-skin-customization-architecture.md`).
@MainActor
public protocol PlayerSkin: AnyObject {
    /// host 가 컨테이너에 add 할 실제 뷰.
    var view: UIView { get }

    /// 사용자 컨트롤 입력 출력. host 가 reactor / usecase 로 매핑한다.
    var onAction: ((PlayerSkinAction) -> Void)? { get set }

    /// 1회 정적 구성 (제목 / 배속 상한).
    func configure(title: String, maxPlaybackRate: Double)

    /// 매 프레임 재생 상태 반영.
    func render(_ state: PlayerSkinState)

    /// host 주입 추가 버튼 (북마크 / 인덱스 / 다음 강의 등).
    func setExtraControls(_ controls: [ExtraControl])

    /// 스킵 간격 라벨 즉시 갱신.
    func updateSkipIntervalLabel(seconds: Int)
}
