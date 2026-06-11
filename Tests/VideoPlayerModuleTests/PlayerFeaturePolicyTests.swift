import Testing
@testable import VideoPlayerCore

@Suite("Player feature policy 검증")
struct PlayerFeaturePolicyTests {
    @Test("default policy가 background playback을 비활성화")
    func defaultPolicyDisablesBackgroundPlayback() {
        #expect(!PlayerFeaturePolicy.default.allowsBackgroundPlayback)
        #expect(PlayerFeaturePolicy.default.allowedPlaybackRates == [0.5, 0.8, 1.0, 1.2, 1.5, 2.0])
        #expect(PlayerFeaturePolicy.default.allowsAutoplay)
    }
}
