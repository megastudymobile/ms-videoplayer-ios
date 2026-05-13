import XCTest
@testable import VideoPlayerCore

final class PlayerFeaturePolicyTests: XCTestCase {
    func testDefaultPolicyDisablesBackgroundPlayback() {
        XCTAssertFalse(PlayerFeaturePolicy.default.allowsBackgroundPlayback)
        XCTAssertEqual(PlayerFeaturePolicy.default.maxPlaybackRate, 2.0)
        XCTAssertTrue(PlayerFeaturePolicy.default.allowsAutoplay)
    }
}
