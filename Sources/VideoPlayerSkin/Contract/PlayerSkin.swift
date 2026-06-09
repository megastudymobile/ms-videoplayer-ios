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

    /// 제스처/키보드 입력 피드백 HUD 표시. 제스처 인식과 의미 해석은 host Shell 이 담당한다.
    func showGestureHUD(icon: String, title: String, detail: String?, emphasized: Bool)

    /// long press 배속 유지처럼 자동 hide 없이 유지되는 배속 HUD 표시.
    func presentRateGestureHUD(_ rate: Double)

    /// 현재 표시 중인 제스처 HUD 숨김.
    func hideGestureHUD()

    /// SDK/엔진 caption event 를 공통 자막 overlay 에 반영.
    func updateCaption(text: String, isSecondary: Bool)

    /// 자막 폰트 크기 설정.
    func setCaptionFontSize(_ size: Int)

    /// 자막 overlay 가시성 설정.
    func setCaptionVisible(_ visible: Bool)

    /// 영상 하단으로부터의 기본 자막 여백 설정.
    func setCaptionBottomInset(_ inset: CGFloat)

    /// 실제 비디오 frame 변화 알림. 기본 skin 은 자막 bottom inset 값을 유지한다.
    func updateCaptionVideoFrame(_ frame: CGRect)
}

public extension PlayerSkin {
    func showGestureHUD(icon: String, title: String) {
        showGestureHUD(icon: icon, title: title, detail: nil, emphasized: false)
    }

    func showGestureHUD(icon: String, title: String, detail: String?) {
        showGestureHUD(icon: icon, title: title, detail: detail, emphasized: false)
    }
}
