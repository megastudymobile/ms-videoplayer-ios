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
