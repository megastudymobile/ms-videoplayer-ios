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
        let skipIntervalCommand = PlaybackCommand.setSkipInterval(30)
        let subtitleVisibleCommand = PlaybackCommand.setSubtitleVisible(true)
        let subtitleTrackID = PlayerSubtitleTrackID(rawValue: "caption-ko")
        let subtitleTrackCommand = PlaybackCommand.selectSubtitleTrack(subtitleTrackID)
        let captionFontSizeCommand = PlaybackCommand.setCaptionFontSize(20)
        let addBookmarkCommand = PlaybackCommand.addBookmark(at: 45)
        let displayLockedCommand = PlaybackCommand.setDisplayLocked(true)
        let displayScaledCommand = PlaybackCommand.setDisplayScaled(true)
        let toggleDisplayScalingCommand = PlaybackCommand.toggleDisplayScaling
        let metadataID = PlayerTimedMetadataID(rawValue: "metadata-1")
        let seekCommand = PlaybackCommand.seekWithOrigin(
            to: 45,
            origin: .timedMetadata(metadataID)
        )

        XCTAssertEqual(rateCommand, .setPlaybackRate(1.5))
        XCTAssertEqual(skipIntervalCommand, .setSkipInterval(30))
        XCTAssertEqual(subtitleVisibleCommand, .setSubtitleVisible(true))
        XCTAssertEqual(subtitleTrackCommand, .selectSubtitleTrack(subtitleTrackID))
        XCTAssertEqual(captionFontSizeCommand, .setCaptionFontSize(20))
        XCTAssertEqual(addBookmarkCommand, .addBookmark(at: 45))
        XCTAssertEqual(displayLockedCommand, .setDisplayLocked(true))
        XCTAssertEqual(displayScaledCommand, .setDisplayScaled(true))
        XCTAssertEqual(toggleDisplayScalingCommand, .toggleDisplayScaling)
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

    func testPlayerCoreRejectsUnsupportedGenericSubtitleCommandExplicitly() async {
        let engine = CoreOnlyEngine()
        let core = PlayerCore(
            engine: engine,
            engineCapabilities: CoreOnlyEngine.capabilities
        )

        do {
            try await core.execute(command: .setSubtitleVisible(true))
            XCTFail("Unsupported subtitle visibility command should fail explicitly.")
        } catch let error as PlayerError {
            XCTAssertEqual(
                error,
                .engineError("Subtitle visibility is not supported by the current playback engine.")
            )
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testPlayerCoreRejectsInvalidCaptionFontSize() async {
        let engine = SubtitleControllableEngine()
        let core = PlayerCore(
            engine: engine,
            engineCapabilities: SubtitleControllableEngine.capabilities
        )

        do {
            try await core.execute(command: .setCaptionFontSize(0))
            XCTFail("Invalid caption font size should fail explicitly.")
        } catch let error as PlayerError {
            XCTAssertEqual(
                error,
                .engineError("Caption font size must be greater than 0. fontSize=0")
            )
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testPlayerCoreDelegatesGenericSubtitleCommandsWhenEngineSupportsSubtitleControl() async throws {
        let engine = SubtitleControllableEngine()
        let core = PlayerCore(
            engine: engine,
            engineCapabilities: SubtitleControllableEngine.capabilities
        )
        let trackID = PlayerSubtitleTrackID(rawValue: "caption-ko")

        try await core.execute(command: .setSubtitleVisible(true))
        try await core.execute(command: .selectSubtitleTrack(trackID))
        try await core.execute(command: .setCaptionFontSize(20))

        let recordedSubtitleVisibility = await engine.recordedSubtitleVisibility
        let recordedSubtitleTrackID = await engine.recordedSubtitleTrackID
        let recordedCaptionFontSize = await engine.recordedCaptionFontSize
        XCTAssertEqual(recordedSubtitleVisibility, true)
        XCTAssertEqual(recordedSubtitleTrackID, trackID)
        XCTAssertEqual(recordedCaptionFontSize, 20)
    }

    func testPlayerCoreRejectsUnsupportedGenericBookmarkCommandExplicitly() async {
        let engine = CoreOnlyEngine()
        let core = PlayerCore(
            engine: engine,
            engineCapabilities: CoreOnlyEngine.capabilities
        )

        do {
            try await core.execute(command: .addBookmark(at: 45))
            XCTFail("Unsupported bookmark command should fail explicitly.")
        } catch let error as PlayerError {
            XCTAssertEqual(
                error,
                .engineError("Bookmark mutation is not supported by the current playback engine.")
            )
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testPlayerCoreRejectsInvalidBookmarkTime() async {
        let engine = BookmarkControllableEngine()
        let core = PlayerCore(
            engine: engine,
            engineCapabilities: BookmarkControllableEngine.capabilities
        )

        do {
            try await core.execute(command: .addBookmark(at: -1))
            XCTFail("Invalid bookmark time should fail explicitly.")
        } catch let error as PlayerError {
            XCTAssertEqual(
                error,
                .engineError("Bookmark time must be greater than or equal to 0. time=-1.0")
            )
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testPlayerCoreDelegatesGenericBookmarkCommandWhenEngineSupportsBookmarkControl() async throws {
        let engine = BookmarkControllableEngine()
        let core = PlayerCore(
            engine: engine,
            engineCapabilities: BookmarkControllableEngine.capabilities
        )

        try await core.execute(command: .addBookmark(at: 45))

        let recordedBookmarkTime = await engine.recordedBookmarkTime
        XCTAssertEqual(recordedBookmarkTime, 45)
    }

    func testPlayerCoreRejectsUnsupportedGenericDisplayCommandExplicitly() async {
        let engine = CoreOnlyEngine()
        let core = PlayerCore(
            engine: engine,
            engineCapabilities: CoreOnlyEngine.capabilities
        )

        do {
            try await core.execute(command: .setDisplayLocked(true))
            XCTFail("Unsupported display command should fail explicitly.")
        } catch let error as PlayerError {
            XCTAssertEqual(
                error,
                .engineError("Display lock is not supported by the current playback engine.")
            )
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testPlayerCoreDelegatesGenericDisplayCommandsWhenEngineSupportsDisplayControl() async throws {
        let engine = DisplayControllableEngine()
        let core = PlayerCore(
            engine: engine,
            engineCapabilities: DisplayControllableEngine.capabilities
        )

        try await core.execute(command: .setDisplayLocked(true))
        try await core.execute(command: .setDisplayScaled(true))
        try await core.execute(command: .toggleDisplayScaling)

        let recordedDisplayLock = await engine.recordedDisplayLock
        let recordedDisplayScale = await engine.recordedDisplayScale
        let toggleDisplayScalingCallCount = await engine.toggleDisplayScalingCallCount
        XCTAssertEqual(recordedDisplayLock, true)
        XCTAssertEqual(recordedDisplayScale, true)
        XCTAssertEqual(toggleDisplayScalingCallCount, 1)
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

    func testPlayerCoreUsesUpdatedSkipIntervalForSkipOrigin() async throws {
        let engine = SeekRecordingEngine()
        let core = PlayerCore(
            engine: engine,
            engineCapabilities: SeekRecordingEngine.capabilities
        )
        try await core.execute(command: .seek(to: 40))
        try await core.execute(command: .setSkipInterval(30))
        await engine.resetRecordedSeekTimes()

        try await core.execute(command: .seekWithOrigin(to: 0, origin: .skipForward))

        let recordedSeekTimes = await engine.recordedSeekTimes
        XCTAssertEqual(recordedSeekTimes, [70])
    }

    func testPlayerCoreRejectsInvalidSkipInterval() async throws {
        let engine = SeekRecordingEngine()
        let core = PlayerCore(
            engine: engine,
            engineCapabilities: SeekRecordingEngine.capabilities
        )

        do {
            try await core.execute(command: .setSkipInterval(0))
            XCTFail("Invalid skip interval should fail explicitly.")
        } catch let error as PlayerError {
            XCTAssertEqual(
                error,
                .engineError("Skip interval must be greater than 0. interval=0.0")
            )
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
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
    func play() async throws {}
    func pause() async throws {}
    func seek(to time: TimeInterval) async throws {}
    func stop(reason: PlayerStopReason) async throws {}
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

    func play() async throws {}
    func pause() async throws {}
    func seek(to time: TimeInterval) async throws {}
    func stop(reason: PlayerStopReason) async throws {}

    func setPlaybackRate(_ rate: Double) async throws {
        recordedRate = rate
    }
}

private actor SubtitleControllableEngine: PlayerPlaybackEngine, PlayerSubtitleEngine {
    nonisolated static let capabilities: EngineCapabilities = []

    var currentState: PlaybackState { .idle }

    let eventStream = AsyncStream<PlayerEvent> { continuation in
        continuation.finish()
    }

    private(set) var recordedSubtitleVisibility: Bool?
    private(set) var recordedSubtitleTrackID: PlayerSubtitleTrackID?
    private(set) var recordedCaptionFontSize: Int?

    func prepare(source: PlaybackSource) async throws {}
    func play() async throws {}
    func pause() async throws {}
    func seek(to time: TimeInterval) async throws {}
    func stop(reason: PlayerStopReason) async throws {}

    func setSubtitleVisible(_ isVisible: Bool) async throws {
        recordedSubtitleVisibility = isVisible
    }

    func selectSubtitleTrack(_ trackID: PlayerSubtitleTrackID?) async throws {
        recordedSubtitleTrackID = trackID
    }

    func setCaptionFontSize(_ fontSize: Int) async throws {
        recordedCaptionFontSize = fontSize
    }
}

private actor DisplayControllableEngine: PlayerPlaybackEngine, PlayerDisplayEngine {
    nonisolated static let capabilities: EngineCapabilities = []

    var currentState: PlaybackState { .idle }

    let eventStream = AsyncStream<PlayerEvent> { continuation in
        continuation.finish()
    }

    private(set) var recordedDisplayLock: Bool?
    private(set) var recordedDisplayScale: Bool?
    private(set) var toggleDisplayScalingCallCount = 0

    func prepare(source: PlaybackSource) async throws {}
    func play() async throws {}
    func pause() async throws {}
    func seek(to time: TimeInterval) async throws {}
    func stop(reason: PlayerStopReason) async throws {}

    func setDisplayLocked(_ isLocked: Bool) async throws {
        recordedDisplayLock = isLocked
    }

    func setDisplayScaled(_ isScaled: Bool) async throws {
        recordedDisplayScale = isScaled
    }

    func toggleDisplayScaling() async throws {
        toggleDisplayScalingCallCount += 1
    }
}

private actor BookmarkControllableEngine: PlayerPlaybackEngine, PlayerBookmarkEngine {
    nonisolated static let capabilities: EngineCapabilities = []

    var currentState: PlaybackState { .idle }

    let eventStream = AsyncStream<PlayerEvent> { continuation in
        continuation.finish()
    }

    private(set) var recordedBookmarkTime: TimeInterval?

    func prepare(source: PlaybackSource) async throws {}
    func play() async throws {}
    func pause() async throws {}
    func seek(to time: TimeInterval) async throws {}
    func stop(reason: PlayerStopReason) async throws {}

    func addBookmark(at time: TimeInterval) async throws {
        recordedBookmarkTime = time
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
    func play() async throws {}
    func pause() async throws {}

    func seek(to time: TimeInterval) async throws {
        recordedSeekTimes.append(time)
        state = state.updating(currentTime: time)
    }

    func stop(reason: PlayerStopReason) async throws {}
}
