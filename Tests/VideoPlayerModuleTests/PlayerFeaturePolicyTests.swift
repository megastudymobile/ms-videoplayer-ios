import XCTest
@testable import VideoPlayerModule

final class PlayerFeaturePolicyTests: XCTestCase {
    func testDefaultPolicyDisablesBackgroundPlayback() {
        XCTAssertFalse(PlayerFeaturePolicy.default.allowsBackgroundPlayback)
        XCTAssertEqual(PlayerFeaturePolicy.default.maxPlaybackRate, 2.0)
        XCTAssertTrue(PlayerFeaturePolicy.default.allowsAutoplay)
    }
}
