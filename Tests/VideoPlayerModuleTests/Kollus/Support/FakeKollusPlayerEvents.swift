//
//  FakeKollusPlayerEvents.swift
//  VideoPlayerModuleTests
//
//  Created by 모바일개발팀_정준영 on 2026/05/15.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

#if canImport(UIKit)

import CoreGraphics
import Foundation
import VideoPlayerCore
@testable import VideoPlayerEngineKollus

/// 26 raw SDK 콜백 시뮬레이션 helper.
/// - KollusPlayerDelegate 23종: KollusEngineSignal payload 생성 → emit
/// - DRM 1종: kollus(didResolveDRM:response:error:) → observer
/// - LMS 1종: kollus(didPostLMS:result:) → observer
/// - Bookmark 1종: 사용자 북마크 리스트 → PlayerEvent.bookmarksDidLoad payload 변환
final class FakeKollusPlayerEvents {
    var signalSink: ((KollusEngineSignal) -> Void)?
    var observerDRMSink: ((_ request: [String: Any], _ response: [String: Any], _ error: Error?) -> Void)?
    var observerLMSSink: ((_ data: String, _ result: [String: Any]) -> Void)?
    var bookmarksSink: (([Bookmark]) -> Void)?

    init() {}

    // MARK: - KollusPlayerDelegate 23

    func emitPrepareToPlayCompleted(error: Error? = nil) { signalSink?(.prepareToPlayCompleted(error: error)) }
    func emitPlayStarted(userInteraction: Bool = true, error: Error? = nil) { signalSink?(.playStarted(userInteraction: userInteraction, error: error)) }
    func emitPauseStarted(userInteraction: Bool = true, error: Error? = nil) { signalSink?(.pauseStarted(userInteraction: userInteraction, error: error)) }
    func emitBufferingChanged(buffering: Bool, prepared: Bool = true, error: Error? = nil) { signalSink?(.bufferingChanged(buffering: buffering, prepared: prepared, error: error)) }
    func emitStopStarted(userInteraction: Bool = true, error: Error? = nil) { signalSink?(.stopStarted(userInteraction: userInteraction, error: error)) }
    func emitPositionChanged(time: TimeInterval, isSeeking: Bool = false) { signalSink?(.positionChanged(time: time, isSeeking: isSeeking)) }
    func emitScrollChanged(distance: CGPoint) { signalSink?(.scrollChanged(distance: distance)) }
    func emitZoomChanged(value: CGFloat) { signalSink?(.zoomChanged(value: value)) }
    func emitNaturalSizeResolved(size: CGSize) { signalSink?(.naturalSizeResolved(size: size)) }
    func emitContentModeChanged(mode: Int) { signalSink?(.contentModeChanged(mode: mode)) }
    func emitContentFrameChanged(frame: CGRect) { signalSink?(.contentFrameChanged(frame: frame)) }
    func emitPlaybackRateChanged(rate: Double) { signalSink?(.playbackRateChanged(rate: rate)) }
    func emitRepeatChanged(enabled: Bool) { signalSink?(.repeatChanged(enabled: enabled)) }
    func emitExternalOutputEnabledChanged(enabled: Bool) { signalSink?(.externalOutputEnabledChanged(enabled: enabled)) }
    func emitUnknownError(_ error: Error) { signalSink?(.unknownError(error)) }
    func emitFramerateResolved(framerate: Int) { signalSink?(.framerateResolved(framerate: framerate)) }
    func emitDevicePolicyLocked(playerType: Int) { signalSink?(.devicePolicyLocked(playerType: playerType)) }
    func emitCaptionUpdated(charset: String? = "UTF-8", caption: String) { signalSink?(.captionUpdated(charset: charset, caption: caption)) }
    func emitSubCaptionUpdated(charset: String? = "UTF-8", caption: String) { signalSink?(.subCaptionUpdated(charset: charset, caption: caption)) }
    func emitThumbnailReady(hasThumbnail: Bool, error: Error? = nil) { signalSink?(.thumbnailReady(hasThumbnail: hasThumbnail, error: error)) }
    func emitMediaContentKeyResolved(mck: String) { signalSink?(.mediaContentKeyResolved(mck: mck)) }
    func emitHLSHeightChanged(height: Int) { signalSink?(.hlsHeightChanged(height: height)) }
    func emitHLSBitrateChanged(bitrate: Int) { signalSink?(.hlsBitrateChanged(bitrate: bitrate)) }

    // MARK: - DRM / LMS / Bookmark 3

    func emitDRMResponse(request: [String: Any], response: [String: Any], error: Error? = nil) {
        observerDRMSink?(request, response, error)
    }

    func emitLMSPost(data: String, result: [String: Any]) {
        observerLMSSink?(data, result)
    }

    func emitBookmarks(_ bookmarks: [Bookmark]) {
        bookmarksSink?(bookmarks)
    }
}

#endif
