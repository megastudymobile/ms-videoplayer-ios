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
import Testing
import VideoPlayerCore
@testable import VideoPlayerEngineKollus

/// Phase 7 T047 — `KollusPlayerAdapter`가 곧 채택할 확장 capability protocol들의 기본 동작 검증.
///
/// 대상 protocol (모두 `PlayerEngineAdapter.swift` 정의):
/// - `EngineZoomAbility`        — zoom / setZoomOutDisabled / zoomValue / isZoomedIn
/// - `EngineScrollAbility`      — scroll / stopScroll
/// - `EngineAdaptiveStreamingAbility` — changeBandwidth / streamInfoList
/// - `EnginePiPAbility`     — 미채택 검증 (PiP 미구현, H9)
///
/// 본 테스트는 `KollusPlayerView` 인스턴스 없이 호출했을 때의 계약을 잠근다:
/// - "조회/disable" 류 (`setZoomOutDisabled`, `zoomValue`, `streamInfoList`, `isZoomedIn`)는
///   throw 없이 default 값(빈 배열, 0, false)을 반환.
/// - "실제 동작" 류 (`changeBandwidth`, `zoom`, `scroll`, `stopScroll`)는
///   `PlayerError.engineError("...playerView가 준비되지 않았습니다...")`를 throw.
///
/// 주의: 본 파일은 `KollusPlayerAdapter`가 위 4개 protocol을 채택하기 *전*에 작성된다.
/// 채택 전에는 빌드가 fail이 정상이며, 메인 작업이 protocol 채택을 완료하는 시점에 GREEN으로 전환된다.
@MainActor
@Suite("KollusPlayerAdapter 확장 capability protocol 기본 동작")
struct KollusAdapterExtendedCapabilityTests {

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

    // MARK: - EngineZoomAbility

    /// `setZoomOutDisabled(_:)`는 playerView 미준비 상태에서도 throw 없이 통과해야 한다.
    /// (정책: noop + log. 실제 SDK 동기화는 playerView attach 후 lazy 적용)
    @Test("setZoomOutDisabled는 playerView 미준비 시 throw 없이 통과")
    func setZoomOutDisabled_doesNotCrashWithoutPlayerView() async {
        let adapter = makeAdapter()
        await adapter.setZoomOutDisabled(true)
        // throw 없이 통과하면 성공.
    }

    /// `zoomValue()`는 playerView 미준비 시 `0`을 반환한다.
    @Test("zoomValue는 playerView 미준비 시 0 반환")
    func zoomValue_returnsZeroWithoutPlayerView() async {
        let adapter = makeAdapter()
        let value = await adapter.zoomValue()
        #expect(value == 0, "playerView 미준비 시 zoomValue는 0 이어야 한다")
    }

    /// `isZoomedIn`은 playerView 미준비 시 `false`이다.
    @Test("isZoomedIn은 playerView 미준비 시 false")
    func isZoomedIn_isFalseWithoutPlayerView() async {
        let adapter = makeAdapter()
        let zoomed = await adapter.isZoomedIn
        #expect(!(zoomed), "playerView 미준비 시 isZoomedIn은 false 이어야 한다")
    }

    /// `zoom(_:)`는 playerView 미준비 시 `PlayerError.engineError`를 throw 한다.
    /// 더미 `UIPinchGestureRecognizer`로 호출하더라도 동일.
    @Test("zoom은 playerView 미준비 시 engineError throw")
    func zoom_pinchRecognizer_throwsWithoutPlayerView() async {
        let adapter = makeAdapter()
        let recognizer = UIPinchGestureRecognizer()

        await #expect {
            try await adapter.zoom(recognizer)
        } throws: { error in
            guard case let PlayerError.engineError(message) = error else { return false }
            return message.contains("playerView가 준비되지 않았습니다")
        }
    }

    // MARK: - EngineScrollAbility

    /// `scroll(by:)`는 playerView 미준비 시 `PlayerError.engineError`를 throw 한다.
    @Test("scroll은 playerView 미준비 시 engineError throw")
    func scroll_throwsWithoutPlayerView() async {
        let adapter = makeAdapter()

        await #expect {
            try await adapter.scroll(by: CGPoint(x: 10, y: 0))
        } throws: { error in
            guard case let PlayerError.engineError(message) = error else { return false }
            return message.contains("playerView가 준비되지 않았습니다")
        }
    }

    /// `stopScroll()`는 playerView 미준비 시 `PlayerError.engineError`를 throw 한다.
    @Test("stopScroll은 playerView 미준비 시 engineError throw")
    func stopScroll_throwsWithoutPlayerView() async {
        let adapter = makeAdapter()

        await #expect {
            try await adapter.stopScroll()
        } throws: { error in
            guard case let PlayerError.engineError(message) = error else { return false }
            return message.contains("playerView가 준비되지 않았습니다")
        }
    }

    // MARK: - EngineAdaptiveStreamingAbility

    /// `streamInfoList()`는 playerView 미준비 시 빈 배열을 반환한다.
    @Test("streamInfoList는 playerView 미준비 시 빈 배열 반환")
    func streamInfoList_returnsEmptyWithoutPlayerView() async {
        let adapter = makeAdapter()
        let list = await adapter.streamInfoList()
        #expect(list.isEmpty, "playerView 미준비 시 streamInfoList는 [] 이어야 한다")
    }

    /// `changeBandwidth(_:)`는 playerView 미준비 시 `PlayerError.engineError`를 throw 한다.
    @Test("changeBandwidth는 playerView 미준비 시 engineError throw")
    func changeBandwidth_throwsWithoutPlayerView() async {
        let adapter = makeAdapter()

        await #expect {
            try await adapter.changeBandwidth(1_000_000)
        } throws: { error in
            guard case let PlayerError.engineError(message) = error else { return false }
            return message.contains("playerView가 준비되지 않았습니다")
        }
    }

    // MARK: - EnginePiPAbility 미채택

    /// PiP는 미구현이므로 어댑터가 `EnginePiPAbility`를 채택하지 않아야 한다.
    /// 채택 + 가짜 구현은 capability 협상이 거짓 보고를 하게 만든다 (H9).
    @Test("KollusPlayerAdapter는 EnginePiPAbility를 채택하지 않는다")
    func adapter_doesNotConformToPiPCapability() {
        let adapter = makeAdapter()
        #expect(!(adapter is any EnginePiPAbility))
    }
}

#endif
