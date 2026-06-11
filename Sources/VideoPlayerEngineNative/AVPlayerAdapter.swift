//
//  AVPlayerAdapter.swift
//  VideoPlayerModule
//
//  Created by 모바일팀_정준영 on 2026/04/17.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import AVFoundation
import UIKit
import VideoPlayerCore
import VideoPlayerShellSupport

public actor AVPlayerAdapter: PlayerEngineAdapter, EnginePlaybackRateAbility, EngineDisplayScalingAbility, EngineSeekPreviewAbility {
    public nonisolated static let runtimeTraits: EngineRuntimeTraits = [
        .continuesWithoutSurface,
        .seamlessSurfaceSwap
        // emitsAuthoritativeStateEvents 미포함: Native는 play/pause/seek 권위 콜백이 없어
        // Core command-origin이 그 상태를 닫는다.
    ]

    /// Core는 이 스트림을 소비해 reducer로 상태를 만든다.
    public let outputStream: AsyncStream<PlayerEngineOutput>

    private let player: AVPlayer
    private let outputContinuation: AsyncStream<PlayerEngineOutput>.Continuation
    private var state: PlaybackState
    private weak var renderSurface: PlayerRenderSurface?
    @MainActor private var playerLayer: AVPlayerLayer?
    private var statusObservation: NSKeyValueObservation?
    private var timeControlObservation: NSKeyValueObservation?
    private var endObserver: NSObjectProtocol?
    private var failedToEndObserver: NSObjectProtocol?
    private var timeObserverToken: Any?
    private var displayScaleMode: PlayerDisplayScaleMode = .aspectFit
    private var imageGenerator: AVAssetImageGenerator?
    /// generator가 어떤 asset용인지 추적 — 콘텐츠 교체 시 재생성.
    private var imageGeneratorAsset: AVAsset?

    /// KVO/Notification/periodic observer 콜백을 단일 FIFO 스트림으로 직렬 소비한다.
    /// 콜백마다 `Task`를 새로 만들면 임의 스레드에서 도착한 이벤트의 actor 처리 순서가 비결정적이라
    /// `timeControlStatus(.playing)`와 `periodicTime`이 뒤바뀌는 등 상태 역전이 발생한다.
    /// 콜백은 continuation에 동기 yield만 하고, 단일 consumer가 순서대로 처리.
    private enum ObserverEvent: Sendable {
        case itemFailed(PlayerError)
        case failedToEnd(PlayerError)
        case timeControl(AVPlayer.TimeControlStatus)
        case didFinish
        case periodicTime(seconds: Double)
    }
    private nonisolated let observerEventStream: AsyncStream<ObserverEvent>
    private nonisolated let observerEventContinuation: AsyncStream<ObserverEvent>.Continuation
    private var observerConsumerTask: Task<Void, Never>?

    public init(player: AVPlayer = AVPlayer()) {
        var observerContinuation: AsyncStream<ObserverEvent>.Continuation?
        self.observerEventStream = AsyncStream<ObserverEvent>(bufferingPolicy: .unbounded) {
            observerContinuation = $0
        }
        self.observerEventContinuation = observerContinuation!
        var outputContinuation: AsyncStream<PlayerEngineOutput>.Continuation?
        self.outputStream = AsyncStream<PlayerEngineOutput>(bufferingPolicy: .unbounded) {
            outputContinuation = $0
        }
        self.outputContinuation = outputContinuation!
        self.player = player
        self.state = .idle
        self.observerConsumerTask = nil
        Task { await self.startObserverConsumerIfNeeded() }
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

        observerConsumerTask?.cancel()
        observerEventContinuation.finish()
        outputContinuation.finish()
    }

    /// observer 이벤트를 단일 Task에서 FIFO로 소비. self를 약하게 잡아 deinit을 막지 않는다.
    private func startObserverConsumerIfNeeded() {
        guard observerConsumerTask == nil else { return }
        observerConsumerTask = Task { [weak self] in
            guard let stream = self?.observerEventStream else { return }
            for await event in stream {
                guard let self else { return }
                switch event {
                case .itemFailed(let error), .failedToEnd(let error):
                    await self.handleFailure(error)
                    await self.emitOutput(.failed(error))
                case .timeControl(let status):
                    await self.handleTimeControlStatus(status)
                    await self.emitOutput(.timeControl(status))
                case .didFinish:
                    await self.handleDidFinish()
                    await self.emitOutput(.didFinish)
                case .periodicTime(let seconds):
                    await self.handlePeriodicTimeUpdate(seconds: seconds)
                    await self.emitOutput(.periodicTime(seconds: seconds))
                }
            }
        }
    }

    public func prepare(source: PlaybackSource) async throws {
        let url: URL
        switch source.kind {
        case .url(let sourceURL):
            url = sourceURL
        case .mediaKey(let key):
            throw PlayerError.engineError("AVPlayerAdapter는 url source만 지원합니다. source=\(key)")
        }

        imageGenerator?.cancelAllCGImageGeneration()
        imageGenerator = nil
        imageGeneratorAsset = nil
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
        // Core reducer가 이 prepared 스냅샷을 받아 readyToPlay 상태를 만든다.
        #if DEBUG
        NSLog("[Native.out] prepared duration=%.3f", duration)
        #endif
        outputContinuation.yield(.stateInput(.prepared(
            PlaybackPreparedSnapshot(position: 0, duration: duration, isLive: false, liveDuration: nil)
        )))
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
                    await self.setState(nextState)
                    await self.emitStateInput(.positionChanged(time: clampedTime, duration: nextState.duration))
                    continuation.resume()
                }
            }
        }
    }

    // MARK: - EngineSeekPreviewAbility

    public func seekPreviewImage(at time: TimeInterval) async -> UIImage? {
        let snapshot = await MainActor.run { () -> (asset: AVAsset, duration: TimeInterval)? in
            guard let item = player.currentItem else { return nil }
            return (item.asset, Self.duration(for: item))
        }
        guard let snapshot, snapshot.duration > 0 else { return nil }

        let generator: AVAssetImageGenerator
        if let existing = imageGenerator, imageGeneratorAsset === snapshot.asset {
            generator = existing
        } else {
            let created = AVAssetImageGenerator(asset: snapshot.asset)
            created.appliesPreferredTrackTransform = true
            created.maximumSize = CGSize(width: 480, height: 270)
            imageGenerator = created
            imageGeneratorAsset = snapshot.asset
            generator = created
        }

        generator.cancelAllCGImageGeneration()

        let clamped = min(max(0, time), snapshot.duration)
        let target = CMTime(seconds: clamped, preferredTimescale: 600)
        return await withCheckedContinuation { continuation in
            generator.generateCGImagesAsynchronously(forTimes: [NSValue(time: target)]) { _, cgImage, _, result, _ in
                guard result == .succeeded, let cgImage else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: UIImage(cgImage: cgImage))
            }
        }
    }

    public func stop(reason: PlayerStopReason) async throws {
        imageGenerator?.cancelAllCGImageGeneration()
        imageGenerator = nil
        imageGeneratorAsset = nil
        cleanupCurrentItemObservers()
        player.cancelPendingPrerolls()
        player.currentItem?.cancelPendingSeeks()
        player.replaceCurrentItem(with: nil)

        let nextState = stateAfterStop(reason: reason)
        transition(to: nextState)
        if reason == .finished {
            outputContinuation.yield(.stateInput(.stopped(.finished)))
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
        try await setDisplayScaleMode(isScaled ? .aspectFill : .aspectFit)
    }

    public func setDisplayScaleMode(_ mode: PlayerDisplayScaleMode) async throws {
        self.displayScaleMode = mode
        await MainActor.run {
            self.playerLayer?.videoGravity = Self.videoGravity(mode: mode)
        }
    }

    public func toggleDisplayScaling() async throws {
        try await toggleDisplayScaleMode()
    }

    public func toggleDisplayScaleMode() async throws {
        try await setDisplayScaleMode(displayScaleMode.next)
    }

    public func bind(renderSurface: PlayerRenderSurface) {
        let previousSurface = self.renderSurface
        self.renderSurface = renderSurface
        let displayScaleMode = self.displayScaleMode

        Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            previousSurface?.engineDidDetach()
            self.attachPlayerLayer(to: renderSurface, displayScaleMode: displayScaleMode)
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
        statusObservation = item.observe(\.status, options: [.new]) { [observerEventContinuation] item, _ in
            guard item.status == .failed else {
                return
            }

            let error = PlayerError.engineError(item.error?.localizedDescription ?? "AVPlayerItem status failed")
            observerEventContinuation.yield(.itemFailed(error))
        }

        timeControlObservation = player.observe(\.timeControlStatus, options: [.new]) { [observerEventContinuation] player, _ in
            observerEventContinuation.yield(.timeControl(player.timeControlStatus))
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [observerEventContinuation] _ in
            observerEventContinuation.yield(.didFinish)
        }

        failedToEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            queue: .main
        ) { [observerEventContinuation] notification in
            let error = (notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? NSError)?
                .localizedDescription ?? "AVPlayerItem failed to play to end"
            observerEventContinuation.yield(.failedToEnd(.engineError(error)))
        }

        timeObserverToken = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [observerEventContinuation] time in
            let seconds = max(0, time.seconds.isFinite ? time.seconds : 0)
            observerEventContinuation.yield(.periodicTime(seconds: seconds))
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

    private func handlePeriodicTimeUpdate(seconds: Double) {
        let currentTime = max(0, seconds)
        let duration = Self.duration(for: player.currentItem)
        let nextState = state.updating(currentTime: currentTime, duration: duration)
        state = nextState
    }

    private func handleTimeControlStatus(_ status: AVPlayer.TimeControlStatus) {
        switch status {
        case .paused:
            // stop/finish 뒤 늦게 도착하는 paused 통지가 종료된 상태를 되살리지 않도록 무시한다.
            break
        case .waitingToPlayAtSpecifiedRate:
            let nextState = state.updating(status: .buffering, isBuffering: true)
            state = nextState
        case .playing:
            break
        @unknown default:
            break
        }
    }

    private func handleDidFinish() {
        let nextState = state.updating(status: .finished, isBuffering: false)
        state = nextState
    }

    private func handleFailure(_ error: PlayerError) {
        let nextState = state.updating(status: .failed(error), isBuffering: false)
        state = nextState
    }

    private func transition(to nextState: PlaybackState) {
        state = nextState
    }

    /// observer 신호를 매퍼로 정규화해 outputStream에 발행한다.
    /// play/pause/seek/prepare는 명령 결과이므로 여기로 보내지 않는다(Core command-origin이 닫음).
    private func emitOutput(_ signal: AVPlayerSignal) {
        guard let output = AVPlayerSignalMapper.normalize(signal) else {
            return
        }
        #if DEBUG
        // device QA: AVPlayer observer 신호 → outputStream 발행 추적.
        NSLog("[Native.out] %@ -> %@", String(describing: signal), String(describing: output))
        #endif
        outputContinuation.yield(output)
    }

    private func emitStateInput(_ input: PlaybackStateInput) {
        outputContinuation.yield(.stateInput(input))
    }

    private func setState(_ nextState: PlaybackState) {
        state = nextState
    }

    @MainActor
    private func attachPlayerLayer(
        to renderSurface: PlayerRenderSurface,
        displayScaleMode: PlayerDisplayScaleMode
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
        layer.videoGravity = Self.videoGravity(mode: displayScaleMode)
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

    private static func videoGravity(mode: PlayerDisplayScaleMode) -> AVLayerVideoGravity {
        switch mode {
        case .aspectFit:
            return .resizeAspect
        case .aspectFill:
            return .resizeAspectFill
        case .fill:
            return .resize
        }
    }
}
