#if canImport(UIKit)
import XCTest
import UIKit
@testable import VideoPlayerSkin

@MainActor
final class PlayerSkinSmokeTests: XCTestCase {
    func testDefaultPlayerSkinRenders() {
        let skin: PlayerSkin = DefaultPlayerSkin()
        XCTAssertNotNil(skin.view)
        skin.configure(title: "T", maxPlaybackRate: 4.0)
        skin.updateSkipIntervalLabel(seconds: 10)
        skin.setExtraControls([ExtraControl(id: "x", iconName: "PlayerBookmarkListNormal", title: "B", placement: .leftMenu)])
        for mode in [PlayerSkinLayoutMode.verticalSplit, .horizontalSplit, .fullScreen] {
            let s = PlayerSkinState(playbackState: .init(status: .playing, currentTime: 10, duration: 100, isBuffering: false), playbackRate: 1.0, controlsVisible: true, isFullScreenMode: mode == .fullScreen, isDisplayScaled: false, layoutMode: mode)
            skin.render(s)
            skin.view.layoutIfNeeded()
        }
    }
    func testActionWiring() {
        let skin = AssembledPlayerSkin(blueprint: .default)
        skin.onAction = { _ in }
        skin.render(.initial)
        XCTAssertNotNil(skin.onAction)
    }
}
#endif
