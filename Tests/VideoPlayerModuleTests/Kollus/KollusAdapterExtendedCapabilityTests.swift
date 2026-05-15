//
//  KollusAdapterExtendedCapabilityTests.swift
//  VideoPlayerModuleTests
//
//  Created by 모바일개발팀_정준영 on 2026/05/15.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

#if canImport(UIKit) && canImport(KollusSDKBinary)

import Foundation
import UIKit
import XCTest
import VideoPlayerCore
@testable import VideoPlayerEngineKollus

/// Phase 7 T047 — `KollusPlayerAdapter`가 곧 채택할 확장 capability protocol들의 기본 동작 검증.
///
/// 대상 protocol (모두 `PlayerEngineAdapter.swift` 정의):
/// - `PlayerZoomEngine`        — zoom / setZoomOutDisabled / zoomValue / isZoomedIn
/// - `PlayerScrollEngine`      — scroll / stopScroll
/// - `PlayerAdaptiveStreamingEngine` — changeBandwidth / streamInfoList
/// - `PlayerPiPCapability`     — startPiP / stopPiP / isPiPActive
///
/// 본 테스트는 `KollusPlayerView` 인스턴스 없이 호출했을 때의 계약을 잠근다:
/// - "조회/disable" 류 (`setZoomOutDisabled`, `zoomValue`, `streamInfoList`, `isZoomedIn`, `isPiPActive`)는
///   throw 없이 default 값(빈 배열, 0, false)을 반환.
/// - "실제 동작" 류 (`changeBandwidth`, `startPiP`, `stopPiP`, `zoom`, `scroll`, `stopScroll`)는
///   `PlayerError.engineError("...playerView가 준비되지 않았습니다...")`를 throw.
///
/// 주의: 본 파일은 `KollusPlayerAdapter`가 위 4개 protocol을 채택하기 *전*에 작성된다.
/// 채택 전에는 빌드가 fail이 정상이며, 메인 작업이 protocol 채택을 완료하는 시점에 GREEN으로 전환된다.
@MainActor
final class KollusAdapterExtendedCapabilityTests: XCTestCase {

    private let validExpire = Date().addingTimeInterval(60 * 60 * 24 * 30)

    private func makeAdapter() -> KollusPlayerAdapter {
        let env = KollusEnvironment(
            applicationKey: "k",
            applicationBundleID: "b",
            applicationExpireDate: validExpire
        )
        let storage = FakeKollusStorage()
        let bootstrapper = KollusSessionBootstrapper(environment: env) { storage }
        return KollusPlayerAdapter(bootstrapper: bootstrapper, environment: env)
    }

    // MARK: - PlayerZoomEngine

    /// `setZoomOutDisabled(_:)`는 playerView 미준비 상태에서도 throw 없이 통과해야 한다.
    /// (정책: noop + log. 실제 SDK 동기화는 playerView attach 후 lazy 적용)
    func test_setZoomOutDisabled_doesNotCrashWithoutPlayerView() async {
        let adapter = makeAdapter()
        await adapter.setZoomOutDisabled(true)
        // throw 없이 통과하면 성공.
    }

    /// `zoomValue()`는 playerView 미준비 시 `0`을 반환한다.
    func test_zoomValue_returnsZeroWithoutPlayerView() async {
        let adapter = makeAdapter()
        let value = await adapter.zoomValue()
        XCTAssertEqual(value, 0, "playerView 미준비 시 zoomValue는 0 이어야 한다")
    }

    /// `isZoomedIn`은 playerView 미준비 시 `false`이다.
    func test_isZoomedIn_isFalseWithoutPlayerView() async {
        let adapter = makeAdapter()
        let zoomed = await adapter.isZoomedIn
        XCTAssertFalse(zoomed, "playerView 미준비 시 isZoomedIn은 false 이어야 한다")
    }

    /// `zoom(_:)`는 playerView 미준비 시 `PlayerError.engineError`를 throw 한다.
    /// 더미 `UIPinchGestureRecognizer`로 호출하더라도 동일.
    func test_zoom_pinchRecognizer_throwsWithoutPlayerView() async {
        let adapter = makeAdapter()
        let recognizer = UIPinchGestureRecognizer()

        do {
            try await adapter.zoom(recognizer)
            XCTFail("Expected engineError when playerView is missing")
        } catch let PlayerError.engineError(message) {
            XCTAssertTrue(
                message.contains("playerView가 준비되지 않았습니다"),
                "got: \(message)"
            )
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    // MARK: - PlayerScrollEngine

    /// `scroll(by:)`는 playerView 미준비 시 `PlayerError.engineError`를 throw 한다.
    func test_scroll_throwsWithoutPlayerView() async {
        let adapter = makeAdapter()

        do {
            try await adapter.scroll(by: CGPoint(x: 10, y: 0))
            XCTFail("Expected engineError when playerView is missing")
        } catch let PlayerError.engineError(message) {
            XCTAssertTrue(
                message.contains("playerView가 준비되지 않았습니다"),
                "got: \(message)"
            )
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    /// `stopScroll()`는 playerView 미준비 시 `PlayerError.engineError`를 throw 한다.
    func test_stopScroll_throwsWithoutPlayerView() async {
        let adapter = makeAdapter()

        do {
            try await adapter.stopScroll()
            XCTFail("Expected engineError when playerView is missing")
        } catch let PlayerError.engineError(message) {
            XCTAssertTrue(
                message.contains("playerView가 준비되지 않았습니다"),
                "got: \(message)"
            )
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    // MARK: - PlayerAdaptiveStreamingEngine

    /// `streamInfoList()`는 playerView 미준비 시 빈 배열을 반환한다.
    func test_streamInfoList_returnsEmptyWithoutPlayerView() async {
        let adapter = makeAdapter()
        let list = await adapter.streamInfoList()
        XCTAssertTrue(list.isEmpty, "playerView 미준비 시 streamInfoList는 [] 이어야 한다")
    }

    /// `changeBandwidth(_:)`는 playerView 미준비 시 `PlayerError.engineError`를 throw 한다.
    func test_changeBandwidth_throwsWithoutPlayerView() async {
        let adapter = makeAdapter()

        do {
            try await adapter.changeBandwidth(1_000_000)
            XCTFail("Expected engineError when playerView is missing")
        } catch let PlayerError.engineError(message) {
            XCTAssertTrue(
                message.contains("playerView가 준비되지 않았습니다"),
                "got: \(message)"
            )
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    // MARK: - PlayerPiPCapability

    /// `startPiP()`는 playerView 미준비 시 `PlayerError.engineError`를 throw 한다.
    func test_pip_startWithoutPlayerView_throws() async {
        let adapter = makeAdapter()

        do {
            try await adapter.startPiP()
            XCTFail("Expected engineError when playerView is missing")
        } catch let PlayerError.engineError(message) {
            XCTAssertTrue(
                message.contains("playerView가 준비되지 않았습니다"),
                "got: \(message)"
            )
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    /// `stopPiP()`는 playerView 미준비 시 `PlayerError.engineError`를 throw 한다.
    func test_pip_stopWithoutPlayerView_throws() async {
        let adapter = makeAdapter()

        do {
            try await adapter.stopPiP()
            XCTFail("Expected engineError when playerView is missing")
        } catch let PlayerError.engineError(message) {
            XCTAssertTrue(
                message.contains("playerView가 준비되지 않았습니다"),
                "got: \(message)"
            )
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    /// `isPiPActive`는 playerView 미준비 시 `false`이다.
    func test_isPiPActive_isFalseWithoutPlayerView() async {
        let adapter = makeAdapter()
        let active = await adapter.isPiPActive
        XCTAssertFalse(active, "playerView 미준비 시 isPiPActive는 false 이어야 한다")
    }
}

#endif
