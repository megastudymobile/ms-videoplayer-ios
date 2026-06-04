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
    /// H5/H7 — prepare 작업의 세대(generation). `start` 진입마다 증가하며, await 복귀 후
    /// `generation == prepareGeneration`인 경우에만 "내가 아직 최신 작업"이다.
    /// 더 새로운 `start`/`.stop`이 끼어들면 generation이 어긋나 stale 정리/실패 surfacing을 막는다.
    private var prepareGeneration: Int = 0
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

    public func dispose() async {
        pendingPrepareTask?.cancel()
        pendingPrepareTask = nil

        // H10/M1 — teardown 시 engine.stop을 idempotent하게 선행한다.
        // 정상 경로는 viewWillDisappear의 `.stop`이 이미 선행되지만(중복 stop은 무해),
        // 비정상 종료(.stop 누락)에서는 이 호출이 playerView/proxy 세션 잔류와
        // KollusProxyPlayerView 타이머 크래시를 막는 최종 방어선이다.
        try? await engine.stop(reason: .appLifecycle)

        engineEventTask?.cancel()
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

        prepareGeneration &+= 1
        let generation = prepareGeneration

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
            // H5 — 내가 최신 세대일 때만 pending 정리(진행 중인 새 작업을 nil化하지 않음).
            if generation == prepareGeneration {
                pendingPrepareTask = nil
            }
        } catch is CancellationError {
            // H4 — 취소로 끝났고 더 새로운 작업이 상태를 바꾸지 않았으면 .idle로 복원.
            // `.stop`은 이미 .idle을 설정하므로 status가 .preparing일 때만 복원해 이중 전이를 피한다.
            if generation == prepareGeneration {
                pendingPrepareTask = nil
                if case .preparing = currentState.status {
                    transition(to: .idle)
                }
            }
        } catch {
            let playerError = mapToPlayerError(error)
            // H7 — superseded(더 새로운 start로 교체됨) 실패는 상태/이벤트 스트림에 반영하지 않는다.
            // 그래야 두 번째 load가 성공해도 첫 load의 실패가 UI에 깜빡이지 않는다.
            if generation == prepareGeneration {
                pendingPrepareTask = nil
                transition(to: currentState.updating(status: .failed(playerError), isBuffering: false))
                publish(event: .didFail(playerError))
            }
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
            // M4 — 미확정 duration(0)이 이미 확정된 duration을 덮어쓰지 않도록 보호.
            let resolvedDuration = duration > 0 ? duration : currentState.duration
            let nextState = currentState.updating(currentTime: currentTime, duration: resolvedDuration)
            transition(to: nextState, emitEvent: false)
            publish(event: engineEvent)
        case .bufferingDidChange(let isBuffering):
            // M3 — terminal 상태(.finished/.failed)는 늦게 도착한 buffering 이벤트로 되살리지 않는다.
            if case .finished = currentState.status {
                publish(event: engineEvent)
                return
            }
            if case .failed = currentState.status {
                publish(event: engineEvent)
                return
            }

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

        guard rate <= currentPolicy.maxPlaybackRate else {
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
        // H3 — network/auth/decoding을 분류해 UI가 실패 원인을 구분할 수 있게 한다.
        PlayerError.classify(error)
    }
}
