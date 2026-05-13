import XCTest
@testable import VideoPlayerCore

final class PlayerCapabilitySurfaceTests: XCTestCase {
    func testPlaybackFeaturesNormalizeRatesAndSkipIntervals() {
        let features = PlayerPlaybackFeatures(
            allowedPlaybackRates: [1.5, 1.0, 1.5],
            initialPlaybackRate: 2.0,
            skipIntervals: [30, 10, 30],
            initialSkipInterval: 5
        )

        XCTAssertEqual(features.allowedPlaybackRates, [1.0, 1.5])
        XCTAssertEqual(features.initialPlaybackRate, 1.0)
        XCTAssertEqual(features.skipIntervals, [10, 30])
        XCTAssertEqual(features.initialSkipInterval, 10)
    }

    func testGenericSurfaceNamesCoverExpectedPlayerConcepts() {
        let featureSet = PlayerFeatureSet(
            playback: PlayerPlaybackFeatures(allowsBackgroundPlayback: true),
            subtitle: PlayerSubtitleFeatures(
                availableTracks: [
                    PlayerSubtitleTrack(
                        id: PlayerSubtitleTrackID(rawValue: "track-ko"),
                        title: "Korean"
                    )
                ]
            ),
            offline: PlayerOfflineFeatures(
                supportsOfflinePlayback: true,
                supportsOfflineSourceValidation: true
            )
        )
        let snapshot = PlayerStateSnapshot(
            selectedPlaybackRate: 1.25,
            subtitleState: PlayerSubtitleState(
                isVisible: true,
                selectedTrack: featureSet.subtitle.availableTracks[0],
                captionFontSize: 18
            ),
            unavailableCapabilities: [
                .timedMetadata(PlayerTimedMetadataID(rawValue: "chapter-3"))
            ]
        )

        XCTAssertTrue(featureSet.playback.allowsBackgroundPlayback)
        XCTAssertEqual(featureSet.subtitle.availableTracks[0].id.rawValue, "track-ko")
        XCTAssertTrue(featureSet.offline.supportsOfflinePlayback)
        XCTAssertEqual(snapshot.selectedPlaybackRate, 1.25)
        XCTAssertEqual(snapshot.subtitleState.captionFontSize, 18)
        XCTAssertEqual(
            snapshot.unavailableCapabilities,
            [.timedMetadata(PlayerTimedMetadataID(rawValue: "chapter-3"))]
        )
    }
}
