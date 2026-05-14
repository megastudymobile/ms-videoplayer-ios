import XCTest
@testable import VideoPlayerCore

final class PlayerInterfaceTests: XCTestCase {
    func testDefaultFeatureSetRepresentsGenericPlayerControls() {
        let featureSet = PlayerFeatureSet.default

        XCTAssertTrue(featureSet.playback.allowsSeeking)
        XCTAssertEqual(featureSet.playback.allowedPlaybackRates, [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
        XCTAssertEqual(featureSet.playback.initialSkipInterval, 10)
        XCTAssertTrue(featureSet.subtitle.supportsSubtitles)
        XCTAssertTrue(featureSet.subtitle.supportsTrackSelection)
        XCTAssertTrue(featureSet.bookmark.supportsBookmarks)
        XCTAssertTrue(featureSet.playlist.supportsItemSelection)
        XCTAssertTrue(featureSet.display.supportsLock)
        XCTAssertTrue(featureSet.display.supportsScaling)
        XCTAssertFalse(featureSet.offline.supportsOfflinePlayback)
    }

    func testFeatureSetCanRepresentGenericOptionalCapabilities() {
        let featureSet = PlayerFeatureSet(
            subtitle: PlayerSubtitleFeatures(
                availableTracks: [
                    PlayerSubtitleTrack(
                        id: PlayerSubtitleTrackID(rawValue: "caption-ko"),
                        title: "Korean",
                        localeIdentifier: "ko-KR"
                    )
                ]
            ),
            playlist: PlayerPlaylistFeatures(
                supportsItemSelection: true,
                supportsNextItem: true,
                supportsAutoplayNextItem: true
            ),
            display: PlayerDisplayFeatures(
                supportsLock: true,
                supportsScaling: true,
                supportsExternalPlayback: true
            ),
            offline: PlayerOfflineFeatures(
                supportsOfflinePlayback: true,
                supportsOfflineSourceValidation: true
            )
        )

        XCTAssertEqual(featureSet.subtitle.availableTracks.first?.id.rawValue, "caption-ko")
        XCTAssertTrue(featureSet.playlist.supportsAutoplayNextItem)
        XCTAssertTrue(featureSet.display.supportsExternalPlayback)
        XCTAssertTrue(featureSet.offline.supportsOfflineSourceValidation)
    }

    func testPlaybackCommandCarriesGenericRateAndSeekOrigin() {
        let rateCommand = PlaybackCommand.setPlaybackRate(1.5)
        let metadataID = PlayerTimedMetadataID(rawValue: "metadata-1")
        let seekCommand = PlaybackCommand.seekWithOrigin(
            to: 45,
            origin: .timedMetadata(metadataID)
        )

        XCTAssertEqual(rateCommand, .setPlaybackRate(1.5))
        XCTAssertEqual(
            seekCommand,
            .seekWithOrigin(to: 45, origin: .timedMetadata(metadataID))
        )
    }

    func testPlayerCoreRejectsUnsupportedGenericRateCommandExplicitly() async {
        let engine = CoreOnlyEngine()
        let core = PlayerCore(
            engine: engine,
            engineCapabilities: CoreOnlyEngine.capabilities
        )

        do {
            try await core.execute(command: .setPlaybackRate(1.5))
            XCTFail("Unsupported rate command should fail explicitly.")
        } catch let error as PlayerError {
            XCTAssertEqual(
                error,
                .engineError("Playback rate 1.5x is not supported by the current playback engine.")
            )
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testPlayerCoreDelegatesGenericRateCommandWhenEngineSupportsRateControl() async throws {
        let engine = RateControllableEngine()
        let core = PlayerCore(
            engine: engine,
            engineCapabilities: RateControllableEngine.capabilities
        )

        try await core.execute(command: .setPlaybackRate(1.5))

        let recordedRate = await engine.recordedRate
        XCTAssertEqual(recordedRate, 1.5)
    }

    func testPlayerCoreRejectsRateAboveCurrentPolicy() async throws {
        let engine = RateControllableEngine()
        let core = PlayerCore(
            engine: engine,
            engineCapabilities: RateControllableEngine.capabilities
        )

        try await core.start(
            source: .url(URL(string: "https://example.com/video.mp4")!),
            policy: PlayerFeaturePolicy(
                allowsBackgroundPlayback: false,
                maxPlaybackRate: 1.25,
                allowsAutoplay: false
            )
        )

        do {
            try await core.execute(command: .setPlaybackRate(1.5))
            XCTFail("Rate above policy should fail explicitly.")
        } catch let error as PlayerError {
            XCTAssertEqual(
                error,
                .engineError("Playback rate 1.5x exceeds max policy rate 1.25x.")
            )
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testPlayerCoreResolvesSkipOriginFromCurrentPlaybackTime() async throws {
        let engine = SeekRecordingEngine()
        let core = PlayerCore(
            engine: engine,
            engineCapabilities: SeekRecordingEngine.capabilities
        )
        try await core.execute(command: .seek(to: 40))
        await engine.resetRecordedSeekTimes()

        try await core.execute(command: .seekWithOrigin(to: 0, origin: .skipForward))
        try await core.execute(command: .seekWithOrigin(to: 0, origin: .skipBackward))

        let recordedSeekTimes = await engine.recordedSeekTimes
        XCTAssertEqual(recordedSeekTimes, [50, 40])
    }

    func testPlayerCoreClampsSkipOriginToPlaybackBounds() async throws {
        let engine = SeekRecordingEngine()
        let core = PlayerCore(
            engine: engine,
            engineCapabilities: SeekRecordingEngine.capabilities,
            initialPolicy: PlayerFeaturePolicy(
                allowsBackgroundPlayback: false,
                maxPlaybackRate: 2,
                allowsAutoplay: true,
                skipInterval: 30
            )
        )
        try await core.execute(command: .seek(to: 5))
        await engine.resetRecordedSeekTimes()

        try await core.execute(command: .seekWithOrigin(to: 0, origin: .skipBackward))

        let recordedSeekTimes = await engine.recordedSeekTimes
        XCTAssertEqual(recordedSeekTimes, [0])
    }
}

private actor CoreOnlyEngine: PlayerPlaybackEngine {
    nonisolated static let capabilities: EngineCapabilities = []

    var currentState: PlaybackState { .idle }
    let eventStream = AsyncStream<PlayerEvent> { continuation in
        continuation.finish()
    }

    func prepare(source: PlaybackSource) async throws {}
    func play() {}
    func pause() {}
    func seek(to time: TimeInterval) async {}
    func stop() {}
}

private actor RateControllableEngine: PlayerPlaybackEngine, PlayerPlaybackRateEngine {
    nonisolated static let capabilities: EngineCapabilities = []

    var currentState: PlaybackState {
        state
    }

    let eventStream = AsyncStream<PlayerEvent> { continuation in
        continuation.finish()
    }

    private var state: PlaybackState = .idle
    private(set) var recordedRate: Double?

    func prepare(source: PlaybackSource) async throws {
        state = PlaybackState(
            status: .readyToPlay,
            currentTime: 0,
            duration: 60,
            isBuffering: false
        )
    }

    func play() {}
    func pause() {}
    func seek(to time: TimeInterval) async {}
    func stop() {}

    func setPlaybackRate(_ rate: Double) async throws {
        recordedRate = rate
    }
}

private actor SeekRecordingEngine: PlayerPlaybackEngine {
    nonisolated static let capabilities: EngineCapabilities = []

    var currentState: PlaybackState {
        state
    }

    let eventStream: AsyncStream<PlayerEvent>

    private let eventContinuation: AsyncStream<PlayerEvent>.Continuation
    private var state: PlaybackState = .idle
    private(set) var recordedSeekTimes: [TimeInterval] = []

    init() {
        var continuation: AsyncStream<PlayerEvent>.Continuation?
        eventStream = AsyncStream<PlayerEvent>(bufferingPolicy: .bufferingNewest(8)) {
            continuation = $0
        }
        self.eventContinuation = continuation!
    }

    deinit {
        eventContinuation.finish()
    }

    func setState(_ state: PlaybackState) {
        self.state = state
    }

    func resetRecordedSeekTimes() {
        recordedSeekTimes = []
    }

    func prepare(source: PlaybackSource) async throws {}
    func play() {}
    func pause() {}

    func seek(to time: TimeInterval) async {
        recordedSeekTimes.append(time)
        state = state.updating(currentTime: time)
    }

    func stop() {}
}
