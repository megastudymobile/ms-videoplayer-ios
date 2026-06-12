//
//  EngineAbilities.swift
//  VideoPlayerModule
//
//  Created by 모바일팀_정준영 on 2026/06/11.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import CoreGraphics
import Foundation
#if canImport(UIKit)
import UIKit
#endif

#if canImport(UIKit)
/// 핀치 줌을 actor 비동기 hop 없이 **동기** 적용한다.
/// 제스처 추적은 매 이벤트 동기 적용이 필요하므로 host(shell)는 main thread 에서 본 메서드로 즉시 적용한다.
/// 구현체는 반드시 main thread 에서 호출되는 것을 전제한다(내부에서 MainActor 단언).
public protocol EngineSynchronousZoomAbility {
    func applyZoomGesture(_ recognizer: UIPinchGestureRecognizer)
}

/// 시킹 스크럽 중 특정 시각의 프리뷰 프레임을 제공한다.
/// 실패 원인(스프라이트 없음/추출 실패/취소)은 UI에서 전부 동일한 라벨-only 폴백으로
/// 수렴하므로 throws 대신 nil로 통일한다.
public protocol EngineSeekPreviewAbility: Actor {
    func seekPreviewImage(at time: TimeInterval) async -> UIImage?
}
#endif
