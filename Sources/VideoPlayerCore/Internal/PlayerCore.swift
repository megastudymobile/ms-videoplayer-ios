//
//  PlayerCore.swift
//  VideoPlayerModule
//
//  Created by 모바일팀_정준영 on 2026/04/17.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import Foundation

public actor PlayerCore {
    public nonisolated let stateStream: AsyncStream<PlaybackState>
    public nonisolated let eventStream: AsyncStream<PlayerEvent>
    /// 엔진의 optional protocol 채택으로 산출한 가용 기능 — UI 버튼 사전 게이트용.
    public nonisolated let availableFeatures: Set<PlayerFeature>

    private let engine: PlayerPlaybackEngine
    private let engineRuntimeTraits: EngineRuntimeTraits
    private let logger: any PlayerLogger
    private let stateReducer = PlaybackStateReducer()
    /// seek "chase" 정책 (Apple QA1820 패턴). 엔진 seek은 동시에 **1개만** in-flight.
    /// - `chaseTime`: 아직 엔진에 보내지 않은 최신 목표(연타 시 여기에 누적).
    /// - `seekInProgressValue`: 현재 엔진에 보낸 seek 목표(nil = in-flight 없음).
    /// 진행 중 seek이 목표 근처에 도달(완료)하면, `chaseTime`이 있으면 그쪽으로 다시 seek(chase),
    /// 없으면 완료 처리한다. 완료 전 들어오는 stale/echo positionChanged는 전부 무시한다.
    /// (탭마다 엔진 seek을 쏟아부으면 SDK가 위치 콜백을 뒤섞어 진동/롤백이 생긴다.)
    private var chaseTime: TimeInterval?
    private var seekInProgressValue: TimeInterval?
    private static let seekSettleThreshold: TimeInterval = 3.0
    private var pendingPrepareTask: Task<Void, Error>?
    private var pendingSeekTask: Task<Void, Never>?
    /// prepare 작업의 세대(generation). `start` 진입마다 증가하며, await 복귀 후
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
        engineRuntimeTraits: EngineRuntimeTraits,
        initialPolicy: PlayerFeaturePolicy = .default,
        logger: any PlayerLogger = NoopPlayerLogger()
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
        self.engineRuntimeTraits = engineRuntimeTraits
        self.logger = logger
        self.availableFeatures = PlayerFeature.available(for: engine)
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

        let stream = await engine.outputStream
        engineEventTask = Task { [weak self] in
            for await output in stream {
                guard let self else {
                    return
                }
                await self.consume(engineOutput: output)
            }
        }
    }

    public func dispose() async {
        pendingPrepareTask?.cancel()
        pendingPrepareTask = nil
        pendingSeekTask?.cancel()
        pendingSeekTask = nil

        // teardown 시 engine.stop을 idempotent하게 선행한다.
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
        // 동일 source가 이미 준비 중이면 중복 .load를 coalesce(무시)한다 — defense-in-depth.
        // 강의 종료 자동전환 + 다음강의 버튼 등으로 같은 source가 거의 동시에 두 번 load되면
        // prepare가 cancel-restart되며 Kollus 다운로드가 충돌(ResCode 23/42)해 한쪽 prepare가 실패한다.
        // 다른 source의 load는 기존 newest-wins(cancel-restart)를 그대로 유지한다.
        if currentSource == source, pendingPrepareTask != nil, case .preparing = currentState.status {
            return
        }

        let effectivePolicy = applyEffectivePolicy(policy)
        currentPolicy = effectivePolicy.policy
        currentSource = source
        chaseTime = nil
        seekInProgressValue = nil

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
            // 내가 최신 세대일 때만 pending 정리(진행 중인 새 작업을 nil化하지 않음).
            if generation == prepareGeneration {
                pendingPrepareTask = nil
            }
        } catch is CancellationError {
            // 취소로 끝났고 더 새로운 작업이 상태를 바꾸지 않았으면 .idle로 복원.
            // `.stop`은 이미 .idle을 설정하므로 status가 .preparing일 때만 복원해 이중 전이를 피한다.
            if generation == prepareGeneration {
                pendingPrepareTask = nil
                if case .preparing = currentState.status {
                    transition(to: .idle)
                }
            }
        } catch {
            let playerError = mapToPlayerError(error)
            // superseded(더 새로운 start로 교체됨) 실패는 상태/이벤트 스트림에 반영하지 않는다.
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
            // 권위 콜백 엔진(Kollus)은 outputStream `.playStarted`가 상태를 만든다.
            // 권위 콜백이 없는 엔진(Native)은 Core가 command-origin으로 닫는다.
            applyCommandOriginIfNeeded(.playStarted)
        case .pause:
            try await executeEngineCommand {
                try await engine.pause()
            }
            applyCommandOriginIfNeeded(.pauseStarted)
        case .seek(let time):
            // 단순 seek은 직접 await해 에러를 caller에게 propagate한다.
            // (.seekWithOrigin 연타는 chase 패턴으로 비차단 처리.)
            chaseTime = nil
            seekInProgressValue = nil
            apply(stateReducer.reduce(.seeking(time: time), state: currentState))
            try await executeEngineCommand {
                try await engine.seek(to: time)
            }
        case .seekWithOrigin(let time, let origin):
            // 연타 skip은 chase 패턴(단일 in-flight)으로 처리한다. actor 재진입 때문에 await-per-tap으로는
            // 직렬화되지 않아 SDK에 seek이 쏟아져 위치 콜백이 진동(롤백)한다. 최신 목표만 chaseTime에
            // 누적하고 in-flight seek 완료 시 그쪽으로 chase한다.
            let base = chaseTime ?? seekInProgressValue ?? currentState.currentTime
            requestSeek(to: seekTargetTime(for: time, origin: origin, base: base))
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
            chaseTime = nil
            seekInProgressValue = nil
            // stop은 양쪽 엔진 모두 command-origin으로 닫아도 안전(.idle은 멱등).
            apply(stateReducer.reduce(.stopped(.userClosed), state: currentState))
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
            // play/pause/seek/stop 같은 런타임 명령의 실패는 일시적·복구 가능하다(빠른 스크럽/전환 중
            // Kollus가 간헐적으로 _GenericObjCError를 throw). 이를 치명적 `.failed` 상태/alert로 만들면
            // 한 번의 transient throw로 플레이어가 실패에 갇힌다. 따라서 상태를 바꾸지 않고 삼킨다.
            // (영상 로드 자체의 실패는 prepare 경로 `start(...)`에서 별도로 치명적으로 처리된다.)
            logger.warning(
                "transient engine command failure ignored: \(error)",
                category: PlayerLogCategory.core
            )
        }
    }

    private func consume(engineOutput: PlayerEngineOutput) {
        switch engineOutput {
        case .stateInput(let input):
            // in-flight seek 정책: 정착 전(SDK가 목표 근처 도달 전) stale positionChanged는 버린다.
            // 목표 근처에 도달하면 pending을 해제하고 통과시켜 로딩을 내린다.
            if case .positionChanged(let time, _) = input, let inProgress = seekInProgressValue {
                guard abs(time - inProgress) <= Self.seekSettleThreshold else {
                    logger.debug(
                        "drop stale position \(time) (seek in progress -> \(inProgress))",
                        category: PlayerLogCategory.core
                    )
                    return
                }
                // 이 leg는 목표에 도달(완료). 더 새 목표(chaseTime)가 있으면 그쪽으로 다시 seek.
                if let next = chaseTime {
                    chaseTime = nil
                    seekInProgressValue = next
                    dispatchEngineSeek(to: next)
                    return // 아직 chase 진행 중 — 이 위치는 반영하지 않음
                }
                seekInProgressValue = nil // 완전 정착 → 아래로 진행해 위치 반영 + 로딩 해제
            } else if seekInProgressValue != nil {
                // positionChanged가 아닌 권위 전이(play/pause/stopped/prepared/failed)는 chase를 끝낸다.
                seekInProgressValue = nil
                chaseTime = nil
            }
            // 상태를 움직이는 입력은 reducer가 유일하게 다음 상태를 만든다.
            let reduced = stateReducer.reduce(input, state: currentState)
            // source 전환 후 늦게 도착한 stale `.prepared`가 새 상태를 덮는지 관찰하기 위한 추적 로그.
            logger.debug(
                "\(input) | \(currentState.status) -> \(reduced.next.status) | source=\(String(describing: currentSource))",
                category: PlayerLogCategory.core
            )
            apply(reduced)
        case .event(.stateDidChange(let state)):
            // Compatibility guard: custom engine이 예전 full-state 이벤트를 보내도
            // Core stateStream과 eventStream이 서로 어긋나지 않게 맞춘다.
            transition(to: state)
        case .event(let event):
            // 상태를 움직이지 않는 이벤트는 passthrough.
            logger.debug("event \(event)", category: PlayerLogCategory.core)
            publish(event: event)
        }
    }

    /// reducer 출력을 상태/스트림에 반영한다. Core만 `currentState`를 만든다.
    private func apply(_ output: PlaybackStateReducerOutput) {
        currentState = output.next
        stateContinuation.yield(output.next)
        output.events.forEach { publish(event: $0) }
    }

    /// 권위 콜백이 없는 엔진(`.commandSuccessClosesState`, 예: Native)에서만 명령 성공 직후
    /// command-origin 입력을 reducer에 넣는다. 권위 콜백이 있는 엔진(Kollus)은 outputStream의
    /// `.stateInput`이 상태를 만들므로 여기서 또 넣으면 이중 적용/경합이 된다.
    private func applyCommandOriginIfNeeded(_ input: PlaybackStateInput) {
        guard engineRuntimeTraits.stateAuthority == .commandSuccessClosesState else {
            logger.debug(
                "skip command-origin (engine emits observed state): \(input)",
                category: PlayerLogCategory.core
            )
            return
        }
        logger.debug("command-origin \(input)", category: PlayerLogCategory.core)
        apply(stateReducer.reduce(input, state: currentState))
    }

    /// seek 요청(chase 패턴). 목표를 즉시 UI에 반영(.seeking: 점프+로딩)하고, in-flight seek이 없으면
    /// 엔진 seek을 1개 시작한다. in-flight 중이면 `chaseTime`만 갱신해 완료 시 chase한다.
    private func requestSeek(to target: TimeInterval) {
        chaseTime = target
        // 즉시 점프 + 로딩 표시. 완료 시 positionChanged가 로딩을 내린다.
        apply(stateReducer.reduce(.seeking(time: target), state: currentState))
        startChaseIfNeeded()
    }

    private func startChaseIfNeeded() {
        guard seekInProgressValue == nil, let chase = chaseTime else {
            return
        }
        chaseTime = nil
        seekInProgressValue = chase
        dispatchEngineSeek(to: chase)
    }

    /// 엔진 seek을 비차단으로 발행한다(완료는 positionChanged로 감지). 동시 1개만 보장됨.
    /// dispose()가 in-flight seek을 취소할 수 있도록 Task를 보관한다.
    private func dispatchEngineSeek(to target: TimeInterval) {
        pendingSeekTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.engine.seek(to: target)
            } catch {
                guard !Task.isCancelled else { return }
                await self.handleSeekFailure(error)
            }
        }
    }

    private func handleSeekFailure(_ error: Error) {
        // seek 실패는 일시적이다(빠른 스크럽/프리뷰 중 Kollus가 간헐적으로 _GenericObjCError를 throw).
        // 치명적 `.failed` 상태/alert로 승격하지 않는다 — in-flight만 정리하고, 대기 중인 최신 목표가
        // 있으면 계속 chase한다. (한 번의 스크럽 throw로 플레이어 전체가 실패 상태에 갇히던 문제 수정.)
        logger.warning(
            "transient seek failure ignored: \(error)",
            category: PlayerLogCategory.core
        )
        seekInProgressValue = nil
        startChaseIfNeeded()
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

        guard engineRuntimeTraits.surface.continuesWithoutSurface else {
            return (
                PlayerFeaturePolicy(
                    allowsBackgroundPlayback: false,
                    allowedPlaybackRates: policy.allowedPlaybackRates,
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

        guard currentPolicy.allowsPlaybackRate(rate) else {
            throw PlayerError.engineError("Playback rate \(rate)x is not allowed by policy. allowed=\(currentPolicy.allowedPlaybackRates)")
        }

        guard let rateEngine = engine as? any EnginePlaybackRateAbility else {
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
            allowedPlaybackRates: currentPolicy.allowedPlaybackRates,
            allowsAutoplay: currentPolicy.allowsAutoplay,
            skipInterval: interval,
            nextEpisodeButtonLeadTime: currentPolicy.nextEpisodeButtonLeadTime
        )
    }

    private func setSubtitleVisible(_ isVisible: Bool) async throws {
        guard let subtitleEngine = engine as? any EngineSubtitleAbility else {
            throw PlayerError.engineError("Subtitle visibility is not supported by the current playback engine.")
        }

        try await subtitleEngine.setSubtitleVisible(isVisible)
    }

    private func selectSubtitleTrack(_ trackID: PlayerSubtitleTrackID?) async throws {
        guard let subtitleEngine = engine as? any EngineSubtitleAbility else {
            throw PlayerError.engineError("Subtitle track selection is not supported by the current playback engine.")
        }

        try await subtitleEngine.selectSubtitleTrack(trackID)
    }

    private func setCaptionFontSize(_ fontSize: Int) async throws {
        guard fontSize > 0 else {
            throw PlayerError.engineError("Caption font size must be greater than 0. fontSize=\(fontSize)")
        }

        guard let subtitleEngine = engine as? any EngineSubtitleAbility else {
            throw PlayerError.engineError("Caption font size is not supported by the current playback engine.")
        }

        try await subtitleEngine.setCaptionFontSize(fontSize)
    }

    private func addBookmark(at time: TimeInterval, title: String) async throws {
        guard time >= 0 else {
            throw PlayerError.engineError("Bookmark time must be greater than or equal to 0. time=\(time)")
        }

        guard let bookmarkEngine = engine as? any EngineBookmarkAbility else {
            throw PlayerError.engineError("Bookmark mutation is not supported by the current playback engine.")
        }

        if title.isEmpty {
            try await bookmarkEngine.addBookmark(at: time)
        } else if let titledEngine = bookmarkEngine as? any EngineTitledBookmarkAbility {
            try await titledEngine.addBookmark(at: time, title: title)
        } else {
            try await bookmarkEngine.addBookmark(at: time)
        }
    }

    private func removeBookmark(at time: TimeInterval) async throws {
        guard time >= 0 else {
            throw PlayerError.engineError("Bookmark time must be greater than or equal to 0. time=\(time)")
        }

        guard let bookmarkEngine = engine as? any EngineTitledBookmarkAbility else {
            throw PlayerError.engineError("Bookmark removal is not supported by the current playback engine.")
        }

        try await bookmarkEngine.removeBookmark(at: time)
    }

    private func selectSubtitleFile(_ fileURL: URL?) async throws {
        guard let subtitleEngine = engine as? any EngineExternalSubtitleAbility else {
            throw PlayerError.engineError("External subtitle file selection is not supported by the current playback engine.")
        }

        try await subtitleEngine.selectSubtitleFile(fileURL)
    }

    private func setDisplayLocked(_ isLocked: Bool) async throws {
        guard let displayEngine = engine as? any EngineDisplayLockAbility else {
            throw PlayerError.engineError("Display lock is not supported by the current playback engine.")
        }

        try await displayEngine.setDisplayLocked(isLocked)
    }

    private func setDisplayScaled(_ isScaled: Bool) async throws {
        try await setDisplayScaleMode(isScaled ? .aspectFill : .aspectFit)
    }

    private func setDisplayScaleMode(_ mode: PlayerDisplayScaleMode) async throws {
        guard let displayEngine = engine as? any EngineDisplayScalingAbility else {
            throw PlayerError.engineError("Display scaling is not supported by the current playback engine.")
        }

        try await displayEngine.setDisplayScaleMode(mode)
    }

    private func toggleDisplayScaling() async throws {
        try await toggleDisplayScaleMode()
    }

    private func toggleDisplayScaleMode() async throws {
        guard let displayEngine = engine as? any EngineDisplayScalingAbility else {
            throw PlayerError.engineError("Display scaling is not supported by the current playback engine.")
        }

        try await displayEngine.toggleDisplayScaleMode()
    }

    private func seekTargetTime(
        for requestedTime: TimeInterval,
        origin: PlayerSeekOrigin,
        base: TimeInterval
    ) -> TimeInterval {
        let rawTargetTime: TimeInterval

        switch origin {
        case .skipForward:
            rawTargetTime = base + currentPolicy.skipInterval
        case .skipBackward:
            rawTargetTime = base - currentPolicy.skipInterval
        default:
            rawTargetTime = requestedTime
        }

        guard currentState.duration > 0 else {
            return max(0, rawTargetTime)
        }

        return min(max(0, rawTargetTime), currentState.duration)
    }

    private func mapToPlayerError(_ error: Error) -> PlayerError {
        // network/auth/decoding을 분류해 UI가 실패 원인을 구분할 수 있게 한다.
        PlayerError.classify(error)
    }
}
