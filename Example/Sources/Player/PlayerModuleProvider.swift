//
//  PlayerModuleProvider.swift
//  VideoPlayerExample
//
//  Created by JunyoungJung on 2026/06/05.
//
//  DIP 경계 — Interactor는 PlayerModuleProviding 추상에만 의존한다.
//  엔진 선택(시뮬레이터/실기기)과 plist+세팅 합성은 전부 여기 캡슐화 (OCP).
//

import Foundation
import VideoPlayerCore
import VideoPlayerEngineKollus
import VideoPlayerShellSupport

@MainActor
protocol PlayerModuleProviding {
    func makeModule() async throws -> PlayerModule
}

@MainActor
final class PlayerModuleProvider: PlayerModuleProviding {
    static let shared = PlayerModuleProvider()

    private var factory: KollusPlayerModuleFactory?
    /// factory 생성 시점의 세팅 스냅샷 — 달라지면 재생성해 다음 재생부터 반영.
    private var factoryFingerprint: SettingsFingerprint?

    private struct SettingsFingerprint: Equatable {
        let hardwareDecoderPreferred: Bool
        let audioBackgroundPlayPolicy: Bool

        static var current: SettingsFingerprint {
            SettingsFingerprint(
                hardwareDecoderPreferred: PreferenceManager.hardwareDecoderPreferred,
                audioBackgroundPlayPolicy: PreferenceManager.isBackgroundAudioPlay
            )
        }
    }

    private init() {}

    func makeModule() async throws -> PlayerModule {
        #if targetEnvironment(simulator)
        // Kollus 실재생은 실기기 한정 — 렌더 표면에 미지원 안내만 표시하는 no-op 엔진.
        return await PlayerModuleWiring.makeModule(
            engine: UnsupportedEnvironmentEngine(message: "Kollus 재생은 실기기에서만 지원됩니다."),
            engineCapabilities: []
        )
        #else
        let factory = try resolveFactory()
        return await factory.makeModule()
        #endif
    }

    private func resolveFactory() throws -> KollusPlayerModuleFactory {
        let fingerprint = SettingsFingerprint.current
        if let factory, factoryFingerprint == fingerprint {
            return factory
        }

        let configuration = try KollusEnvironmentLoader.loadFromBundle(
            hardwareDecoderPreferred: fingerprint.hardwareDecoderPreferred,
            audioBackgroundPlayPolicy: fingerprint.audioBackgroundPlayPolicy
        )
        try configuration.environment.validate()

        let newFactory = KollusPlayerModuleFactory(environment: configuration.environment)
        factory = newFactory
        factoryFingerprint = fingerprint
        return newFactory
    }
}
