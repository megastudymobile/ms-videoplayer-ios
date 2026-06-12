#if canImport(UIKit)

//
//  KollusContractFactory.swift
//  SmartPlayer
//
//  Created by 모바일개발팀_정준영 on 2026/05/11.
//  Updated by 모바일개발팀_정준영 on 2026/05/15.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import Foundation
import Testing
@testable import VideoPlayerCore
@testable import VideoPlayerEngineKollus
@testable import VideoPlayerShellSupport

enum KollusContractFactory: PlayerEngineAdapterContractTestable {
    static func makeTestAdapter() -> PlayerEngineAdapter {
        let env = KollusEnvironment(
            applicationKey: "test-key",
            applicationBundleID: "com.example.test",
            applicationExpireDate: Date().addingTimeInterval(60 * 60 * 24 * 30)
        )
        let bootstrapper = KollusSessionBootstrapper(environment: env)
        return KollusPlayerAdapter(bootstrapper: bootstrapper, environment: env)
    }

    static func cleanupTestAdapter(_ adapter: PlayerEngineAdapter) async {
        try? await adapter.handle(.stop)
    }

    static var maxPreparationSeconds: TimeInterval { 5 }

    static var isSupportedInCurrentEnvironment: Bool {
        #if targetEnvironment(simulator)
        false
        #else
        true
        #endif
    }

    static var expectedCapabilities: EngineRuntimeTraits {
        .kollus
    }
}

/// `PlayerEngineContract` generic 계약을 KollusPlayerAdapter에 대해 실행한다.
/// simulator에서는 Kollus가 미지원이므로 suite trait로 전체를 건너뛴다.
@Suite("KollusPlayerAdapter 엔진 계약", .enabled(if: KollusContractFactory.isSupportedInCurrentEnvironment))
struct KollusPlayerEngineContractTests {
    private typealias Contract = PlayerEngineContract<KollusContractFactory>

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

    @Test("stop 명령은 finished output을 방출하지 않는다")
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
