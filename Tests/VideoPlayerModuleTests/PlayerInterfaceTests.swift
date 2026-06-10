import Foundation
import Testing
@testable import VideoPlayerCore

@Suite("Player 인터페이스 FeatureSet/Command/Core 위임 검증")
struct PlayerInterfaceTests {
    @Test("기본 FeatureSet은 일반 플레이어 컨트롤을 나타낸다")
    func defaultFeatureSetRepresentsGenericPlayerControls() {
        let featureSet = PlayerFeatureSet.default

        #expect(featureSet.playback.allowsSeeking)
        #expect(featureSet.playback.allowedPlaybackRates == [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
        #expect(featureSet.playback.initialSkipInterval == 10)
        #expect(featureSet.subtitle.supportsSubtitles)
        #expect(featureSet.subtitle.supportsTrackSelection)
        #expect(featureSet.subtitle.captionFontSizes == [10, 15, 20, 25, 30, 35, 40])
        #expect(featureSet.subtitle.initialCaptionFontSize == 20)
        #expect(featureSet.bookmark.supportsBookmarks)
        #expect(featureSet.playlist.supportsItemSelection)
        #expect(featureSet.display.supportsLock)
        #expect(featureSet.display.supportsScaling)
        #expect(!(featureSet.offline.supportsOfflinePlayback))
    }

    @Test("FeatureSet은 일반 선택적 capability를 표현할 수 있다")
    func featureSetCanRepresentGenericOptionalCapabilities() {
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

        #expect(featureSet.subtitle.availableTracks.first?.id.rawValue == "caption-ko")
        #expect(featureSet.playlist.supportsAutoplayNextItem)
        #expect(featureSet.display.supportsExternalPlayback)
        #expect(featureSet.offline.supportsOfflineSourceValidation)
    }

    @Test("빈 자막 크기 목록은 20pt 기본값으로 복구한다")
    func emptyCaptionFontSizesFallBackToDefaultSize() {
        let subtitleFeatures = PlayerSubtitleFeatures(captionFontSizes: [])

        #expect(subtitleFeatures.captionFontSizes == [20])
        #expect(subtitleFeatures.initialCaptionFontSize == 20)
    }

    @Test("PlaybackCommand는 일반 rate와 seek origin을 담는다")
    func playbackCommandCarriesGenericRateAndSeekOrigin() {
        let rateCommand = PlaybackCommand.setPlaybackRate(1.5)
        let skipIntervalCommand = PlaybackCommand.setSkipInterval(30)
        let subtitleVisibleCommand = PlaybackCommand.setSubtitleVisible(true)
        let subtitleTrackID = PlayerSubtitleTrackID(rawValue: "caption-ko")
        let subtitleTrackCommand = PlaybackCommand.selectSubtitleTrack(subtitleTrackID)
        let captionFontSizeCommand = PlaybackCommand.setCaptionFontSize(20)
        let addBookmarkCommand = PlaybackCommand.addBookmark(at: 45)
        let displayLockedCommand = PlaybackCommand.setDisplayLocked(true)
        let displayScaleModeCommand = PlaybackCommand.setDisplayScaleMode(.fill)
        let displayScaledCommand = PlaybackCommand.setDisplayScaled(true)
        let toggleDisplayScaleModeCommand = PlaybackCommand.toggleDisplayScaleMode
        let toggleDisplayScalingCommand = PlaybackCommand.toggleDisplayScaling
        let metadataID = PlayerTimedMetadataID(rawValue: "metadata-1")
        let seekCommand = PlaybackCommand.seekWithOrigin(
            to: 45,
            origin: .timedMetadata(metadataID)
        )

        #expect(rateCommand == .setPlaybackRate(1.5))
        #expect(skipIntervalCommand == .setSkipInterval(30))
        #expect(subtitleVisibleCommand == .setSubtitleVisible(true))
        #expect(subtitleTrackCommand == .selectSubtitleTrack(subtitleTrackID))
        #expect(captionFontSizeCommand == .setCaptionFontSize(20))
        #expect(addBookmarkCommand == .addBookmark(at: 45))
        #expect(displayLockedCommand == .setDisplayLocked(true))
        #expect(displayScaleModeCommand == .setDisplayScaleMode(.fill))
        #expect(displayScaledCommand == .setDisplayScaled(true))
        #expect(toggleDisplayScaleModeCommand == .toggleDisplayScaleMode)
        #expect(toggleDisplayScalingCommand == .toggleDisplayScaling)
        #expect(
            seekCommand == .seekWithOrigin(to: 45, origin: .timedMetadata(metadataID))
        )
    }

    @Test("엔진이 rate를 미지원하면 PlayerCore가 명시적으로 거부한다")
    func playerCoreRejectsUnsupportedGenericRateCommandExplicitly() async {
        let engine = CoreOnlyEngine()
        let core = PlayerCore(
            engine: engine,
            engineCapabilities: CoreOnlyEngine.capabilities
        )

        do {
            try await core.execute(command: .setPlaybackRate(1.5))
            Issue.record("Unsupported rate command should fail explicitly.")
        } catch let error as PlayerError {
            #expect(
                error == .engineError("Playback rate 1.5x is not supported by the current playback engine.")
            )
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("엔진이 rate 제어를 지원하면 PlayerCore가 rate 명령을 위임한다")
    func playerCoreDelegatesGenericRateCommandWhenEngineSupportsRateControl() async throws {
        let engine = RateControllableEngine()
        let core = PlayerCore(
            engine: engine,
            engineCapabilities: RateControllableEngine.capabilities
        )

        try await core.execute(command: .setPlaybackRate(1.5))

        let recordedRate = await engine.recordedRate
        #expect(recordedRate == 1.5)
    }

    @Test("현재 정책 최대치를 초과하는 rate를 거부한다")
    func playerCoreRejectsRateAboveCurrentPolicy() async throws {
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
            Issue.record("Rate above policy should fail explicitly.")
        } catch let error as PlayerError {
            #expect(
                error == .engineError("Playback rate 1.5x exceeds max policy rate 1.25x.")
            )
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("엔진이 subtitle을 미지원하면 자막 가시성 명령을 명시적으로 거부한다")
    func playerCoreRejectsUnsupportedGenericSubtitleCommandExplicitly() async {
        let engine = CoreOnlyEngine()
        let core = PlayerCore(
            engine: engine,
            engineCapabilities: CoreOnlyEngine.capabilities
        )

        do {
            try await core.execute(command: .setSubtitleVisible(true))
            Issue.record("Unsupported subtitle visibility command should fail explicitly.")
        } catch let error as PlayerError {
            #expect(
                error == .engineError("Subtitle visibility is not supported by the current playback engine.")
            )
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("잘못된 캡션 폰트 크기를 거부한다")
    func playerCoreRejectsInvalidCaptionFontSize() async {
        let engine = SubtitleControllableEngine()
        let core = PlayerCore(
            engine: engine,
            engineCapabilities: SubtitleControllableEngine.capabilities
        )

        do {
            try await core.execute(command: .setCaptionFontSize(0))
            Issue.record("Invalid caption font size should fail explicitly.")
        } catch let error as PlayerError {
            #expect(
                error == .engineError("Caption font size must be greater than 0. fontSize=0")
            )
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("엔진이 subtitle 제어를 지원하면 자막 명령을 위임한다")
    func playerCoreDelegatesGenericSubtitleCommandsWhenEngineSupportsSubtitleControl() async throws {
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
        #expect(recordedSubtitleVisibility == true)
        #expect(recordedSubtitleTrackID == trackID)
        #expect(recordedCaptionFontSize == 20)
    }

    @Test("엔진이 bookmark를 미지원하면 북마크 명령을 명시적으로 거부한다")
    func playerCoreRejectsUnsupportedGenericBookmarkCommandExplicitly() async {
        let engine = CoreOnlyEngine()
        let core = PlayerCore(
            engine: engine,
            engineCapabilities: CoreOnlyEngine.capabilities
        )

        do {
            try await core.execute(command: .addBookmark(at: 45))
            Issue.record("Unsupported bookmark command should fail explicitly.")
        } catch let error as PlayerError {
            #expect(
                error == .engineError("Bookmark mutation is not supported by the current playback engine.")
            )
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("잘못된 북마크 시간을 거부한다")
    func playerCoreRejectsInvalidBookmarkTime() async {
        let engine = BookmarkControllableEngine()
        let core = PlayerCore(
            engine: engine,
            engineCapabilities: BookmarkControllableEngine.capabilities
        )

        do {
            try await core.execute(command: .addBookmark(at: -1))
            Issue.record("Invalid bookmark time should fail explicitly.")
        } catch let error as PlayerError {
            #expect(
                error == .engineError("Bookmark time must be greater than or equal to 0. time=-1.0")
            )
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("엔진이 bookmark 제어를 지원하면 북마크 명령을 위임한다")
    func playerCoreDelegatesGenericBookmarkCommandWhenEngineSupportsBookmarkControl() async throws {
        let engine = BookmarkControllableEngine()
        let core = PlayerCore(
            engine: engine,
            engineCapabilities: BookmarkControllableEngine.capabilities
        )

        try await core.execute(command: .addBookmark(at: 45))

        let recordedBookmarkTime = await engine.recordedBookmarkTime
        #expect(recordedBookmarkTime == 45)
    }

    @Test("엔진이 display를 미지원하면 디스플레이 명령을 명시적으로 거부한다")
    func playerCoreRejectsUnsupportedGenericDisplayCommandExplicitly() async {
        let engine = CoreOnlyEngine()
        let core = PlayerCore(
            engine: engine,
            engineCapabilities: CoreOnlyEngine.capabilities
        )

        do {
            try await core.execute(command: .setDisplayLocked(true))
            Issue.record("Unsupported display command should fail explicitly.")
        } catch let error as PlayerError {
            #expect(
                error == .engineError("Display lock is not supported by the current playback engine.")
            )
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("엔진이 display 제어를 지원하면 디스플레이 명령을 위임한다")
    func playerCoreDelegatesGenericDisplayCommandsWhenEngineSupportsDisplayControl() async throws {
        let engine = DisplayControllableEngine()
        let core = PlayerCore(
            engine: engine,
            engineCapabilities: DisplayControllableEngine.capabilities
        )

        try await core.execute(command: .setDisplayLocked(true))
        try await core.execute(command: .setDisplayScaleMode(.fill))
        try await core.execute(command: .setDisplayScaled(true))
        try await core.execute(command: .toggleDisplayScaleMode)
        try await core.execute(command: .toggleDisplayScaling)

        let recordedDisplayLock = await engine.recordedDisplayLock
        let recordedDisplayScaleMode = await engine.recordedDisplayScaleMode
        let toggleDisplayScaleModeCallCount = await engine.toggleDisplayScaleModeCallCount
        #expect(recordedDisplayLock == true)
        #expect(recordedDisplayScaleMode == .aspectFill)
        #expect(toggleDisplayScaleModeCallCount == 2)
    }

    @Test("skip origin을 현재 재생 시간으로부터 해석한다")
    func playerCoreResolvesSkipOriginFromCurrentPlaybackTime() async throws {
        let engine = SeekRecordingEngine()
        let core = PlayerCore(
            engine: engine,
            engineCapabilities: SeekRecordingEngine.capabilities
        )
        await core.activate()
        try await core.execute(command: .seek(to: 40))
        await engine.resetRecordedSeekTimes()

        try await core.execute(command: .seekWithOrigin(to: 0, origin: .skipForward))
        try await core.execute(command: .seekWithOrigin(to: 0, origin: .skipBackward))

        // chase는 비차단 — in-flight 완료(위치 통지) 후 다음 seek이 디스패치되므로 정착을 기다린다.
        let recordedSeekTimes = try await waitForSeekTimes(engine, expectedCount: 2)
        #expect(recordedSeekTimes == [50, 40])
    }

    @Test("skip origin에 갱신된 skip interval을 사용한다")
    func playerCoreUsesUpdatedSkipIntervalForSkipOrigin() async throws {
        let engine = SeekRecordingEngine()
        let core = PlayerCore(
            engine: engine,
            engineCapabilities: SeekRecordingEngine.capabilities
        )
        await core.activate()
        try await core.execute(command: .seek(to: 40))
        try await core.execute(command: .setSkipInterval(30))
        await engine.resetRecordedSeekTimes()

        try await core.execute(command: .seekWithOrigin(to: 0, origin: .skipForward))

        let recordedSeekTimes = try await waitForSeekTimes(engine, expectedCount: 1)
        #expect(recordedSeekTimes == [70])
    }

    @Test("잘못된 skip interval을 거부한다")
    func playerCoreRejectsInvalidSkipInterval() async throws {
        let engine = SeekRecordingEngine()
        let core = PlayerCore(
            engine: engine,
            engineCapabilities: SeekRecordingEngine.capabilities
        )

        do {
            try await core.execute(command: .setSkipInterval(0))
            Issue.record("Invalid skip interval should fail explicitly.")
        } catch let error as PlayerError {
            #expect(
                error == .engineError("Skip interval must be greater than 0. interval=0.0")
            )
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("skip origin을 재생 경계로 clamp한다")
    func playerCoreClampsSkipOriginToPlaybackBounds() async throws {
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
        await core.activate()
        try await core.execute(command: .seek(to: 5))
        await engine.resetRecordedSeekTimes()

        try await core.execute(command: .seekWithOrigin(to: 0, origin: .skipBackward))

        let recordedSeekTimes = try await waitForSeekTimes(engine, expectedCount: 1)
        #expect(recordedSeekTimes == [0])
    }

    /// chase 패턴은 비차단 — seek 디스패치가 in-flight 완료(위치 통지) 후 진행되므로,
    /// 기대 개수에 도달할 때까지 cooperative하게 기다린다(테스트용, 짧은 타임아웃).
    private func waitForSeekTimes(
        _ engine: SeekRecordingEngine,
        expectedCount: Int
    ) async throws -> [TimeInterval] {
        for _ in 0..<200 {
            let times = await engine.recordedSeekTimes
            if times.count >= expectedCount {
                return times
            }
            try await Task.sleep(nanoseconds: 5_000_000) // 5ms
        }
        return await engine.recordedSeekTimes
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
    private(set) var recordedDisplayScaleMode: PlayerDisplayScaleMode?
    private(set) var toggleDisplayScaleModeCallCount = 0

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

    func setDisplayScaleMode(_ mode: PlayerDisplayScaleMode) async throws {
        recordedDisplayScaleMode = mode
    }

    func toggleDisplayScaling() async throws {
        toggleDisplayScaleModeCallCount += 1
    }

    func toggleDisplayScaleMode() async throws {
        toggleDisplayScaleModeCallCount += 1
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
        // chase 패턴 완료 신호: 실 엔진처럼 seek 직후 도달 위치를 통지해
        // PlayerCore가 in-flight seek 완료를 감지하고 다음 chase를 디스패치하게 한다.
        eventContinuation.yield(.timeDidChange(currentTime: time, duration: state.duration))
    }

    func stop(reason: PlayerStopReason) async throws {}
}
