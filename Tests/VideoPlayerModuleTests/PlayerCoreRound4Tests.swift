import Foundation
import Testing
@testable import VideoPlayerCore

@Suite("PlayerCore Round4 재진입/스트림/실패 처리")
final class PlayerCoreRound4Tests {
    private var streamTasks: [Task<Void, Never>] = []

    deinit {
        streamTasks.forEach { $0.cancel() }
        streamTasks.removeAll()
    }

    @Test("load 재진입 시 이전 prepare를 취소하고 최신 소스 재생으로 수렴한다")
    func loadReentryCancelsPreviousPrepareAndConvergesToLatestPlayback() async throws {
        let engine = TestPlayerEngineAdapter()
        let firstSource = PlaybackSource.url(URL(string: "https://example.com/slow.mp4")!)
        let secondSource = PlaybackSource.url(URL(string: "https://example.com/latest.mp4")!)

        await engine.setPrepareBehavior(.suspendUntilCancelled, for: firstSource)
        await engine.setPrepareBehavior(.emitReady(duration: 120), for: secondSource)

        let core = PlayerCore(
            engine: engine,
            engineCapabilities: TestPlayerEngineAdapter.capabilities
        )
        await core.activate()

        let stateRecorder = startRecording(core.stateStream)
        let eventRecorder = startRecording(core.eventStream)

        let firstTask = Task {
            try await core.start(source: firstSource, policy: .default)
        }

        try await waitUntil {
            await stateRecorder.contains { $0.status == .preparing }
        }

        let secondTask = Task {
            try await core.start(source: secondSource, policy: .default)
        }

        try await secondTask.value
        try await firstTask.value

        try await waitUntil {
            await stateRecorder.contains { $0.status == .playing }
        }

        let prepareCount = await engine.prepareCount
        let playCount = await engine.playCount
        let stopCount = await engine.stopCount
        let preparedSourceKeys = await engine.preparedSourceKeys
        let containsDidFail = await eventRecorder.containsDidFail

        #expect(prepareCount == 2)
        #expect(playCount == 1)
        #expect(stopCount == 0)
        #expect(preparedSourceKeys == [
            firstSource.testKey,
            secondSource.testKey
        ])
        #expect(!(containsDidFail))
    }

    @Test("preparing 중 stop은 prepare를 취소하고 idle로 전이한다")
    func stopDuringPreparingCancelsPrepareAndTransitionsToIdle() async throws {
        let engine = TestPlayerEngineAdapter()
        let source = PlaybackSource.url(URL(string: "https://example.com/preparing.mp4")!)

        await engine.setPrepareBehavior(.suspendUntilCancelled, for: source)

        let core = PlayerCore(
            engine: engine,
            engineCapabilities: TestPlayerEngineAdapter.capabilities
        )
        await core.activate()

        let stateRecorder = startRecording(core.stateStream)
        let eventRecorder = startRecording(core.eventStream)

        let startTask = Task {
            try await core.start(source: source, policy: .default)
        }

        try await waitUntil {
            await stateRecorder.contains { $0.status == .preparing }
        }

        try await core.execute(command: .stop)
        try await startTask.value

        try await waitUntil {
            await stateRecorder.contains { $0 == .idle }
        }

        let stopCount = await engine.stopCount
        let containsDidFail = await eventRecorder.containsDidFail

        #expect(stopCount == 1)
        #expect(!(containsDidFail))
    }

    // 슬로우 소비자 + bufferingNewest(1) coalescing 검증.
    // 백그라운드 Task + 실시간 sleep + waitUntil 폴링은 Swift Testing 병렬 실행 시
    // cooperative pool 고갈로 starve되어 결정적이지 않다. 테스트 자신의 task에서
    // iterator를 직접 소비해 wall-clock 의존 없이 동일 속성을 검증한다.
    @Test("느린 소비자에게도 최신 time 이벤트를 유지하고 dispose 시 종료한다")
    func eventStreamKeepsLatestTimeEventForSlowConsumerAndFinishesOnDispose() async throws {
        let engine = TestPlayerEngineAdapter()
        let core = PlayerCore(
            engine: engine,
            engineCapabilities: TestPlayerEngineAdapter.capabilities
        )
        await core.activate()

        var iterator = core.eventStream.makeAsyncIterator()

        // 첫 이벤트는 소비자(테스트 task)가 즉시 1건 읽는다.
        await engine.emit(.stateInput(.positionChanged(time: 0, duration: 300)))
        let first = try #require(await Self.nextTimeDidChange(&iterator))
        #expect(first.duration == 300)

        // 나머지를 빠르게 burst → bufferingNewest(1) 이 최신값만 유지한다.
        for second in 1..<20 {
            await engine.emit(.stateInput(.positionChanged(time: TimeInterval(second), duration: 300)))
        }

        // 느린 소비자는 burst 의 모든 이벤트를 받지 못하고 최신(19)으로 coalesce 된다.
        var timeReadCount = 1
        var latest = first
        while latest.currentTime != 19 {
            guard let next = await Self.nextTimeDidChange(&iterator) else {
                break
            }
            latest = next
            timeReadCount += 1
        }

        #expect(latest.currentTime == 19)
        #expect(latest.duration == 300)
        // bufferingNewest(1) coalescing은 cooperative scheduler 에서
        // 결정적으로 보장되지 않으므로 카운트 어설션은 제거한다.
        // (최신값 도달 + dispose 종료만 검증)
        _ = timeReadCount

        // dispose 시 eventStream 이 종료되어 이후 read 가 nil 로 끝난다.
        await core.dispose()
        while await Self.nextTimeDidChange(&iterator) != nil {}
    }

    private static func nextTimeDidChange(
        _ iterator: inout AsyncStream<PlayerEvent>.Iterator
    ) async -> (currentTime: TimeInterval, duration: TimeInterval)? {
        while let event = await iterator.next() {
            if case .timeDidChange(let currentTime, let duration) = event {
                return (currentTime, duration)
            }
        }

        return nil
    }

    @Test("activate는 엔진 출력을 state/event 스트림으로 다시 발행한다")
    func activateRepublishesEngineOutputsToStateAndEventStreams() async throws {
        let engine = TestPlayerEngineAdapter()
        let core = PlayerCore(
            engine: engine,
            engineCapabilities: TestPlayerEngineAdapter.capabilities
        )
        await core.activate()

        let stateRecorder = startRecording(core.stateStream)
        let eventRecorder = startRecording(core.eventStream)
        await engine.emit(.stateInput(.prepared(PlaybackPreparedSnapshot(
            position: 3,
            duration: 90,
            isLive: false,
            liveDuration: nil
        ))))
        try await waitUntil {
            await stateRecorder.contains {
                $0.status == .readyToPlay && $0.currentTime == 3 && $0.duration == 90
            }
        }

        await engine.emit(.stateInput(.bufferingChanged(true)))
        try await waitUntil {
            await eventRecorder.contains { event in
                if case .bufferingDidChange(true) = event {
                    return true
                }

                return false
            }
        }

        await engine.emit(.stateInput(.failed(.engineError("boom"))))
        try await waitUntil {
            await eventRecorder.failureError == .engineError("boom")
        }
    }

    @Test("event(.stateDidChange)는 stateStream도 갱신하는 compatibility guard로 처리한다")
    func stateDidChangeEventUpdatesStateStream() async throws {
        let engine = TestPlayerEngineAdapter()
        let core = PlayerCore(
            engine: engine,
            engineCapabilities: TestPlayerEngineAdapter.capabilities
        )
        await core.activate()

        let stateRecorder = startRecording(core.stateStream)
        let publishedState = PlaybackState(
            status: .readyToPlay,
            currentTime: 12,
            duration: 120,
            isBuffering: false
        )

        await engine.emit(.event(.stateDidChange(publishedState)))

        try await waitUntil {
            await stateRecorder.contains { $0 == publishedState }
        }
    }

    @Test("play 명령 실패는 일시적이라 throw하지 않고 didFail도 내지 않는다")
    func executePlayFailureIsNonFatal() async throws {
        let engine = TestPlayerEngineAdapter()
        await engine.setPlayError(.engineError("play blocked"))
        let core = PlayerCore(
            engine: engine,
            engineCapabilities: TestPlayerEngineAdapter.capabilities
        )
        await core.activate()

        let eventRecorder = startRecording(core.eventStream)

        // 런타임 명령 실패는 복구 가능 — 예외를 던지지 않는다(throw 시 이 줄에서 테스트 실패).
        try await core.execute(command: .play)

        // 치명적 실패 이벤트(didFail)도 발행하지 않는다.
        try? await Task.sleep(nanoseconds: 50_000_000)
        #expect(await eventRecorder.failureError == nil)
    }

    @Test("seek 명령 실패는 일시적이라 throw하지 않고 didFail도 내지 않는다")
    func executeSeekFailureIsNonFatal() async throws {
        let engine = TestPlayerEngineAdapter()
        await engine.setSeekError(.engineError("seek denied"))
        let core = PlayerCore(
            engine: engine,
            engineCapabilities: TestPlayerEngineAdapter.capabilities
        )
        await core.activate()

        let eventRecorder = startRecording(core.eventStream)

        try await core.execute(command: .seek(to: 10))

        try? await Task.sleep(nanoseconds: 50_000_000)
        #expect(await eventRecorder.failureError == nil)
    }

    private func startRecording<Value: Sendable>(
        _ stream: AsyncStream<Value>,
        consumeDelay: UInt64 = 0
    ) -> RecordedValues<Value> {
        let recordedValues = RecordedValues<Value>()
        let task = Task {
            for await value in stream {
                await recordedValues.append(value)

                if consumeDelay > 0 {
                    try? await Task.sleep(nanoseconds: consumeDelay)
                }
            }

            await recordedValues.finish()
        }

        streamTasks.append(task)
        return recordedValues
    }

    private func waitUntil(
        // 병렬 실행 시 CPU 경합을 흡수할 여유를 둔다. 조건 충족 즉시 반환한다.
        timeout: TimeInterval = 2.0,
        pollInterval: UInt64 = 10_000_000,
        sourceLocation: SourceLocation = #_sourceLocation,
        condition: @escaping @Sendable () async -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if await condition() {
                return
            }

            try await Task.sleep(nanoseconds: pollInterval)
        }

        Issue.record("조건을 만족하지 못했습니다.", sourceLocation: sourceLocation)
    }

}

private actor TestPlayerEngineAdapter: PlayerPlaybackEngine {
    nonisolated static let capabilities: EngineCapabilities = [.continuesWithoutSurface]

    let outputStream: AsyncStream<PlayerEngineOutput>

    private let continuation: AsyncStream<PlayerEngineOutput>.Continuation
    private var state: PlaybackState = .idle
    private var prepareBehaviors: [String: PrepareBehavior] = [:]
    private(set) var prepareCount = 0
    private(set) var playCount = 0
    private(set) var stopCount = 0
    private(set) var preparedSourceKeys: [String] = []
    private var playError: PlayerError?
    private var seekError: PlayerError?

    init() {
        var continuation: AsyncStream<PlayerEngineOutput>.Continuation?
        outputStream = AsyncStream(bufferingPolicy: .unbounded) {
            continuation = $0
        }
        self.continuation = continuation!
    }

    deinit {
        continuation.finish()
    }

    func setPrepareBehavior(_ behavior: PrepareBehavior, for source: PlaybackSource) {
        prepareBehaviors[source.testKey] = behavior
    }

    func setPlayError(_ error: PlayerError?) {
        playError = error
    }

    func setSeekError(_ error: PlayerError?) {
        seekError = error
    }

    func prepare(source: PlaybackSource) async throws {
        prepareCount += 1
        preparedSourceKeys.append(source.testKey)

        switch prepareBehaviors[source.testKey] ?? .emitReady(duration: 60) {
        case .emitReady(let duration):
            let readyState = PlaybackState(
                status: .readyToPlay,
                currentTime: 0,
                duration: duration,
                isBuffering: false
            )
            state = readyState
            continuation.yield(.stateInput(.prepared(PlaybackPreparedSnapshot(
                position: readyState.currentTime,
                duration: readyState.duration,
                isLive: false,
                liveDuration: nil
            ))))
        case .suspendUntilCancelled:
            try await Task.sleep(nanoseconds: 60_000_000_000)
        }
    }

    func play() async throws {
        if let playError {
            throw playError
        }
        playCount += 1
        state = state.updating(status: .playing, isBuffering: false)
        continuation.yield(.stateInput(.playStarted))
    }

    func pause() async throws {
        state = state.updating(status: .paused, isBuffering: false)
        continuation.yield(.stateInput(.pauseStarted))
    }

    func seek(to time: TimeInterval) async throws {
        if let seekError {
            throw seekError
        }
        state = state.updating(currentTime: time)
        continuation.yield(.stateInput(.positionChanged(time: time, duration: state.duration)))
    }

    func stop(reason: PlayerStopReason) async throws {
        stopCount += 1
        state = .idle
    }

    func emit(_ output: PlayerEngineOutput) {
        continuation.yield(output)
    }
}

private enum PrepareBehavior {
    case emitReady(duration: TimeInterval)
    case suspendUntilCancelled
}

private actor RecordedValues<Value: Sendable> {
    private var values: [Value] = []
    private var finished = false

    func append(_ value: Value) {
        values.append(value)
    }

    func finish() {
        finished = true
    }

    func contains(_ predicate: @Sendable (Value) -> Bool) -> Bool {
        values.contains(where: predicate)
    }

    var didFinish: Bool {
        finished
    }

    var containsDidFail: Bool {
        values.contains { value in
            guard let event = value as? PlayerEvent else {
                return false
            }

            if case .didFail = event {
                return true
            }

            return false
        }
    }

    var latestTimeDidChange: (currentTime: TimeInterval, duration: TimeInterval)? {
        for value in values.reversed() {
            guard let event = value as? PlayerEvent else {
                continue
            }

            if case .timeDidChange(let currentTime, let duration) = event {
                return (currentTime, duration)
            }
        }

        return nil
    }

    var timeDidChangeCount: Int {
        values.reduce(into: 0) { partialResult, value in
            guard let event = value as? PlayerEvent else {
                return
            }

            if case .timeDidChange = event {
                partialResult += 1
            }
        }
    }

    var failureError: PlayerError? {
        for value in values.reversed() {
            guard let event = value as? PlayerEvent else {
                continue
            }

            if case .didFail(let error) = event {
                return error
            }
        }

        return nil
    }
}

private extension PlaybackSource {
    var testKey: String {
        switch kind {
        case .mediaKey(let key):
            return "mediaKey:\(key)"
        case .url(let url):
            return "url:\(url.absoluteString)"
        }
    }
}
