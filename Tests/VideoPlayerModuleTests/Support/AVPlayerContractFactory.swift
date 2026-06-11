#if canImport(UIKit)

//
//  AVPlayerContractFactory.swift
//  SmartPlayer
//
//  Created by 모바일개발팀_정준영 on 2026/04/20.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import AVFoundation
import Foundation
import Testing
@testable import VideoPlayerCore
@testable import VideoPlayerEngineNative
@testable import VideoPlayerShellSupport

enum AVPlayerContractFactory: PlayerEngineAdapterContractTestable {
    static func makeTestAdapter() -> PlayerEngineAdapter {
        AVPlayerAdapter(player: AVPlayer())
    }

    static func cleanupTestAdapter(_ adapter: PlayerEngineAdapter) async {
        try? await adapter.stop(reason: .userClosed)
    }

    static var maxPreparationSeconds: TimeInterval { 3 }
    static var isSupportedInCurrentEnvironment: Bool { true }
    static var expectedCapabilities: EngineRuntimeTraits {
        [.continuesWithoutSurface, .seamlessSurfaceSwap]
    }
}

/// `PlayerEngineContract` generic 계약을 AVPlayerAdapter에 대해 실행한다.
/// 추가 AVPlayer 전용 assertion이 필요하면 이 suite에 `@Test`를 더 선언한다.
@Suite("AVPlayerAdapter 엔진 계약", .enabled(if: AVPlayerContractFactory.isSupportedInCurrentEnvironment))
struct AVPlayerEngineContractTests {
    private typealias Contract = PlayerEngineContract<AVPlayerContractFactory>

    @Test("현재 환경 지원 여부를 throw 없이 판별한다")
    func isSupportedInCurrentEnvironmentIsDecidableWithoutThrow() {
        Contract.isSupportedInCurrentEnvironmentIsDecidableWithoutThrow()
    }

    @Test("runtimeTraits가 기대값과 일치한다")
    func capabilitiesMatchExpectation() {
        Contract.capabilitiesMatchExpectation()
    }

    @Test("idle에서 stop 반복 호출이 crash하지 않는다")
    func stopFromIdleDoesNotCrash() async throws {
        try await Contract.stopFromIdleDoesNotCrash()
    }

    @Test("finished 사유 stop은 finished output을 방출한다")
    func stopWithFinishedReasonEmitsFinishedOutput() async throws {
        try await Contract.stopWithFinishedReasonEmitsFinishedOutput()
    }

    @Test("bind 없이 unbindRenderSurface 호출이 crash하지 않는다")
    func unbindRenderSurfaceWithoutBindDoesNotCrash() async throws {
        try await Contract.unbindRenderSurfaceWithoutBindDoesNotCrash()
    }

    @Test("outputStream을 isolation 문제 없이 획득한다")
    func outputStreamIsAvailable() async throws {
        try await Contract.outputStreamIsAvailable()
    }
}

#endif
