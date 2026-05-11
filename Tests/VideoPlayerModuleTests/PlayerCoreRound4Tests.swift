import XCTest
@testable import VideoPlayerModule

final class PlayerCoreRound4Tests: XCTestCase {
    private var streamTasks: [Task<Void, Never>] = []

    override func tearDown() {
        streamTasks.forEach { $0.cancel() }
        streamTasks.removeAll()
        super.tearDown()
    }

    func testLoadReentryCancelsPreviousPrepareAndConvergesToLatestPlayback() async throws {
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

        XCTAssertEqual(prepareCount, 2)
        XCTAssertEqual(playCount, 1)
        XCTAssertEqual(stopCount, 0)
        XCTAssertEqual(preparedSourceKeys, [
            firstSource.testKey,
            secondSource.testKey
        ])
        XCTAssertFalse(containsDidFail)
    }

    func testStopDuringPreparingCancelsPrepareAndTransitionsToIdle() async throws {
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

        XCTAssertEqual(stopCount, 1)
        XCTAssertFalse(containsDidFail)
    }

    func testEventStreamKeepsLatestTimeEventForSlowConsumerAndFinishesOnDispose() async throws {
        let engine = TestPlayerEngineAdapter()
        let core = PlayerCore(
            engine: engine,
            engineCapabilities: TestPlayerEngineAdapter.capabilities
        )
        await core.activate()

        let eventRecorder = startRecording(
            core.eventStream,
            consumeDelay: 50_000_000
        )

        for second in 0..<20 {
            await engine.emit(.timeDidChange(currentTime: TimeInterval(second), duration: 300))
        }

        try await waitUntil {
            await eventRecorder.timeDidChangeCount >= 2
        }

        let latestTimeEvent = await eventRecorder.latestTimeDidChange
        switch latestTimeEvent {
        case .some((let currentTime, let duration)):
            XCTAssertEqual(currentTime, 19)
            XCTAssertEqual(duration, 300)
        case .none:
            XCTFail("최신 timeDidChange 이벤트가 전달되어야 합니다.")
        }

        let timeDidChangeCount = await eventRecorder.timeDidChangeCount
        XCTAssertLessThan(timeDidChangeCount, 20)

        await core.dispose()
        try await waitUntil {
            await eventRecorder.didFinish
        }
    }

    func testActivateRepublishesEngineEventsToStateAndEventStreams() async throws {
        let engine = TestPlayerEngineAdapter()
        let core = PlayerCore(
            engine: engine,
            engineCapabilities: TestPlayerEngineAdapter.capabilities
        )
        await core.activate()

        let stateRecorder = startRecording(core.stateStream)
        let eventRecorder = startRecording(core.eventStream)
        let publishedState = PlaybackState(
            status: .readyToPlay,
            currentTime: 3,
            duration: 90,
            isBuffering: false
        )

        await engine.emit(.stateDidChange(publishedState))
        try await waitUntil {
            await stateRecorder.contains { $0 == publishedState }
        }

        await engine.emit(.bufferingDidChange(isBuffering: true))
        try await waitUntil {
            await eventRecorder.contains { event in
                if case .bufferingDidChange(true) = event {
                    return true
                }

                return false
            }
        }

        await engine.emit(.didFail(.engineError("boom")))
        try await waitUntil {
            await eventRecorder.failureError == .engineError("boom")
        }
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
        timeout: TimeInterval = 1.0,
        pollInterval: UInt64 = 10_000_000,
        file: StaticString = #filePath,
        line: UInt = #line,
        condition: @escaping @Sendable () async -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if await condition() {
                return
            }

            try await Task.sleep(nanoseconds: pollInterval)
        }

        XCTFail("조건을 만족하지 못했습니다.", file: file, line: line)
    }

}

private actor TestPlayerEngineAdapter: PlayerEngineAdapter {
    nonisolated static let capabilities: EngineCapabilities = [.continuesWithoutSurface]

    var currentState: PlaybackState {
        state
    }

    let eventStream: AsyncStream<PlayerEvent>

    private let continuation: AsyncStream<PlayerEvent>.Continuation
    private var state: PlaybackState = .idle
    private var prepareBehaviors: [String: PrepareBehavior] = [:]
    private(set) var prepareCount = 0
    private(set) var playCount = 0
    private(set) var stopCount = 0
    private(set) var preparedSourceKeys: [String] = []

    init() {
        var continuation: AsyncStream<PlayerEvent>.Continuation?
        eventStream = AsyncStream(bufferingPolicy: .bufferingNewest(32)) {
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
            continuation.yield(.stateDidChange(readyState))
        case .suspendUntilCancelled:
            try await Task.sleep(nanoseconds: 60_000_000_000)
        }
    }

    func play() {
        playCount += 1
        state = state.updating(status: .playing, isBuffering: false)
        continuation.yield(.stateDidChange(state))
    }

    func pause() {
        state = state.updating(status: .paused, isBuffering: false)
        continuation.yield(.stateDidChange(state))
    }

    func seek(to time: TimeInterval) async {
        state = state.updating(currentTime: time)
        continuation.yield(.timeDidChange(currentTime: time, duration: state.duration))
    }

    func stop() {
        stopCount += 1
        state = .idle
    }

    func bind(renderSurface: PlayerRenderSurface) {}

    func unbindRenderSurface() {}

    func emit(_ event: PlayerEvent) {
        continuation.yield(event)
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
        switch self {
        case .kollus(let mediaContentKey):
            return "kollus:\(mediaContentKey)"
        case .url(let url):
            return "url:\(url.absoluteString)"
        }
    }
}
