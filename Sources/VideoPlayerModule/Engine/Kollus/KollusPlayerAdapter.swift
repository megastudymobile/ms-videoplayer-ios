//
//  KollusPlayerAdapter.swift
//  SmartPlayer
//
//  Created by 모바일개발팀_정준영 on 2026/05/11.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import Foundation
import KollusSDKBinary
import UIKit
import VideoPlayerCore
import VideoPlayerShellSupport

public actor KollusPlayerAdapter: PlayerEngineAdapter {
    public nonisolated static let capabilities: EngineCapabilities = []

    public var currentState: PlaybackState {
        state
    }

    public let eventStream: AsyncStream<PlayerEvent>

    private let eventContinuation: AsyncStream<PlayerEvent>.Continuation
    private let storage: KollusStorage
    private let playerType: KollusPlayerType
    private var state: PlaybackState
    private weak var renderSurface: PlayerRenderSurface?
    @MainActor private var playerView: KollusPlayerView?

    public init() {
        self.init(
            storage: KollusStorage(),
            playerType: KollusPlayerType(rawValue: 1)!
        )
    }

    init(
        storage: KollusStorage = KollusStorage(),
        playerType: KollusPlayerType = KollusPlayerType(rawValue: 1)!
    ) {
        var continuation: AsyncStream<PlayerEvent>.Continuation?
        self.eventStream = AsyncStream<PlayerEvent>(bufferingPolicy: .bufferingNewest(8)) {
            continuation = $0
        }
        self.eventContinuation = continuation!
        self.storage = storage
        self.playerType = playerType
        self.state = .idle
    }

    deinit {
        eventContinuation.finish()
    }

    public func prepare(source: PlaybackSource) async throws {
        let mediaContentKey: String
        switch source {
        case .kollus(let key):
            mediaContentKey = key
        case .url(let sourceURL):
            throw PlayerError.engineError("KollusPlayerAdapter는 kollus(mediaContentKey:)만 지원합니다. source=\(sourceURL.absoluteString)")
        }

        let boundSurface = renderSurface
        let preparedState = try await MainActor.run { () throws -> PlaybackState in
            self.playerView?.removeFromSuperview()

            guard let playerView = KollusPlayerView(mediaContentKey: mediaContentKey) else {
                throw PlayerError.engineError("KollusPlayerView 초기화에 실패했습니다.")
            }
            playerView.storage = storage
            playerView.debug = false

            if let boundSurface {
                attach(playerView: playerView, to: boundSurface)
            }

            try playerView.prepareToPlay(withMode: playerType)

            self.playerView = playerView

            return PlaybackState(
                status: .readyToPlay,
                currentTime: playerView.content?.position ?? 0,
                duration: playerView.content?.duration ?? 0,
                isBuffering: false
            )
        }

        transition(to: preparedState)
    }

    public func play() {
        Task {
            await performPlay()
        }
    }

    public func pause() {
        Task {
            await performPause()
        }
    }

    public func seek(to time: TimeInterval) async {
        let clampedTime = max(0, time)

        await MainActor.run {
            self.playerView?.currentPlaybackTime = clampedTime
        }

        let nextState = state.updating(currentTime: clampedTime)
        transition(to: nextState, emitStateEvent: false)
        publish(event: .timeDidChange(currentTime: clampedTime, duration: nextState.duration))
    }

    public func stop() {
        state = .idle
        publish(event: .stateDidChange(.idle))

        Task {
            await performStop()
        }
    }

    public func bind(renderSurface: PlayerRenderSurface) {
        let previousSurface = self.renderSurface
        self.renderSurface = renderSurface

        Task { @MainActor in
            previousSurface?.engineDidDetach()
            if let playerView = self.playerView {
                attach(playerView: playerView, to: renderSurface)
            }
            renderSurface.engineDidAttach()
        }
    }

    public func unbindRenderSurface() {
        let detachedSurface = renderSurface
        renderSurface = nil

        Task { @MainActor in
            detachedSurface?.engineDidDetach()
            self.playerView?.removeFromSuperview()
        }
    }

    private func performPlay() async {
        do {
            try await MainActor.run {
                guard let playerView else {
                    throw PlayerError.engineError("Kollus playerView가 준비되지 않았습니다.")
                }

                try playerView.play()
            }

            let nextState = state.updating(status: .playing, isBuffering: false)
            transition(to: nextState)
        } catch {
            handleFailure(mapToPlayerError(error))
        }
    }

    private func performPause() async {
        do {
            try await MainActor.run {
                guard let playerView else {
                    throw PlayerError.engineError("Kollus playerView가 준비되지 않았습니다.")
                }

                try playerView.pause()
            }

            let nextState = state.updating(status: .paused, isBuffering: false)
            transition(to: nextState)
        } catch {
            handleFailure(mapToPlayerError(error))
        }
    }

    private func performStop() async {
        await MainActor.run {
            if let playerView {
                _ = try? playerView.stop()
                playerView.removeFromSuperview()
            }
            self.playerView = nil
        }
    }

    @MainActor
    private func attach(playerView: KollusPlayerView, to renderSurface: PlayerRenderSurface) {
        playerView.removeFromSuperview()
        playerView.frame = renderSurface.containerView.bounds
        playerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        renderSurface.containerView.addSubview(playerView)
    }

    private func transition(to nextState: PlaybackState, emitStateEvent: Bool = true) {
        state = nextState
        if emitStateEvent {
            publish(event: .stateDidChange(nextState))
        }
    }

    private func handleFailure(_ error: PlayerError) {
        let nextState = state.updating(status: .failed(error), isBuffering: false)
        transition(to: nextState)
        publish(event: .didFail(error))
    }

    private func publish(event: PlayerEvent) {
        eventContinuation.yield(event)
    }

    private func mapError(_ error: NSError?, fallback: String) -> PlayerError {
        let message = error?.localizedDescription ?? fallback
        return .engineError(message)
    }

    private func mapToPlayerError(_ error: Error) -> PlayerError {
        if let playerError = error as? PlayerError {
            return playerError
        }

        return .unknown((error as NSError).localizedDescription)
    }
}
