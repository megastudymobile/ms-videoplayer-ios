//
//  PlayerEngineAdapter.swift
//  VideoPlayerModule
//
//  Created by 모바일개발팀_정준영 on 2026/04/17.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
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
    /// (설계 문서 §5.2.1 명령별 상태 권위 매트릭스)
    public static let emitsObservedCommandState = EngineCapabilities(rawValue: 1 << 3)
}

public protocol PlayerPlaybackEngine: Actor {
    nonisolated static var capabilities: EngineCapabilities { get }

    func prepare(source: PlaybackSource) async throws
    func play() async throws
    func pause() async throws
    func seek(to time: TimeInterval) async throws
    func stop(reason: PlayerStopReason) async throws

    var currentState: PlaybackState { get }
    var eventStream: AsyncStream<PlayerEvent> { get }
}

/// B안 전환용 병행 계약. 엔진이 상태를 직접 노출(`currentState`/`eventStream`)하는 대신,
/// Core가 해석할 출력 스트림만 제공한다. 전환 기간에는 실제 adapter가
/// `PlayerPlaybackEngine & PlayerEngineOutputProducing`을 동시에 만족하고, `PlayerCore`만 먼저
/// `outputStream` 소비로 옮긴다. (설계 문서 §5.4 / §8 2단계)
///
/// - Important: `outputStream`은 adapter lifetime 동안 **동일한 장수명 인스턴스**여야 하고,
///   teardown/deinit에서 `finish()`되어야 한다. 또한 `PlaybackStateInput`을 델타로 싣기 때문에
///   버퍼링은 **`.unbounded`**여야 한다. `bufferingNewest`로 두면 입력 손실이 영구 상태 desync를
///   만든다. (설계 문서 §5.1)
public protocol PlayerEngineOutputProducing: Actor {
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
#endif

public protocol PlayerScrollEngine: Actor {
    func scroll(by distance: CGPoint) async throws
    func stopScroll() async throws
}

public protocol PlayerAdaptiveStreamingEngine: Actor {
    func changeBandwidth(_ bps: Int) async throws
    func streamInfoList() async -> [StreamInfo]
}

public protocol PlayerPiPCapability: Actor {
    func startPiP() async throws
    func stopPiP() async throws
    var isPiPActive: Bool { get async }
}
