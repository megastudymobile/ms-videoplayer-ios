import Testing
@testable import VideoPlayerCore

@Suite("Player capability surface 검증")
struct PlayerCapabilitySurfaceTests {
    @Test("Playback features가 배속과 skip interval을 정규화")
    func playbackFeaturesNormalizeRatesAndSkipIntervals() {
        let features = PlayerPlaybackFeatures(
            allowedPlaybackRates: [1.5, 1.0, 1.5],
            initialPlaybackRate: 2.0,
            skipIntervals: [30, 10, 30],
            initialSkipInterval: 5
        )

        #expect(features.allowedPlaybackRates == [1.0, 1.5])
        #expect(features.initialPlaybackRate == 1.0)
        #expect(features.skipIntervals == [10, 30])
        #expect(features.initialSkipInterval == 10)
    }

    @Test("범용 surface 이름이 기대하는 player 개념을 포괄")
    func genericSurfaceNamesCoverExpectedPlayerConcepts() {
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

        #expect(featureSet.playback.allowsBackgroundPlayback)
        #expect(featureSet.subtitle.availableTracks[0].id.rawValue == "track-ko")
        #expect(featureSet.offline.supportsOfflinePlayback)
        #expect(snapshot.selectedPlaybackRate == 1.25)
        #expect(snapshot.subtitleState.captionFontSize == 18)
        #expect(snapshot.unavailableCapabilities == [
            .timedMetadata(PlayerTimedMetadataID(rawValue: "chapter-3"))
        ])
    }
}
