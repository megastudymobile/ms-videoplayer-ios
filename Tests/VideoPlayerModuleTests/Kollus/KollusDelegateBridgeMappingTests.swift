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
import Testing
@testable import VideoPlayerEngineKollus

/// 26 raw SDK 콜백 → KollusEngineSignal(23) + observer(DRM/LMS 2) + Bookmark(1) 매핑 검증.
@MainActor
@Suite("KollusDelegateBridge raw SDK 콜백 → signal 매핑")
struct KollusDelegateBridgeMappingTests {

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

    @Test("prepareToPlayCompleted nil error 매핑")
    func prepareToPlayCompleted_nilError() {
        let capture = CapturedSignals()
        makeBridge(capture: capture).handlePrepareToPlayCompleted(error: nil)
        guard case .prepareToPlayCompleted(let error) = capture.signals[0] else { Issue.record(); return }
        #expect(error == nil)
    }

    @Test("prepareToPlayCompleted error 매핑")
    func prepareToPlayCompleted_withError() {
        let capture = CapturedSignals()
        makeBridge(capture: capture).handlePrepareToPlayCompleted(error: NSError(domain: "t", code: 42))
        guard case .prepareToPlayCompleted(let error) = capture.signals[0] else { Issue.record(); return }
        #expect((error as NSError?)?.code == 42)
    }

    @Test("playStarted 매핑")
    func playStarted() {
        let capture = CapturedSignals()
        makeBridge(capture: capture).handlePlayStarted(userInteraction: true, error: nil)
        guard case .playStarted(let ui, _) = capture.signals[0] else { Issue.record(); return }
        #expect(ui)
    }

    @Test("pauseStarted 매핑")
    func pauseStarted() {
        let capture = CapturedSignals()
        makeBridge(capture: capture).handlePauseStarted(userInteraction: false, error: nil)
        guard case .pauseStarted(let ui, _) = capture.signals[0] else { Issue.record(); return }
        #expect(!(ui))
    }

    @Test("bufferingChanged 매핑")
    func bufferingChanged() {
        let capture = CapturedSignals()
        makeBridge(capture: capture).handleBufferingChanged(buffering: true, prepared: true, error: nil)
        guard case .bufferingChanged(let buffering, let prepared, _) = capture.signals[0] else { Issue.record(); return }
        #expect(buffering)
        #expect(prepared)
    }

    @Test("stopStarted 매핑")
    func stopStarted() {
        let capture = CapturedSignals()
        makeBridge(capture: capture).handleStopStarted(userInteraction: true, error: nil)
        guard case .stopStarted(let ui, _) = capture.signals[0] else { Issue.record(); return }
        #expect(ui)
    }

    @Test("positionChanged 매핑")
    func positionChanged() {
        let capture = CapturedSignals()
        makeBridge(capture: capture).handlePositionChanged(time: 12.5, isSeeking: false)
        guard case .positionChanged(let time, let isSeeking) = capture.signals[0] else { Issue.record(); return }
        #expect(time == 12.5)
        #expect(!(isSeeking))
    }

    @Test("scrollChanged 매핑")
    func scrollChanged() {
        let capture = CapturedSignals()
        makeBridge(capture: capture).handleScrollChanged(distance: CGPoint(x: 10, y: 20))
        guard case .scrollChanged(let distance) = capture.signals[0] else { Issue.record(); return }
        #expect(distance == CGPoint(x: 10, y: 20))
    }

    @Test("zoomChanged 매핑")
    func zoomChanged() {
        let capture = CapturedSignals()
        makeBridge(capture: capture).handleZoomChanged(scale: 1.5)
        guard case .zoomChanged(let value) = capture.signals[0] else { Issue.record(); return }
        #expect(value == 1.5)
    }

    @Test("naturalSizeResolved 매핑")
    func naturalSizeResolved() {
        let capture = CapturedSignals()
        makeBridge(capture: capture).handleNaturalSizeResolved(size: CGSize(width: 1920, height: 1080))
        guard case .naturalSizeResolved(let size) = capture.signals[0] else { Issue.record(); return }
        #expect(size == CGSize(width: 1920, height: 1080))
    }

    @Test("contentModeChanged 매핑")
    func contentModeChanged() {
        let capture = CapturedSignals()
        makeBridge(capture: capture).handleContentModeChanged(mode: 2)
        guard case .contentModeChanged(let mode) = capture.signals[0] else { Issue.record(); return }
        #expect(mode == 2)
    }

    @Test("contentFrameChanged 매핑")
    func contentFrameChanged() {
        let capture = CapturedSignals()
        let frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        makeBridge(capture: capture).handleContentFrameChanged(frame: frame)
        guard case .contentFrameChanged(let f) = capture.signals[0] else { Issue.record(); return }
        #expect(f == frame)
    }

    @Test("playbackRateChanged 매핑")
    func playbackRateChanged() {
        let capture = CapturedSignals()
        makeBridge(capture: capture).handlePlaybackRateChanged(rate: 1.5)
        guard case .playbackRateChanged(let rate) = capture.signals[0] else { Issue.record(); return }
        #expect(rate == 1.5)
    }

    @Test("repeatChanged 매핑")
    func repeatChanged() {
        let capture = CapturedSignals()
        makeBridge(capture: capture).handleRepeatChanged(enabled: true)
        guard case .repeatChanged(let enabled) = capture.signals[0] else { Issue.record(); return }
        #expect(enabled)
    }

    @Test("externalOutputChanged 매핑")
    func externalOutputChanged() {
        let capture = CapturedSignals()
        makeBridge(capture: capture).handleExternalOutputChanged(enabled: true)
        guard case .externalOutputEnabledChanged(let enabled) = capture.signals[0] else { Issue.record(); return }
        #expect(enabled)
    }

    @Test("unknownError 매핑")
    func unknownError() {
        let capture = CapturedSignals()
        makeBridge(capture: capture).handleUnknownError(NSError(domain: "t", code: 99))
        guard case .unknownError(let error) = capture.signals[0] else { Issue.record(); return }
        #expect((error as NSError).code == 99)
    }

    @Test("framerateResolved 매핑")
    func framerateResolved() {
        let capture = CapturedSignals()
        makeBridge(capture: capture).handleFramerateResolved(framerate: 60)
        guard case .framerateResolved(let framerate) = capture.signals[0] else { Issue.record(); return }
        #expect(framerate == 60)
    }

    @Test("devicePolicyLocked 매핑")
    func devicePolicyLocked() {
        let capture = CapturedSignals()
        makeBridge(capture: capture).handleDevicePolicyLocked(playerType: 1)
        guard case .devicePolicyLocked(let playerType) = capture.signals[0] else { Issue.record(); return }
        #expect(playerType == 1)
    }

    @Test("captionUpdated 매핑")
    func captionUpdated() {
        let capture = CapturedSignals()
        makeBridge(capture: capture).handleCaptionUpdated(charset: "UTF-8", caption: "hello")
        guard case .captionUpdated(let charset, let caption) = capture.signals[0] else { Issue.record(); return }
        #expect(charset == "UTF-8")
        #expect(caption == "hello")
    }

    @Test("subCaptionUpdated 매핑")
    func subCaptionUpdated() {
        let capture = CapturedSignals()
        makeBridge(capture: capture).handleSubCaptionUpdated(charset: "UTF-8", caption: "sub")
        guard case .subCaptionUpdated(let charset, let caption) = capture.signals[0] else { Issue.record(); return }
        #expect(charset == "UTF-8")
        #expect(caption == "sub")
    }

    @Test("thumbnailReady 매핑")
    func thumbnailReady() {
        let capture = CapturedSignals()
        makeBridge(capture: capture).handleThumbnailReady(hasThumbnail: true, error: nil)
        guard case .thumbnailReady(let hasThumbnail, _) = capture.signals[0] else { Issue.record(); return }
        #expect(hasThumbnail)
    }

    @Test("mediaContentKeyResolved 매핑")
    func mediaContentKeyResolved() {
        let capture = CapturedSignals()
        makeBridge(capture: capture).handleMediaContentKeyResolved(mck: "mck-123")
        guard case .mediaContentKeyResolved(let mck) = capture.signals[0] else { Issue.record(); return }
        #expect(mck == "mck-123")
    }

    @Test("hlsHeightChanged 매핑")
    func hlsHeightChanged() {
        let capture = CapturedSignals()
        makeBridge(capture: capture).handleHLSHeightChanged(height: 720)
        guard case .hlsHeightChanged(let height) = capture.signals[0] else { Issue.record(); return }
        #expect(height == 720)
    }

    @Test("hlsBitrateChanged 매핑")
    func hlsBitrateChanged() {
        let capture = CapturedSignals()
        makeBridge(capture: capture).handleHLSBitrateChanged(bitrate: 4_500_000)
        guard case .hlsBitrateChanged(let bitrate) = capture.signals[0] else { Issue.record(); return }
        #expect(bitrate == 4_500_000)
    }

    // MARK: - DRM / LMS / Bookmark 3

    @Test("DRM 응답을 observer로 전달")
    func drmResponse_forwardsToObserver() {
        let capture = CapturedSignals()
        let observer = FakeObserver()
        let bridge = makeBridge(capture: capture, observer: observer)

        bridge.handleDRMResponse(
            request: ["url": "https://example.com/drm"],
            response: ["status": 200],
            error: nil
        )

        #expect(observer.drmCalls.count == 1)
        #expect(observer.drmCalls[0].request["url"] as? String == "https://example.com/drm")
        #expect(observer.drmCalls[0].response["status"] as? Int == 200)
        #expect(capture.signals.isEmpty)
    }

    @Test("LMS post를 observer로 전달")
    func lmsPost_forwardsToObserver() {
        let capture = CapturedSignals()
        let observer = FakeObserver()
        let bridge = makeBridge(capture: capture, observer: observer)

        bridge.handleLMSPost(data: "progress=50", result: ["ok": true])

        #expect(observer.lmsCalls.count == 1)
        #expect(observer.lmsCalls[0].data == "progress=50")
        #expect(observer.lmsCalls[0].result["ok"] as? Bool == true)
    }

    @Test("bookmarks를 bookmark 콜백으로 전달")
    func bookmarks_forwardsToBookmarkCallback() {
        let capture = CapturedSignals()
        let bridge = makeBridge(capture: capture)
        let bookmarks = [
            Bookmark(position: 10, title: "intro", kind: .user),
            Bookmark(position: 20, title: "chapter1", kind: .index)
        ]

        bridge.handleBookmarks(bookmarks)

        #expect(capture.bookmarks.count == 1)
        #expect(capture.bookmarks[0] == bookmarks)
    }

    // MARK: - nil observer / nil diagnostics

    @Test("nil observer일 때 DRM 호출은 no-op")
    func nilObserver_drmCallIsNoOp() {
        let capture = CapturedSignals()
        let bridge = makeBridge(capture: capture, observer: nil)

        bridge.handleDRMResponse(request: [:], response: [:], error: nil)
        bridge.handleLMSPost(data: "x", result: [:])

        #expect(capture.signals.isEmpty)
    }

    @Test("nil diagnostics여도 signal은 onSignal로 전달")
    func nilDiagnostics_signalsStillForwardedToOnSignal() {
        let capture = CapturedSignals()
        let bridge = makeBridge(capture: capture, diagnostics: nil)

        bridge.handlePlayStarted(userInteraction: true, error: nil)

        #expect(capture.signals.count == 1)
    }

    @Test("diagnostics 존재 시 signal은 두 채널 모두로 전달")
    func withDiagnostics_signalsForwardedToBothChannels() {
        let capture = CapturedSignals()
        let diagnostics = FakeDiagnostics()
        let bridge = makeBridge(capture: capture, diagnostics: diagnostics)

        bridge.handlePlayStarted(userInteraction: false, error: nil)
        bridge.handleHLSHeightChanged(height: 1080)

        #expect(capture.signals.count == 2)
        #expect(diagnostics.signals.count == 2)
    }
}

#endif
