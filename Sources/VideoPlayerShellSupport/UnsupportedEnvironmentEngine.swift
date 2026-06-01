//
//  UnsupportedEnvironmentEngine.swift
//  VideoPlayerModule
//
//  Created by 모바일팀_정준영 on 2026/06/01.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

import Foundation
import VideoPlayerCore

/// 현재 실행 환경(예: iOS 시뮬레이터)에서 특정 엔진(Kollus 등)이 실제 재생을
/// 제공할 수 없을 때 사용하는 no-op 엔진.
///
/// `bind(renderSurface:)` 시점에 렌더 표면에 "미지원" 안내를 표시하고,
/// 재생 관련 명령(`prepare`/`play`/`seek` 등)은 상태를 바꾸지 않는 no-op 으로 처리한다.
/// 호스트 앱은 시뮬레이터 + Kollus 소스 조합에서 본 엔진으로 라우팅한다.
public actor UnsupportedEnvironmentEngine: PlayerEngineAdapter {
    public nonisolated static let capabilities: EngineCapabilities = []

    public var currentState: PlaybackState { state }
    public let eventStream: AsyncStream<PlayerEvent>

    private let eventContinuation: AsyncStream<PlayerEvent>.Continuation
    private let message: String
    private var state: PlaybackState = .idle
    private weak var renderSurface: PlayerRenderSurface?

    public init(message: String) {
        self.message = message
        var continuation: AsyncStream<PlayerEvent>.Continuation?
        self.eventStream = AsyncStream<PlayerEvent>(bufferingPolicy: .bufferingNewest(1)) {
            continuation = $0
        }
        self.eventContinuation = continuation!
    }

    deinit {
        eventContinuation.finish()
    }

    // MARK: - PlayerEngineAdapter

    public func bind(renderSurface: PlayerRenderSurface) {
        self.renderSurface = renderSurface
        let message = self.message

        Task { @MainActor in
            renderSurface.showUnsupportedEnvironment(message: message)
        }
    }

    public func unbindRenderSurface() {
        renderSurface = nil
    }

    // MARK: - PlayerPlaybackEngine (no-op)

    public func prepare(source: PlaybackSource) async throws {}
    public func play() async throws {}
    public func pause() async throws {}
    public func seek(to time: TimeInterval) async throws {}
    public func stop(reason: PlayerStopReason) async throws {}
}
