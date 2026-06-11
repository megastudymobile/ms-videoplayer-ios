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

// 엔진이 선택적으로 채택하는 기능별 ability 계약.
// 채택 여부는 `PlayerFeature.available(for:)`가 조사해 UI 버튼 노출로 이어진다.

public protocol EnginePlaybackRateAbility: Actor {
    func setPlaybackRate(_ rate: Double) async throws
}

public protocol EngineSubtitleAbility: Actor {
    func setSubtitleVisible(_ isVisible: Bool) async throws
    func selectSubtitleTrack(_ trackID: PlayerSubtitleTrackID?) async throws
    func setCaptionFontSize(_ fontSize: Int) async throws
}

public protocol EngineExternalSubtitleAbility: EngineSubtitleAbility {
    func selectSubtitleFile(_ fileURL: URL?) async throws
}

public protocol EngineBookmarkAbility: Actor {
    func addBookmark(at time: TimeInterval) async throws
}

public protocol EngineTitledBookmarkAbility: EngineBookmarkAbility {
    func addBookmark(at time: TimeInterval, title: String) async throws
    func removeBookmark(at time: TimeInterval) async throws
    func currentBookmarks() async -> [Bookmark]
}

public protocol EngineDisplayLockAbility: Actor {
    func setDisplayLocked(_ isLocked: Bool) async throws
}

public protocol EngineDisplayScalingAbility: Actor {
    func setDisplayScaleMode(_ mode: PlayerDisplayScaleMode) async throws
    func setDisplayScaled(_ isScaled: Bool) async throws
    func toggleDisplayScaleMode() async throws
    func toggleDisplayScaling() async throws
}

public protocol EngineDisplayAbility: EngineDisplayLockAbility, EngineDisplayScalingAbility {}

public protocol EngineScrollAbility: Actor {
    func scroll(by distance: CGPoint) async throws
    func stopScroll() async throws
}

public protocol EngineAdaptiveStreamingAbility: Actor {
    func changeBandwidth(_ bps: Int) async throws
    func streamInfoList() async -> [StreamInfo]
}

/// 현재 재생 중인 콘텐츠의 메타데이터(제목/썸네일 등) 조회 — NowPlaying 표시 등 부가 UI용.
public protocol EngineContentMetadataAbility: Actor {
    func currentContent() async -> DownloadedContent?
}

public protocol EnginePiPAbility: Actor {
    func startPiP() async throws
    func stopPiP() async throws
    var isPiPActive: Bool { get async }
}

#if canImport(UIKit)
public protocol EngineZoomAbility: Actor {
    func zoom(_ recognizer: UIPinchGestureRecognizer) async throws
    func setZoomOutDisabled(_ disabled: Bool) async
    func zoomValue() async -> CGFloat
    var isZoomedIn: Bool { get async }
}

/// 핀치 줌을 actor 비동기 hop 없이 **동기** 적용한다.
/// `EngineZoomAbility.zoom`(async)을 pinch `.changed` 마다 Task 로 호출하면 hop 지연·배칭으로
/// 연속 추적이 끊겨 "핀치 한 번에 한 단계"처럼 보인다. 제스처 추적은 매 이벤트 동기 적용이 필요하므로
/// host(shell)는 main thread 에서 본 메서드로 즉시 적용한다.
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
