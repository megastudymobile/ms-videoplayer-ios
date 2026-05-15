//
//  KollusDelegateBridgeMappingTests.swift
//  VideoPlayerModuleTests
//
//  Created by 모바일개발팀_정준영 on 2026/05/15.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

#if canImport(UIKit) && canImport(KollusSDKBinary)

import CoreGraphics
import Foundation
import VideoPlayerCore
import XCTest
@testable import VideoPlayerEngineKollus

/// 26 raw SDK 콜백 → KollusEngineSignal(23) + observer(DRM/LMS 2) + Bookmark(1) 매핑 검증.
@MainActor
final class KollusDelegateBridgeMappingTests: XCTestCase {

    // MARK: - Fixtures

    private final class CapturedSignals {
        var signals: [KollusEngineSignal] = []
        var bookmarks: [[Bookmark]] = []
    }

    private final class FakeObserver: KollusObserver {
        var drmCalls: [(request: [String: Any], response: [String: Any])] = []
        var lmsCalls: [(data: String, result: [String: Any])] = []

        func kollus(didResolveDRM request: [String: Any], response: [String: Any], error: Error?) {
            drmCalls.append((request, response))
        }
        func kollus(didPostLMS data: String, result: [String: Any]) {
            lmsCalls.append((data, result))
        }
        func kollusStorage(didCompleteStoredLMS success: Int, failure: Int) {}
    }

    private final class FakeDiagnostics: KollusDiagnosticsSink {
        var signals: [KollusEngineSignal] = []
        func kollus(_ signal: KollusEngineSignal) { signals.append(signal) }
    }

    private func makeBridge(
        capture: CapturedSignals,
        observer: KollusObserver? = nil,
        diagnostics: KollusDiagnosticsSink? = nil
    ) -> KollusDelegateBridge {
        KollusDelegateBridge(
            onSignal: { capture.signals.append($0) },
            onBookmarks: { capture.bookmarks.append($0) },
            observer: observer,
            diagnostics: diagnostics
        )
    }

    // MARK: - KollusPlayerDelegate 23 mappings

    func test_prepareToPlayCompleted_nilError() {
        let capture = CapturedSignals()
        makeBridge(capture: capture).handlePrepareToPlayCompleted(error: nil)
        guard case .prepareToPlayCompleted(let error) = capture.signals[0] else { return XCTFail() }
        XCTAssertNil(error)
    }

    func test_prepareToPlayCompleted_withError() {
        let capture = CapturedSignals()
        makeBridge(capture: capture).handlePrepareToPlayCompleted(error: NSError(domain: "t", code: 42))
        guard case .prepareToPlayCompleted(let error) = capture.signals[0] else { return XCTFail() }
        XCTAssertEqual((error as NSError?)?.code, 42)
    }

    func test_playStarted() {
        let capture = CapturedSignals()
        makeBridge(capture: capture).handlePlayStarted(userInteraction: true, error: nil)
        guard case .playStarted(let ui, _) = capture.signals[0] else { return XCTFail() }
        XCTAssertTrue(ui)
    }

    func test_pauseStarted() {
        let capture = CapturedSignals()
        makeBridge(capture: capture).handlePauseStarted(userInteraction: false, error: nil)
        guard case .pauseStarted(let ui, _) = capture.signals[0] else { return XCTFail() }
        XCTAssertFalse(ui)
    }

    func test_bufferingChanged() {
        let capture = CapturedSignals()
        makeBridge(capture: capture).handleBufferingChanged(buffering: true, prepared: true, error: nil)
        guard case .bufferingChanged(let buffering, let prepared, _) = capture.signals[0] else { return XCTFail() }
        XCTAssertTrue(buffering)
        XCTAssertTrue(prepared)
    }

    func test_stopStarted() {
        let capture = CapturedSignals()
        makeBridge(capture: capture).handleStopStarted(userInteraction: true, error: nil)
        guard case .stopStarted(let ui, _) = capture.signals[0] else { return XCTFail() }
        XCTAssertTrue(ui)
    }

    func test_positionChanged() {
        let capture = CapturedSignals()
        makeBridge(capture: capture).handlePositionChanged(time: 12.5, isSeeking: false)
        guard case .positionChanged(let time, let isSeeking) = capture.signals[0] else { return XCTFail() }
        XCTAssertEqual(time, 12.5)
        XCTAssertFalse(isSeeking)
    }

    func test_scrollChanged() {
        let capture = CapturedSignals()
        makeBridge(capture: capture).handleScrollChanged(distance: CGPoint(x: 10, y: 20))
        guard case .scrollChanged(let distance) = capture.signals[0] else { return XCTFail() }
        XCTAssertEqual(distance, CGPoint(x: 10, y: 20))
    }

    func test_zoomChanged() {
        let capture = CapturedSignals()
        makeBridge(capture: capture).handleZoomChanged(scale: 1.5)
        guard case .zoomChanged(let value) = capture.signals[0] else { return XCTFail() }
        XCTAssertEqual(value, 1.5)
    }

    func test_naturalSizeResolved() {
        let capture = CapturedSignals()
        makeBridge(capture: capture).handleNaturalSizeResolved(size: CGSize(width: 1920, height: 1080))
        guard case .naturalSizeResolved(let size) = capture.signals[0] else { return XCTFail() }
        XCTAssertEqual(size, CGSize(width: 1920, height: 1080))
    }

    func test_contentModeChanged() {
        let capture = CapturedSignals()
        makeBridge(capture: capture).handleContentModeChanged(mode: 2)
        guard case .contentModeChanged(let mode) = capture.signals[0] else { return XCTFail() }
        XCTAssertEqual(mode, 2)
    }

    func test_contentFrameChanged() {
        let capture = CapturedSignals()
        let frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        makeBridge(capture: capture).handleContentFrameChanged(frame: frame)
        guard case .contentFrameChanged(let f) = capture.signals[0] else { return XCTFail() }
        XCTAssertEqual(f, frame)
    }

    func test_playbackRateChanged() {
        let capture = CapturedSignals()
        makeBridge(capture: capture).handlePlaybackRateChanged(rate: 1.5)
        guard case .playbackRateChanged(let rate) = capture.signals[0] else { return XCTFail() }
        XCTAssertEqual(rate, 1.5)
    }

    func test_repeatChanged() {
        let capture = CapturedSignals()
        makeBridge(capture: capture).handleRepeatChanged(enabled: true)
        guard case .repeatChanged(let enabled) = capture.signals[0] else { return XCTFail() }
        XCTAssertTrue(enabled)
    }

    func test_externalOutputChanged() {
        let capture = CapturedSignals()
        makeBridge(capture: capture).handleExternalOutputChanged(enabled: true)
        guard case .externalOutputEnabledChanged(let enabled) = capture.signals[0] else { return XCTFail() }
        XCTAssertTrue(enabled)
    }

    func test_unknownError() {
        let capture = CapturedSignals()
        makeBridge(capture: capture).handleUnknownError(NSError(domain: "t", code: 99))
        guard case .unknownError(let error) = capture.signals[0] else { return XCTFail() }
        XCTAssertEqual((error as NSError).code, 99)
    }

    func test_framerateResolved() {
        let capture = CapturedSignals()
        makeBridge(capture: capture).handleFramerateResolved(framerate: 60)
        guard case .framerateResolved(let framerate) = capture.signals[0] else { return XCTFail() }
        XCTAssertEqual(framerate, 60)
    }

    func test_devicePolicyLocked() {
        let capture = CapturedSignals()
        makeBridge(capture: capture).handleDevicePolicyLocked(playerType: 1)
        guard case .devicePolicyLocked(let playerType) = capture.signals[0] else { return XCTFail() }
        XCTAssertEqual(playerType, 1)
    }

    func test_captionUpdated() {
        let capture = CapturedSignals()
        makeBridge(capture: capture).handleCaptionUpdated(charset: "UTF-8", caption: "hello")
        guard case .captionUpdated(let charset, let caption) = capture.signals[0] else { return XCTFail() }
        XCTAssertEqual(charset, "UTF-8")
        XCTAssertEqual(caption, "hello")
    }

    func test_subCaptionUpdated() {
        let capture = CapturedSignals()
        makeBridge(capture: capture).handleSubCaptionUpdated(charset: "UTF-8", caption: "sub")
        guard case .subCaptionUpdated(let charset, let caption) = capture.signals[0] else { return XCTFail() }
        XCTAssertEqual(charset, "UTF-8")
        XCTAssertEqual(caption, "sub")
    }

    func test_thumbnailReady() {
        let capture = CapturedSignals()
        makeBridge(capture: capture).handleThumbnailReady(hasThumbnail: true, error: nil)
        guard case .thumbnailReady(let hasThumbnail, _) = capture.signals[0] else { return XCTFail() }
        XCTAssertTrue(hasThumbnail)
    }

    func test_mediaContentKeyResolved() {
        let capture = CapturedSignals()
        makeBridge(capture: capture).handleMediaContentKeyResolved(mck: "mck-123")
        guard case .mediaContentKeyResolved(let mck) = capture.signals[0] else { return XCTFail() }
        XCTAssertEqual(mck, "mck-123")
    }

    func test_hlsHeightChanged() {
        let capture = CapturedSignals()
        makeBridge(capture: capture).handleHLSHeightChanged(height: 720)
        guard case .hlsHeightChanged(let height) = capture.signals[0] else { return XCTFail() }
        XCTAssertEqual(height, 720)
    }

    func test_hlsBitrateChanged() {
        let capture = CapturedSignals()
        makeBridge(capture: capture).handleHLSBitrateChanged(bitrate: 4_500_000)
        guard case .hlsBitrateChanged(let bitrate) = capture.signals[0] else { return XCTFail() }
        XCTAssertEqual(bitrate, 4_500_000)
    }

    // MARK: - DRM / LMS / Bookmark 3

    func test_drmResponse_forwardsToObserver() {
        let capture = CapturedSignals()
        let observer = FakeObserver()
        let bridge = makeBridge(capture: capture, observer: observer)

        bridge.handleDRMResponse(
            request: ["url": "https://example.com/drm"],
            response: ["status": 200],
            error: nil
        )

        XCTAssertEqual(observer.drmCalls.count, 1)
        XCTAssertEqual(observer.drmCalls[0].request["url"] as? String, "https://example.com/drm")
        XCTAssertEqual(observer.drmCalls[0].response["status"] as? Int, 200)
        XCTAssertTrue(capture.signals.isEmpty)
    }

    func test_lmsPost_forwardsToObserver() {
        let capture = CapturedSignals()
        let observer = FakeObserver()
        let bridge = makeBridge(capture: capture, observer: observer)

        bridge.handleLMSPost(data: "progress=50", result: ["ok": true])

        XCTAssertEqual(observer.lmsCalls.count, 1)
        XCTAssertEqual(observer.lmsCalls[0].data, "progress=50")
        XCTAssertEqual(observer.lmsCalls[0].result["ok"] as? Bool, true)
    }

    func test_bookmarks_forwardsToBookmarkCallback() {
        let capture = CapturedSignals()
        let bridge = makeBridge(capture: capture)
        let bookmarks = [
            Bookmark(position: 10, title: "intro", kind: .user),
            Bookmark(position: 20, title: "chapter1", kind: .index)
        ]

        bridge.handleBookmarks(bookmarks)

        XCTAssertEqual(capture.bookmarks.count, 1)
        XCTAssertEqual(capture.bookmarks[0], bookmarks)
    }

    // MARK: - nil observer / nil diagnostics

    func test_nilObserver_drmCallIsNoOp() {
        let capture = CapturedSignals()
        let bridge = makeBridge(capture: capture, observer: nil)

        bridge.handleDRMResponse(request: [:], response: [:], error: nil)
        bridge.handleLMSPost(data: "x", result: [:])

        XCTAssertTrue(capture.signals.isEmpty)
    }

    func test_nilDiagnostics_signalsStillForwardedToOnSignal() {
        let capture = CapturedSignals()
        let bridge = makeBridge(capture: capture, diagnostics: nil)

        bridge.handlePlayStarted(userInteraction: true, error: nil)

        XCTAssertEqual(capture.signals.count, 1)
    }

    func test_withDiagnostics_signalsForwardedToBothChannels() {
        let capture = CapturedSignals()
        let diagnostics = FakeDiagnostics()
        let bridge = makeBridge(capture: capture, diagnostics: diagnostics)

        bridge.handlePlayStarted(userInteraction: false, error: nil)
        bridge.handleHLSHeightChanged(height: 1080)

        XCTAssertEqual(capture.signals.count, 2)
        XCTAssertEqual(diagnostics.signals.count, 2)
    }
}

#endif
