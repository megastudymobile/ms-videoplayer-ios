//
//  AVPlayerAdapter.swift
//  VideoPlayerModule
//
//  Created by 모바일개발팀_정준영 on 2026/04/17.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

import AVFoundation
import UIKit
import VideoPlayerCore
import VideoPlayerShellSupport

public actor AVPlayerAdapter: PlayerEngineAdapter, PlayerPlaybackRateEngine, PlayerDisplayScalingEngine {
    public nonisolated static let capabilities: EngineCapabilities = [
        .continuesWithoutSurface,
        .seamlessSurfaceSwap
    ]

    public var currentState: PlaybackState {
        state
    }

    public let eventStream: AsyncStream<PlayerEvent>

    private let player: AVPlayer
    private let eventContinuation: AsyncStream<PlayerEvent>.Continuation
    private var state: PlaybackState
    private weak var renderSurface: PlayerRenderSurface?
    @MainActor private var playerLayer: AVPlayerLayer?
    private var statusObservation: NSKeyValueObservation?
    private var timeControlObservation: NSKeyValueObservation?
    private var endObserver: NSObjectProtocol?
    private var failedToEndObserver: NSObjectProtocol?
    private var timeObserverToken: Any?
    private var isDisplayScaled = false

    public init(player: AVPlayer = AVPlayer()) {
        var continuation: AsyncStream<PlayerEvent>.Continuation?
        self.eventStream = AsyncStream<PlayerEvent>(bufferingPolicy: .bufferingNewest(8)) {
            continuation = $0
        }
        self.eventContinuation = continuation!
        self.player = player
        self.state = .idle
    }

    deinit {
        statusObservation?.invalidate()
        timeControlObservation?.invalidate()

        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }

        if let failedToEndObserver {
            NotificationCenter.default.removeObserver(failedToEndObserver)
        }

        if let timeObserverToken {
            player.removeTimeObserver(timeObserverToken)
        }

        eventContinuation.finish()
    }

    public func prepare(source: PlaybackSource) async throws {
        let url: URL
        switch source {
        case .url(let sourceURL):
            url = sourceURL
        case .kollus(let mediaContentKey):
            throw PlayerError.engineError("AVPlayerAdapter는 url source만 지원합니다. source=\(mediaContentKey)")
        }

        cleanupCurrentItemObservers()

        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        installObservers(for: item)

        let duration = try await waitUntilReady(item: item)
        let nextState = PlaybackState(
            status: .readyToPlay,
            currentTime: 0,
            duration: duration,
            isBuffering: false
        )
        transition(to: nextState)
    }

    public func play() async throws {
        await MainActor.run { [player] in
            player.play()
        }

        let nextState = state.updating(status: .playing, isBuffering: false)
        transition(to: nextState)
    }

    public func pause() async throws {
        await MainActor.run { [player] in
            player.pause()
        }

        let nextState = state.updating(status: .paused, isBuffering: false)
        transition(to: nextState)
    }

    public func seek(to time: TimeInterval) async throws {
        let clampedTime = max(0, time)
        let targetTime = CMTime(seconds: clampedTime, preferredTimescale: 600)

        try await withCheckedThrowingContinuation { continuation in
            player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
                Task {
                    guard let self else {
                        continuation.resume()
                        return
                    }
                    guard finished else {
                        continuation.resume(throwing: PlayerError.engineError("AVPlayer seek가 완료되지 않았습니다."))
                        return
                    }

                    let nextState = await self.state.updating(currentTime: clampedTime)
                    await self.publish(event: .timeDidChange(currentTime: clampedTime, duration: nextState.duration))
                    await self.setState(nextState)
                    continuation.resume()
                }
            }
        }
    }

    public func stop(reason: PlayerStopReason) async throws {
        cleanupCurrentItemObservers()
        player.cancelPendingPrerolls()
        player.currentItem?.cancelPendingSeeks()
        player.replaceCurrentItem(with: nil)

        let nextState = stateAfterStop(reason: reason)
        transition(to: nextState)
        if reason == .finished {
            publish(event: .didFinish)
        }

        Task { @MainActor [player, weak self] in
            player.pause()
            guard let self else {
                return
            }
            self.detachCurrentSurface()
        }
    }

    private func stateAfterStop(reason: PlayerStopReason) -> PlaybackState {
        switch reason {
        case .finished:
            state.updating(status: .finished, isBuffering: false)
        case .userClosed, .replacedSource, .appLifecycle:
            .idle
        }
    }

    public func setPlaybackRate(_ rate: Double) async throws {
        guard rate > 0 else {
            throw PlayerError.engineError("AVPlayer playback rate must be greater than 0. rate=\(rate)")
        }

        await MainActor.run { [player] in
            player.rate = Float(rate)
        }
    }

    public func setDisplayScaled(_ isScaled: Bool) async throws {
        self.isDisplayScaled = isScaled
        await MainActor.run {
            self.playerLayer?.videoGravity = Self.videoGravity(isScaled: isScaled)
        }
    }

    public func toggleDisplayScaling() async throws {
        try await setDisplayScaled(!isDisplayScaled)
    }

    public func bind(renderSurface: PlayerRenderSurface) {
        let previousSurface = self.renderSurface
        self.renderSurface = renderSurface
        let isDisplayScaled = self.isDisplayScaled

        Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            previousSurface?.engineDidDetach()
            self.attachPlayerLayer(to: renderSurface, isDisplayScaled: isDisplayScaled)
            renderSurface.engineDidAttach()
        }
    }

    public func unbindRenderSurface() {
        let detachedSurface = renderSurface
        renderSurface = nil

        Task { @MainActor [weak self] in
            detachedSurface?.engineDidDetach()
            guard let self else {
                return
            }
            self.detachCurrentSurface()
        }
    }

    private func installObservers(for item: AVPlayerItem) {
        statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard let self else {
                return
            }

            guard item.status == .failed else {
                return
            }

            let error = PlayerError.engineError(item.error?.localizedDescription ?? "AVPlayerItem status failed")
            Task {
                await self.handleFailure(error)
            }
        }

        timeControlObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            guard let self else {
                return
            }

            Task {
                await self.handleTimeControlStatus(player.timeControlStatus)
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            guard let self else {
                return
            }

            Task {
                await self.handleDidFinish()
            }
        }

        failedToEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] notification in
            guard let self else {
                return
            }

            let error = (notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? NSError)?
                .localizedDescription ?? "AVPlayerItem failed to play to end"

            Task {
                await self.handleFailure(.engineError(error))
            }
        }

        timeObserverToken = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self else {
                return
            }

            Task {
                await self.handlePeriodicTimeUpdate(time)
            }
        }
    }

    private func cleanupCurrentItemObservers() {
        statusObservation?.invalidate()
        statusObservation = nil

        timeControlObservation?.invalidate()
        timeControlObservation = nil

        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }

        if let failedToEndObserver {
            NotificationCenter.default.removeObserver(failedToEndObserver)
            self.failedToEndObserver = nil
        }

        if let timeObserverToken {
            player.removeTimeObserver(timeObserverToken)
            self.timeObserverToken = nil
        }
    }

    private func waitUntilReady(item: AVPlayerItem) async throws -> TimeInterval {
        switch item.status {
        case .readyToPlay:
            return Self.duration(for: item)
        case .failed:
            throw PlayerError.engineError(item.error?.localizedDescription ?? "AVPlayerItem status failed")
        case .unknown:
            break
        @unknown default:
            break
        }

        return try await withCheckedThrowingContinuation { continuation in
            var observation: NSKeyValueObservation?
            observation = item.observe(\.status, options: [.initial, .new]) { item, _ in
                switch item.status {
                case .readyToPlay:
                    observation?.invalidate()
                    observation = nil
                    continuation.resume(returning: Self.duration(for: item))
                case .failed:
                    observation?.invalidate()
                    observation = nil
                    continuation.resume(
                        throwing: PlayerError.engineError(item.error?.localizedDescription ?? "AVPlayerItem status failed")
                    )
                case .unknown:
                    break
                @unknown default:
                    break
                }
            }
        }
    }

    private func handlePeriodicTimeUpdate(_ time: CMTime) {
        let currentTime = max(0, time.seconds.isFinite ? time.seconds : 0)
        let duration = Self.duration(for: player.currentItem)
        let nextState = state.updating(currentTime: currentTime, duration: duration)
        state = nextState
        publish(event: .timeDidChange(currentTime: currentTime, duration: duration))
    }

    private func handleTimeControlStatus(_ status: AVPlayer.TimeControlStatus) {
        switch status {
        case .paused:
            break
        case .waitingToPlayAtSpecifiedRate:
            let nextState = state.updating(status: .buffering, isBuffering: true)
            state = nextState
            publish(event: .bufferingDidChange(isBuffering: true))
        case .playing:
            if state.isBuffering {
                publish(event: .bufferingDidChange(isBuffering: false))
            }
        @unknown default:
            break
        }
    }

    private func handleDidFinish() {
        let nextState = state.updating(status: .finished, isBuffering: false)
        state = nextState
        publish(event: .didFinish)
    }

    private func handleFailure(_ error: PlayerError) {
        let nextState = state.updating(status: .failed(error), isBuffering: false)
        state = nextState
        publish(event: .didFail(error))
    }

    private func transition(to nextState: PlaybackState) {
        state = nextState
        publish(event: .stateDidChange(nextState))
    }

    private func publish(event: PlayerEvent) {
        eventContinuation.yield(event)
    }

    private func setState(_ nextState: PlaybackState) {
        state = nextState
    }

    @MainActor
    private func attachPlayerLayer(
        to renderSurface: PlayerRenderSurface,
        isDisplayScaled: Bool
    ) {
        let layer: AVPlayerLayer
        if let existingLayer = playerLayer {
            layer = existingLayer
            existingLayer.removeFromSuperlayer()
        } else {
            layer = AVPlayerLayer(player: player)
            playerLayer = layer
        }

        layer.player = player
        layer.videoGravity = Self.videoGravity(isScaled: isDisplayScaled)
        layer.frame = renderSurface.containerView.bounds
        layer.needsDisplayOnBoundsChange = true
        renderSurface.containerView.layer.addSublayer(layer)
    }

    @MainActor
    private func detachCurrentSurface() {
        playerLayer?.removeFromSuperlayer()
    }

    private static func duration(for item: AVPlayerItem?) -> TimeInterval {
        guard let item else {
            return 0
        }

        let seconds = item.duration.seconds
        guard seconds.isFinite else {
            return 0
        }

        return max(0, seconds)
    }

    private static func videoGravity(isScaled: Bool) -> AVLayerVideoGravity {
        isScaled ? .resizeAspectFill : .resizeAspect
    }
}
