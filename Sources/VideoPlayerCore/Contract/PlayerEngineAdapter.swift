//
//  PlayerEngineAdapter.swift
//  VideoPlayerModule
//
//  Created by 모바일팀_정준영 on 2026/04/17.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import CoreGraphics
import Foundation
#if canImport(UIKit)
import UIKit
#endif

public struct EngineCapabilities: OptionSet, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let continuesWithoutSurface = EngineCapabilities(rawValue: 1 << 0)
    public static let seamlessSurfaceSwap = EngineCapabilities(rawValue: 1 << 1)
    public static let nativePiP = EngineCapabilities(rawValue: 1 << 2)

    /// 엔진이 play/pause/seek 성공을 별도 observer 신호(권위 콜백)로 다시 통지하는가.
    ///
    /// - Kollus = `true`: `playStarted`/`pauseStarted` 등 콜백이 상태를 만든다. Core는 명령 성공 후
    ///   상태를 만들지 않고 outputStream의 `.stateInput`만 신뢰한다.
    /// - Native = `false`: `timeControlStatus(.playing)`은 play-started 상태 입력을 만들지 않으므로,
    ///   Core가 명령 성공 직후 command-origin `PlaybackStateInput`을 reducer에 넣어야 한다.
    ///
    /// 이 비트가 없으면 Native에서 play 성공 후 status가 `.playing`에 도달하지 못한다.
    public static let emitsObservedCommandState = EngineCapabilities(rawValue: 1 << 3)
}

public protocol PlayerPlaybackEngine: Actor {
    nonisolated static var capabilities: EngineCapabilities { get }

    func prepare(source: PlaybackSource) async throws
    func play() async throws
    func pause() async throws
    func seek(to time: TimeInterval) async throws
    func stop(reason: PlayerStopReason) async throws

    /// 엔진의 유일한 출력. Core가 소비해 reducer로 `PlaybackState`를 만든다.
    ///
    /// - Important: `outputStream`은 adapter lifetime 동안 **동일한 장수명 인스턴스**여야 하고,
    ///   teardown/deinit에서 `finish()`되어야 한다. 또한 `PlaybackStateInput`을 델타로 싣기 때문에
    ///   버퍼링은 **`.unbounded`**여야 한다. `bufferingNewest`로 두면 입력 손실이 영구 상태 desync를
    ///   만든다.
    var outputStream: AsyncStream<PlayerEngineOutput> { get }
}

public protocol PlayerPlaybackRateEngine: Actor {
    func setPlaybackRate(_ rate: Double) async throws
}

public protocol PlayerSubtitleEngine: Actor {
    func setSubtitleVisible(_ isVisible: Bool) async throws
    func selectSubtitleTrack(_ trackID: PlayerSubtitleTrackID?) async throws
    func setCaptionFontSize(_ fontSize: Int) async throws
}

public protocol PlayerBookmarkEngine: Actor {
    func addBookmark(at time: TimeInterval) async throws
}

public protocol PlayerTitledBookmarkEngine: PlayerBookmarkEngine {
    func addBookmark(at time: TimeInterval, title: String) async throws
    func removeBookmark(at time: TimeInterval) async throws
    func currentBookmarks() async -> [Bookmark]
}

public protocol PlayerExternalSubtitleEngine: PlayerSubtitleEngine {
    func selectSubtitleFile(_ fileURL: URL?) async throws
}

public protocol PlayerDisplayLockEngine: Actor {
    func setDisplayLocked(_ isLocked: Bool) async throws
}

public protocol PlayerDisplayScalingEngine: Actor {
    func setDisplayScaleMode(_ mode: PlayerDisplayScaleMode) async throws
    func setDisplayScaled(_ isScaled: Bool) async throws
    func toggleDisplayScaleMode() async throws
    func toggleDisplayScaling() async throws
}

public protocol PlayerDisplayEngine: PlayerDisplayLockEngine, PlayerDisplayScalingEngine {}

#if canImport(UIKit)
public protocol PlayerZoomEngine: Actor {
    func zoom(_ recognizer: UIPinchGestureRecognizer) async throws
    func setZoomOutDisabled(_ disabled: Bool) async
    func zoomValue() async -> CGFloat
    var isZoomedIn: Bool { get async }
}

/// 핀치 줌을 actor 비동기 hop 없이 **동기** 적용한다.
/// `PlayerZoomEngine.zoom`(async)을 pinch `.changed` 마다 Task 로 호출하면 hop 지연·배칭으로
/// 연속 추적이 끊겨 "핀치 한 번에 한 단계"처럼 보인다. 제스처 추적은 매 이벤트 동기 적용이 필요하므로
/// host(shell)는 main thread 에서 본 메서드로 즉시 적용한다.
/// 구현체는 반드시 main thread 에서 호출되는 것을 전제한다(내부에서 MainActor 단언).
public protocol PlayerSynchronousZoomEngine {
    func applyZoomGesture(_ recognizer: UIPinchGestureRecognizer)
}

/// 시킹 스크럽 중 특정 시각의 프리뷰 프레임을 제공한다.
/// 실패 원인(스프라이트 없음/추출 실패/취소)은 UI에서 전부 동일한 라벨-only 폴백으로
/// 수렴하므로 throws 대신 nil로 통일한다.
public protocol PlayerSeekPreviewEngine: Actor {
    func seekPreviewImage(at time: TimeInterval) async -> UIImage?
}
#endif

public protocol PlayerScrollEngine: Actor {
    func scroll(by distance: CGPoint) async throws
    func stopScroll() async throws
}

public protocol PlayerAdaptiveStreamingEngine: Actor {
    func changeBandwidth(_ bps: Int) async throws
    func streamInfoList() async -> [StreamInfo]
}

/// 현재 재생 중인 콘텐츠의 메타데이터(제목/썸네일 등) 조회 — NowPlaying 표시 등 부가 UI용.
public protocol PlayerContentMetadataEngine: Actor {
    func currentContent() async -> DownloadedContent?
}

public protocol PlayerPiPCapability: Actor {
    func startPiP() async throws
    func stopPiP() async throws
    var isPiPActive: Bool { get async }
}
