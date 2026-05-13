import XCTest
@testable import VideoPlayerModule

final class SmartLearningPlayerInterfaceTests: XCTestCase {
    func testDefaultFeatureSetRepresentsSmartLearningPlayerControls() {
        let featureSet = SmartLearningPlayerFeatureSet.default

        XCTAssertTrue(featureSet.playback.allowsSeeking)
        XCTAssertEqual(featureSet.playback.allowedPlaybackRates, [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
        XCTAssertEqual(featureSet.playback.initialSkipInterval, 10)
        XCTAssertTrue(featureSet.subtitle.supportsAISubtitle)
        XCTAssertTrue(featureSet.subtitle.supportsSubtitleErrorReport)
        XCTAssertTrue(featureSet.panels.supportsBookmarkList)
        XCTAssertTrue(featureSet.panels.supportsLectureIndex)
        XCTAssertTrue(featureSet.panels.supportsMegaling)
        XCTAssertTrue(featureSet.panels.supportsAISummary)
        XCTAssertTrue(featureSet.panels.supportsLectureQnA)
        XCTAssertFalse(featureSet.offline.supportsDownloadPlayback)
        XCTAssertTrue(featureSet.gestures.supportsDoubleTapSeek)
        XCTAssertTrue(featureSet.gestures.supportsLock)
        XCTAssertTrue(featureSet.allowsScreenScaling)
    }

    func testFeatureSetCanRepresentDeferredSmartLearningPlayerDomains() {
        let featureSet = SmartLearningPlayerFeatureSet(
            panels: SmartLearningPanelFeatures(
                supportsBookmarkList: true,
                supportsLectureIndex: true,
                supportsLecturePlaylist: true,
                supportsMegaling: true,
                supportsAISummary: true,
                supportsLectureQnA: true
            ),
            offline: SmartLearningOfflineFeatures(
                supportsDownloadPlayback: true,
                supportsDownloadedFileValidation: true,
                supportsDownloadQueueNavigation: true
            ),
            allowsCastMode: true
        )

        XCTAssertTrue(featureSet.offline.supportsDownloadPlayback)
        XCTAssertTrue(featureSet.offline.supportsDownloadedFileValidation)
        XCTAssertTrue(featureSet.offline.supportsDownloadQueueNavigation)
        XCTAssertTrue(featureSet.allowsCastMode)
        XCTAssertEqual(SmartLearningPlayerPanel.lectureQnA, .lectureQnA)
    }

    func testPlaybackCommandCanCarrySmartLearningPlayerCommand() {
        let command = PlaybackCommand.smartLearning(.setPlaybackRate(1.5))

        XCTAssertEqual(command, .smartLearning(.setPlaybackRate(1.5)))
    }

    func testPlayerCoreForwardsSmartLearningCommandToSupportingEngine() async throws {
        let engine = SmartLearningCommandRecordingEngine()
        let core = PlayerCore(
            engine: engine,
            engineCapabilities: SmartLearningCommandRecordingEngine.capabilities
        )

        try await core.execute(command: .smartLearning(.setAISubtitleEnabled(true)))

        let receivedCommands = await engine.receivedCommands
        XCTAssertEqual(receivedCommands, [.setAISubtitleEnabled(true)])
    }

    func testPlayerCoreRejectsSmartLearningCommandWhenEngineDoesNotSupportIt() async {
        let engine = CoreOnlyEngine()
        let core = PlayerCore(
            engine: engine,
            engineCapabilities: CoreOnlyEngine.capabilities
        )

        do {
            try await core.execute(command: .smartLearning(.toggleScreenScaling))
            XCTFail("SmartLearning command should fail when the engine does not support it.")
        } catch let error as PlayerError {
            XCTAssertEqual(
                error,
                .engineError("SmartLearning command is not supported by the current playback engine.")
            )
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

private actor SmartLearningCommandRecordingEngine: PlayerEngineAdapter, SmartLearningPlayerCommandHandling {
    nonisolated static let capabilities: EngineCapabilities = [.continuesWithoutSurface]

    var currentState: PlaybackState { .idle }
    let eventStream = AsyncStream<PlayerEvent> { continuation in
        continuation.finish()
    }
    private(set) var receivedCommands: [SmartLearningPlayerCommand] = []

    func prepare(source: PlaybackSource) async throws {}
    func play() {}
    func pause() {}
    func seek(to time: TimeInterval) async {}
    func stop() {}
    func bind(renderSurface: PlayerRenderSurface) {}
    func unbindRenderSurface() {}

    func executeSmartLearningCommand(_ command: SmartLearningPlayerCommand) async throws {
        receivedCommands.append(command)
    }
}

private actor CoreOnlyEngine: PlayerEngineAdapter {
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
    func bind(renderSurface: PlayerRenderSurface) {}
    func unbindRenderSurface() {}
}
