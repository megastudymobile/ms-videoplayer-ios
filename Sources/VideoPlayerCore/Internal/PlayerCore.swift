//
//  PlayerCore.swift
//  VideoPlayerModule
//
//  Created by 모바일개발팀_정준영 on 2026/04/17.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

import Foundation

public actor PlayerCore {
    public nonisolated let stateStream: AsyncStream<PlaybackState>
    public nonisolated let eventStream: AsyncStream<PlayerEvent>

    private let engine: PlayerPlaybackEngine
    private let engineCapabilities: EngineCapabilities
    private var pendingPrepareTask: Task<Void, Error>?
    private var engineEventTask: Task<Void, Never>?
    private var currentState: PlaybackState
    private var currentPolicy: PlayerFeaturePolicy
    private var currentSource: PlaybackSource?
    private let stateContinuation: AsyncStream<PlaybackState>.Continuation
    private let eventContinuation: AsyncStream<PlayerEvent>.Continuation

    public init(
        engine: PlayerPlaybackEngine,
        engineCapabilities: EngineCapabilities,
        initialPolicy: PlayerFeaturePolicy = .default
    ) {
        var stateContinuation: AsyncStream<PlaybackState>.Continuation?
        let stateStream = AsyncStream<PlaybackState>(bufferingPolicy: .bufferingNewest(8)) {
            stateContinuation = $0
        }

        var eventContinuation: AsyncStream<PlayerEvent>.Continuation?
        let eventStream = AsyncStream<PlayerEvent>(bufferingPolicy: .bufferingNewest(1)) {
            eventContinuation = $0
        }

        self.engine = engine
        self.engineCapabilities = engineCapabilities
        self.currentState = .idle
        self.currentPolicy = initialPolicy
        self.stateStream = stateStream
        self.eventStream = eventStream
        self.stateContinuation = stateContinuation!
        self.eventContinuation = eventContinuation!
    }

    deinit {
        pendingPrepareTask?.cancel()
        engineEventTask?.cancel()
        stateContinuation.finish()
        eventContinuation.finish()
    }

    public func activate() async {
        guard engineEventTask == nil else {
            return
        }

        let stream = await engine.eventStream
        engineEventTask = Task { [weak self] in
            for await event in stream {
                guard let self else {
                    return
                }
                await self.consume(engineEvent: event)
            }
        }
    }

    public func dispose() {
        pendingPrepareTask?.cancel()
        engineEventTask?.cancel()
        pendingPrepareTask = nil
        engineEventTask = nil
        stateContinuation.finish()
        eventContinuation.finish()
    }

    public func start(source: PlaybackSource, policy: PlayerFeaturePolicy) async throws {
        let effectivePolicy = applyEffectivePolicy(policy)
        currentPolicy = effectivePolicy.policy
        currentSource = source

        if let reason = effectivePolicy.reason {
            publish(event: .policyDowngraded(reason: reason))
        }

        pendingPrepareTask?.cancel()
        pendingPrepareTask = nil

        transition(to: currentState.updating(status: .preparing, currentTime: 0, duration: 0, isBuffering: false))

        let task = Task { [weak self] in
            guard let self else {
                return
            }
            try await self.performStart(source: source, policy: effectivePolicy.policy)
        }
        pendingPrepareTask = task

        do {
            try await task.value
            if pendingPrepareTask?.isCancelled == false {
                pendingPrepareTask = nil
            }
        } catch is CancellationError {
            if pendingPrepareTask?.isCancelled == true {
                pendingPrepareTask = nil
            }
        } catch {
            pendingPrepareTask = nil
            let playerError = mapToPlayerError(error)
            transition(to: currentState.updating(status: .failed(playerError), isBuffering: false))
            publish(event: .didFail(playerError))
            throw playerError
        }
    }

    public func execute(command: PlaybackCommand) async throws {
        switch command {
        case .load(let source):
            try await start(source: source, policy: currentPolicy)
        case .play:
            try await executeEngineCommand {
                try await engine.play()
            }
            transition(to: currentState.updating(status: .playing, isBuffering: false))
        case .pause:
            try await executeEngineCommand {
                try await engine.pause()
            }
            transition(to: currentState.updating(status: .paused, isBuffering: false))
        case .seek(let time):
            try await executeEngineCommand {
                try await engine.seek(to: time)
            }
            transition(to: currentState.updating(currentTime: time))
        case .seekWithOrigin(let time, let origin):
            let targetTime = seekTargetTime(for: time, origin: origin)
            try await executeEngineCommand {
                try await engine.seek(to: targetTime)
            }
            transition(to: currentState.updating(currentTime: targetTime))
        case .setPlaybackRate(let rate):
            try await setPlaybackRate(rate)
        case .setSkipInterval(let interval):
            try setSkipInterval(interval)
        case .setSubtitleVisible(let isVisible):
            try await setSubtitleVisible(isVisible)
        case .selectSubtitleTrack(let trackID):
            try await selectSubtitleTrack(trackID)
        case .setCaptionFontSize(let fontSize):
            try await setCaptionFontSize(fontSize)
        case .addBookmark(let time):
            try await addBookmark(at: time, title: "")
        case .addBookmarkWithTitle(let time, let title):
            try await addBookmark(at: time, title: title)
        case .removeBookmark(let time):
            try await removeBookmark(at: time)
        case .selectSubtitleFile(let fileURL):
            try await selectSubtitleFile(fileURL)
        case .setDisplayLocked(let isLocked):
            try await setDisplayLocked(isLocked)
        case .setDisplayScaleMode(let mode):
            try await setDisplayScaleMode(mode)
        case .setDisplayScaled(let isScaled):
            try await setDisplayScaled(isScaled)
        case .toggleDisplayScaleMode:
            try await toggleDisplayScaleMode()
        case .toggleDisplayScaling:
            try await toggleDisplayScaling()
        case .stop:
            pendingPrepareTask?.cancel()
            pendingPrepareTask = nil
            try await executeEngineCommand {
                try await engine.stop(reason: .userClosed)
            }
            currentSource = nil
            transition(to: .idle)
        }
    }

    private func performStart(source: PlaybackSource, policy: PlayerFeaturePolicy) async throws {
        try Task.checkCancellation()
        try await engine.prepare(source: source)
        try Task.checkCancellation()

        if policy.allowsAutoplay {
            try await engine.play()
        }
    }

    private func executeEngineCommand(_ operation: () async throws -> Void) async throws {
        do {
            try await operation()
        } catch {
            let playerError = mapToPlayerError(error)
            transition(to: currentState.updating(status: .failed(playerError), isBuffering: false))
            publish(event: .didFail(playerError))
            throw playerError
        }
    }

    private func consume(engineEvent: PlayerEvent) {
        switch engineEvent {
        case .stateDidChange(let state):
            transition(to: state)
        case .timeDidChange(let currentTime, let duration):
            let nextState = currentState.updating(currentTime: currentTime, duration: duration)
            transition(to: nextState, emitEvent: false)
            publish(event: engineEvent)
        case .bufferingDidChange(let isBuffering):
            let nextStatus: PlaybackState.Status
            if isBuffering {
                nextStatus = .buffering
            } else if case .readyToPlay = currentState.status {
                nextStatus = .readyToPlay
            } else {
                nextStatus = .playing
            }

            let nextState = currentState.updating(status: nextStatus, isBuffering: isBuffering)
            transition(to: nextState, emitEvent: false)
            publish(event: engineEvent)
        case .didFinish:
            transition(to: currentState.updating(status: .finished, isBuffering: false))
            publish(event: .didFinish)
        case .didFail(let error):
            transition(to: currentState.updating(status: .failed(error), isBuffering: false))
            publish(event: .didFail(error))
        case .policyDowngraded:
            publish(event: engineEvent)
        case .captionDidUpdate,
             .bookmarksDidLoad,
             .bitrateDidChange,
             .heightDidChange,
             .externalOutputDidChange,
             .naturalSizeDidResolve,
             .framerateDidResolve,
             .deviceLockPolicyChanged,
             .nextEpisodeAvailable:
            publish(event: engineEvent)
        }
    }

    private func transition(to nextState: PlaybackState, emitEvent: Bool = true) {
        currentState = nextState
        stateContinuation.yield(nextState)

        if emitEvent {
            publish(event: .stateDidChange(nextState))
        }
    }

    private func publish(event: PlayerEvent) {
        eventContinuation.yield(event)
    }

    private func applyEffectivePolicy(_ policy: PlayerFeaturePolicy) -> (policy: PlayerFeaturePolicy, reason: PolicyDowngradeReason?) {
        guard policy.allowsBackgroundPlayback else {
            return (policy, nil)
        }

        guard engineCapabilities.contains(.continuesWithoutSurface) else {
            return (
                PlayerFeaturePolicy(
                    allowsBackgroundPlayback: false,
                    maxPlaybackRate: policy.maxPlaybackRate,
                    allowsAutoplay: policy.allowsAutoplay,
                    skipInterval: policy.skipInterval,
                    nextEpisodeButtonLeadTime: policy.nextEpisodeButtonLeadTime
                ),
                .missingContinuesWithoutSurface
            )
        }

        return (policy, nil)
    }

    private func setPlaybackRate(_ rate: Double) async throws {
        guard rate > 0 else {
            throw PlayerError.engineError("Playback rate must be greater than 0. rate=\(rate)")
        }

        guard rate <= Double(currentPolicy.maxPlaybackRate) else {
            throw PlayerError.engineError("Playback rate \(rate)x exceeds max policy rate \(currentPolicy.maxPlaybackRate)x.")
        }

        guard let rateEngine = engine as? any PlayerPlaybackRateEngine else {
            throw PlayerError.engineError("Playback rate \(rate)x is not supported by the current playback engine.")
        }

        try await rateEngine.setPlaybackRate(rate)
    }

    private func setSkipInterval(_ interval: TimeInterval) throws {
        guard interval > 0 else {
            throw PlayerError.engineError("Skip interval must be greater than 0. interval=\(interval)")
        }

        currentPolicy = PlayerFeaturePolicy(
            allowsBackgroundPlayback: currentPolicy.allowsBackgroundPlayback,
            maxPlaybackRate: currentPolicy.maxPlaybackRate,
            allowsAutoplay: currentPolicy.allowsAutoplay,
            skipInterval: interval,
            nextEpisodeButtonLeadTime: currentPolicy.nextEpisodeButtonLeadTime
        )
    }

    private func setSubtitleVisible(_ isVisible: Bool) async throws {
        guard let subtitleEngine = engine as? any PlayerSubtitleEngine else {
            throw PlayerError.engineError("Subtitle visibility is not supported by the current playback engine.")
        }

        try await subtitleEngine.setSubtitleVisible(isVisible)
    }

    private func selectSubtitleTrack(_ trackID: PlayerSubtitleTrackID?) async throws {
        guard let subtitleEngine = engine as? any PlayerSubtitleEngine else {
            throw PlayerError.engineError("Subtitle track selection is not supported by the current playback engine.")
        }

        try await subtitleEngine.selectSubtitleTrack(trackID)
    }

    private func setCaptionFontSize(_ fontSize: Int) async throws {
        guard fontSize > 0 else {
            throw PlayerError.engineError("Caption font size must be greater than 0. fontSize=\(fontSize)")
        }

        guard let subtitleEngine = engine as? any PlayerSubtitleEngine else {
            throw PlayerError.engineError("Caption font size is not supported by the current playback engine.")
        }

        try await subtitleEngine.setCaptionFontSize(fontSize)
    }

    private func addBookmark(at time: TimeInterval, title: String) async throws {
        guard time >= 0 else {
            throw PlayerError.engineError("Bookmark time must be greater than or equal to 0. time=\(time)")
        }

        guard let bookmarkEngine = engine as? any PlayerBookmarkEngine else {
            throw PlayerError.engineError("Bookmark mutation is not supported by the current playback engine.")
        }

        if title.isEmpty {
            try await bookmarkEngine.addBookmark(at: time)
        } else if let titledEngine = bookmarkEngine as? any PlayerTitledBookmarkEngine {
            try await titledEngine.addBookmark(at: time, title: title)
        } else {
            try await bookmarkEngine.addBookmark(at: time)
        }
    }

    private func removeBookmark(at time: TimeInterval) async throws {
        guard time >= 0 else {
            throw PlayerError.engineError("Bookmark time must be greater than or equal to 0. time=\(time)")
        }

        guard let bookmarkEngine = engine as? any PlayerTitledBookmarkEngine else {
            throw PlayerError.engineError("Bookmark removal is not supported by the current playback engine.")
        }

        try await bookmarkEngine.removeBookmark(at: time)
    }

    private func selectSubtitleFile(_ fileURL: URL?) async throws {
        guard let subtitleEngine = engine as? any PlayerExternalSubtitleEngine else {
            throw PlayerError.engineError("External subtitle file selection is not supported by the current playback engine.")
        }

        try await subtitleEngine.selectSubtitleFile(fileURL)
    }

    private func setDisplayLocked(_ isLocked: Bool) async throws {
        guard let displayEngine = engine as? any PlayerDisplayLockEngine else {
            throw PlayerError.engineError("Display lock is not supported by the current playback engine.")
        }

        try await displayEngine.setDisplayLocked(isLocked)
    }

    private func setDisplayScaled(_ isScaled: Bool) async throws {
        try await setDisplayScaleMode(isScaled ? .aspectFill : .aspectFit)
    }

    private func setDisplayScaleMode(_ mode: PlayerDisplayScaleMode) async throws {
        guard let displayEngine = engine as? any PlayerDisplayScalingEngine else {
            throw PlayerError.engineError("Display scaling is not supported by the current playback engine.")
        }

        try await displayEngine.setDisplayScaleMode(mode)
    }

    private func toggleDisplayScaling() async throws {
        try await toggleDisplayScaleMode()
    }

    private func toggleDisplayScaleMode() async throws {
        guard let displayEngine = engine as? any PlayerDisplayScalingEngine else {
            throw PlayerError.engineError("Display scaling is not supported by the current playback engine.")
        }

        try await displayEngine.toggleDisplayScaleMode()
    }

    private func seekTargetTime(
        for requestedTime: TimeInterval,
        origin: PlayerSeekOrigin
    ) -> TimeInterval {
        let rawTargetTime: TimeInterval

        switch origin {
        case .skipForward:
            rawTargetTime = currentState.currentTime + currentPolicy.skipInterval
        case .skipBackward:
            rawTargetTime = currentState.currentTime - currentPolicy.skipInterval
        default:
            rawTargetTime = requestedTime
        }

        guard currentState.duration > 0 else {
            return max(0, rawTargetTime)
        }

        return min(max(0, rawTargetTime), currentState.duration)
    }

    private func mapToPlayerError(_ error: Error) -> PlayerError {
        if let playerError = error as? PlayerError {
            return playerError
        }

        return .unknown((error as NSError).localizedDescription)
    }
}
