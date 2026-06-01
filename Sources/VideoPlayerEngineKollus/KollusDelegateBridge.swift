//
//  KollusDelegateBridge.swift
//  VideoPlayerModule
//
//  Created by 모바일개발팀_정준영 on 2026/05/15.
//  Updated on 2026/05/15 (Phase 3 refactor): SDK delegate 본문을 internal raw-handler 26개로 추출.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

#if canImport(UIKit) && canImport(KollusSDKBinary)

import CoreGraphics
import Foundation
import KollusSDKBinary
import UIKit
import VideoPlayerCore

/// 4종 KollusPlayer*Delegate를 단일 `@MainActor` 클래스로 묶어 SDK가 발행하는 26 raw callback을
/// `KollusEngineSignal`(23) + observer(DRM/LMS 2) + Bookmark 콜백(1)로 분배한다.
///
/// SDK delegate 메서드들은 internal `handle*` 메서드의 trampoline이다.
/// `handle*` 메서드는 `KollusPlayerView` 의존 없이 호출 가능해 단위 테스트가 매핑을 검증할 수 있다.
@MainActor
final class KollusDelegateBridge: NSObject,
    @preconcurrency KollusPlayerDelegate,
    @preconcurrency KollusPlayerDRMDelegate,
    @preconcurrency KollusPlayerLMSDelegate,
    @preconcurrency KollusPlayerBookmarkDelegate {

    private let onSignal: @MainActor (KollusEngineSignal) -> Void
    private let onBookmarks: @MainActor ([Bookmark]) -> Void
    private weak var observer: AnyObject?
    private weak var diagnostics: AnyObject?

    init(
        onSignal: @escaping @MainActor (KollusEngineSignal) -> Void,
        onBookmarks: @escaping @MainActor ([Bookmark]) -> Void,
        observer: KollusObserver?,
        diagnostics: KollusDiagnosticsSink?
    ) {
        self.onSignal = onSignal
        self.onBookmarks = onBookmarks
        self.observer = observer.map { $0 as AnyObject }
        self.diagnostics = diagnostics.map { $0 as AnyObject }
        super.init()
    }

    // MARK: - Internal raw handlers (KollusPlayerDelegate 23)

    func handlePrepareToPlayCompleted(error: Error?) {
        emit(.prepareToPlayCompleted(error: error))
    }

    func handlePlayStarted(userInteraction: Bool, error: Error?) {
        emit(.playStarted(userInteraction: userInteraction, error: error))
    }

    func handlePauseStarted(userInteraction: Bool, error: Error?) {
        emit(.pauseStarted(userInteraction: userInteraction, error: error))
    }

    func handleBufferingChanged(buffering: Bool, prepared: Bool, error: Error?) {
        emit(.bufferingChanged(buffering: buffering, prepared: prepared, error: error))
    }

    func handleStopStarted(userInteraction: Bool, error: Error?) {
        emit(.stopStarted(userInteraction: userInteraction, error: error))
    }

    func handlePositionChanged(time: TimeInterval, isSeeking: Bool) {
        emit(.positionChanged(time: time, isSeeking: isSeeking))
    }

    func handleScrollChanged(distance: CGPoint) {
        emit(.scrollChanged(distance: distance))
    }

    func handleZoomChanged(scale: CGFloat) {
        emit(.zoomChanged(value: scale))
    }

    func handleNaturalSizeResolved(size: CGSize) {
        emit(.naturalSizeResolved(size: size))
    }

    func handleContentModeChanged(mode: Int) {
        emit(.contentModeChanged(mode: mode))
    }

    func handleContentFrameChanged(frame: CGRect) {
        emit(.contentFrameChanged(frame: frame))
    }

    func handlePlaybackRateChanged(rate: Double) {
        emit(.playbackRateChanged(rate: rate))
    }

    func handleRepeatChanged(enabled: Bool) {
        emit(.repeatChanged(enabled: enabled))
    }

    func handleExternalOutputChanged(enabled: Bool) {
        emit(.externalOutputEnabledChanged(enabled: enabled))
    }

    func handleUnknownError(_ error: Error) {
        emit(.unknownError(error))
    }

    func handleFramerateResolved(framerate: Int) {
        emit(.framerateResolved(framerate: framerate))
    }

    func handleDevicePolicyLocked(playerType: Int) {
        emit(.devicePolicyLocked(playerType: playerType))
    }

    func handleCaptionUpdated(charset: String?, caption: String) {
        emit(.captionUpdated(charset: charset, caption: caption))
    }

    func handleSubCaptionUpdated(charset: String?, caption: String) {
        emit(.subCaptionUpdated(charset: charset, caption: caption))
    }

    func handleThumbnailReady(hasThumbnail: Bool, error: Error?) {
        emit(.thumbnailReady(hasThumbnail: hasThumbnail, error: error))
    }

    func handleMediaContentKeyResolved(mck: String) {
        emit(.mediaContentKeyResolved(mck: mck))
    }

    func handleHLSHeightChanged(height: Int) {
        emit(.hlsHeightChanged(height: height))
    }

    func handleHLSBitrateChanged(bitrate: Int) {
        emit(.hlsBitrateChanged(bitrate: bitrate))
    }

    // MARK: - Internal raw handlers (DRM/LMS/Bookmark 3)

    func handleDRMResponse(request: [String: Any], response: [String: Any], error: Error?) {
        if let observer = observer as? KollusObserver {
            observer.kollus(didResolveDRM: request, response: response, error: error)
        }
    }

    func handleLMSPost(data: String, result: [String: Any]) {
        if let observer = observer as? KollusObserver {
            observer.kollus(didPostLMS: data, result: result)
        }
    }

    /// 도메인 표현(`[Bookmark]`) 직접 forward. KollusBookmark→Bookmark 매핑은 SDK 메서드 본문이 수행.
    func handleBookmarks(_ bookmarks: [Bookmark]) {
        onBookmarks(bookmarks)
    }

    // MARK: - KollusPlayerDelegate trampolines (SDK 23)

    func kollusPlayerView(_ kollusPlayerView: KollusPlayerView, prepareToPlayWithError error: Error?) {
        handlePrepareToPlayCompleted(error: error)
    }

    func kollusPlayerView(_ kollusPlayerView: KollusPlayerView, play userInteraction: Bool, error: Error?) {
        handlePlayStarted(userInteraction: userInteraction, error: error)
    }

    func kollusPlayerView(_ kollusPlayerView: KollusPlayerView, pause userInteraction: Bool, error: Error?) {
        handlePauseStarted(userInteraction: userInteraction, error: error)
    }

    func kollusPlayerView(_ kollusPlayerView: KollusPlayerView, buffering: Bool, prepared: Bool, error: Error?) {
        handleBufferingChanged(buffering: buffering, prepared: prepared, error: error)
    }

    func kollusPlayerView(_ kollusPlayerView: KollusPlayerView, stop userInteraction: Bool, error: Error?) {
        handleStopStarted(userInteraction: userInteraction, error: error)
    }

    func kollusPlayerView(_ kollusPlayerView: KollusPlayerView, position: TimeInterval, error: Error?) {
        handlePositionChanged(time: position, isSeeking: kollusPlayerView.isSeeking)
    }

    func kollusPlayerView(_ kollusPlayerView: KollusPlayerView, scroll distance: CGPoint, error: Error?) {
        handleScrollChanged(distance: distance)
    }

    func kollusPlayerView(_ kollusPlayerView: KollusPlayerView, zoom recognizer: UIPinchGestureRecognizer, error: NSErrorPointer) {
        handleZoomChanged(scale: recognizer.scale)
    }

    func kollusPlayerView(_ kollusPlayerView: KollusPlayerView, naturalSize: CGSize) {
        handleNaturalSizeResolved(size: naturalSize)
    }

    func kollusPlayerView(_ kollusPlayerView: KollusPlayerView, playerContentMode: KollusPlayerContentMode, error: Error?) {
        handleContentModeChanged(mode: Int(playerContentMode.rawValue))
    }

    func kollusPlayerView(_ kollusPlayerView: KollusPlayerView, playerContentFrame: CGRect, error: Error?) {
        handleContentFrameChanged(frame: playerContentFrame)
    }

    func kollusPlayerView(_ kollusPlayerView: KollusPlayerView, playbackRate: Float, error: Error?) {
        handlePlaybackRateChanged(rate: Double(playbackRate))
    }

    func kollusPlayerView(_ kollusPlayerView: KollusPlayerView, repeat: Bool, error: Error?) {
        handleRepeatChanged(enabled: `repeat`)
    }

    func kollusPlayerView(_ kollusPlayerView: KollusPlayerView, enabledOutput: Bool, error: Error?) {
        handleExternalOutputChanged(enabled: enabledOutput)
    }

    func kollusPlayerView(_ kollusPlayerView: KollusPlayerView, unknownError: Error) {
        handleUnknownError(unknownError)
    }

    func kollusPlayerView(_ kollusPlayerView: KollusPlayerView, framerate: Int32) {
        handleFramerateResolved(framerate: Int(framerate))
    }

    func kollusPlayerView(_ kollusPlayerView: KollusPlayerView, lockedPlayer playerType: KollusPlayerType) {
        handleDevicePolicyLocked(playerType: Int(playerType.rawValue))
    }

    func kollusPlayerView(_ kollusPlayerView: KollusPlayerView, charset: UnsafeMutablePointer<CChar>, caption: UnsafeMutablePointer<CChar>) {
        let charsetString = String(cString: charset)
        let captionString = Self.string(fromCString: caption, charset: charsetString)
        handleCaptionUpdated(charset: charsetString, caption: captionString)
    }

    func kollusPlayerView(_ kollusPlayerView: KollusPlayerView, charsetSub: UnsafeMutablePointer<CChar>, captionSub: UnsafeMutablePointer<CChar>) {
        let charsetString = String(cString: charsetSub)
        let captionString = Self.string(fromCString: captionSub, charset: charsetString)
        handleSubCaptionUpdated(charset: charsetString, caption: captionString)
    }

    func kollusPlayerView(_ kollusPlayerView: KollusPlayerView, thumbnail isThumbnail: Bool, error: Error?) {
        handleThumbnailReady(hasThumbnail: isThumbnail, error: error)
    }

    func kollusPlayerView(_ kollusPlayerView: KollusPlayerView, mck: String) {
        handleMediaContentKeyResolved(mck: mck)
    }

    func kollusPlayerView(_ view: KollusPlayerView, height: Int32) {
        handleHLSHeightChanged(height: Int(height))
    }

    func kollusPlayerView(_ view: KollusPlayerView, bitrate: Int32) {
        handleHLSBitrateChanged(bitrate: Int(bitrate))
    }

    // MARK: - KollusPlayerDRMDelegate / LMS / Bookmark trampolines

    func kollusPlayerView(_ kollusPlayerView: KollusPlayerView, request: [AnyHashable: Any], json: [AnyHashable: Any], error: Error?) {
        handleDRMResponse(request: Self.normalize(request), response: Self.normalize(json), error: error)
    }

    func kollusPlayerView(_ kollusPlayerView: KollusPlayerView, lmsData: String, resultJson: [AnyHashable: Any]) {
        handleLMSPost(data: lmsData, result: Self.normalize(resultJson))
    }

    func kollusPlayerView(_ kollusPlayerView: KollusPlayerView, bookmark: [Any], enabled: Bool, error: Error?) {
        let mapped: [Bookmark] = bookmark.compactMap { raw in
            guard let kb = raw as? KollusBookmark else { return nil }
            return Bookmark(
                position: kb.position,
                title: Self.bookmarkTitle(from: kb),
                kind: kb.kind == .index ? .index : .user,
                createdAt: kb.time as Date?
            )
        }
        handleBookmarks(mapped)
    }

    // MARK: - Helpers

    private func emit(_ signal: KollusEngineSignal) {
        onSignal(signal)
        if let diagnostics = diagnostics as? KollusDiagnosticsSink {
            diagnostics.kollus(signal)
        }
    }

    private static func normalize(_ dict: [AnyHashable: Any]) -> [String: Any] {
        Dictionary(uniqueKeysWithValues: dict.compactMap { key, value -> (String, Any)? in
            guard let stringKey = key as? String else { return nil }
            return (stringKey, value)
        })
    }

    private static func bookmarkTitle(from bookmark: KollusBookmark) -> String {
        switch bookmark.kind {
        case .user:
            return bookmark.value ?? ""
        case .index:
            return bookmark.title ?? ""
        @unknown default:
            return bookmark.value ?? bookmark.title ?? ""
        }
    }

    private static func string(fromCString pointer: UnsafeMutablePointer<CChar>, charset: String) -> String {
        if let utf8 = String(validatingUTF8: pointer) {
            return utf8
        }
        let length = Int(strlen(pointer))
        let buffer = UnsafeBufferPointer(start: pointer, count: length)
        let data = Data(buffer: buffer)
        let encoding = Self.stringEncoding(for: charset)
        return String(data: data, encoding: encoding) ?? ""
    }

    private static func stringEncoding(for charset: String) -> String.Encoding {
        switch charset.lowercased() {
        case "utf-8", "utf8":
            return .utf8
        case "euc-kr", "euckr":
            return String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.EUC_KR.rawValue)))
        default:
            return .utf8
        }
    }
}

#endif
