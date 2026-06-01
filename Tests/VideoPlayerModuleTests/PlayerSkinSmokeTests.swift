#if canImport(UIKit)
import Testing
import UIKit
@testable import VideoPlayerSkin

@MainActor
@Suite("PlayerSkin smoke 테스트")
struct PlayerSkinSmokeTests {
    private final class ThemeProbeBlock: UIView, PlayerSkinBlock {
        var view: UIView { self }
        var onAction: ((PlayerSkinAction) -> Void)?
        private(set) var renderColor: UIColor?

        func render(_ state: PlayerSkinState, theme: PlayerSkinTheme) {
            renderColor = theme.color(.controlTint)
        }
    }

    @Test("DefaultPlayerSkin이 모든 layout mode에서 렌더링")
    func defaultPlayerSkinRenders() {
        let skin: PlayerSkin = DefaultPlayerSkin()
        #expect(skin.view.subviews.isEmpty == false)

        skin.configure(title: "T", maxPlaybackRate: 4.0)
        skin.updateSkipIntervalLabel(seconds: 10)
        skin.setExtraControls([
            ExtraControl(id: "x", iconName: "PlayerBookmarkListNormal", title: "B", placement: .leftMenu)
        ])

        for mode in [PlayerSkinLayoutMode.verticalSplit, .horizontalSplit, .fullScreen] {
            let state = PlayerSkinState(
                playbackState: .init(status: .playing, currentTime: 10, duration: 100, isBuffering: false),
                playbackRate: 1.0,
                controlsVisible: true,
                isFullScreenMode: mode == .fullScreen,
                isDisplayScaled: false,
                layoutMode: mode
            )
            skin.render(state)
            skin.view.layoutIfNeeded()
        }
    }

    @Test("action handler를 연결 가능")
    func actionWiring() {
        let skin = AssembledPlayerSkin(blueprint: .default)
        skin.onAction = { _ in }
        skin.render(.initial)
        #expect(skin.onAction != nil)
    }

    @Test("PlayerSkinTheme이 override와 default fallback을 사용")
    func playerSkinThemeUsesOverridesAndDefaultFallbacks() {
        let theme = PlayerSkinTheme(
            colors: [.controlTint: .systemRed],
            fonts: [.rateLabel: .boldSystemFont(ofSize: 19)]
        )

        #expect(theme.color(.controlTint).isEqual(UIColor.systemRed))
        #expect(theme.color(.barBackground).isEqual(PlayerSkinTheme.default.color(.barBackground)))
        #expect(theme.font(.rateLabel).isEqual(UIFont.boldSystemFont(ofSize: 19)))
        #expect(theme.font(.time).isEqual(PlayerSkinTheme.default.font(.time)))
    }

    @Test("AssembledPlayerSkin이 render 시 theme을 전달")
    func assembledPlayerSkinPassesThemeDuringRender() {
        let block = ThemeProbeBlock()
        let theme = PlayerSkinTheme(colors: [.controlTint: .systemGreen])
        let blueprint = PlayerSkinBlueprint(
            blocks: [.centerControls: [{ block }]],
            visibleSlots: [
                .verticalSplit: [.centerControls],
                .horizontalSplit: [.centerControls],
                .fullScreen: [.centerControls]
            ]
        )

        let skin = AssembledPlayerSkin(blueprint: blueprint, theme: theme)
        skin.render(.initial)

        #expect(block.renderColor?.isEqual(UIColor.systemGreen) == true)
    }
}
#endif
