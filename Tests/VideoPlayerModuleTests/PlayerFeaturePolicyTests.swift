import Testing
@testable import VideoPlayerCore

@Suite("Player feature policy")
struct PlayerFeaturePolicyTests {
    @Test("Default policy disables background playback")
    func defaultPolicyDisablesBackgroundPlayback() {
        #expect(!PlayerFeaturePolicy.default.allowsBackgroundPlayback)
        #expect(PlayerFeaturePolicy.default.maxPlaybackRate == 2.0)
        #expect(PlayerFeaturePolicy.default.allowsAutoplay)
    }
}
