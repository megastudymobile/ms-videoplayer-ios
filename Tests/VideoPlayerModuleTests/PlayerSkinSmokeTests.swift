#if canImport(UIKit)
import Testing
import UIKit
@testable import VideoPlayerSkin

@MainActor
@Suite("PlayerSkin smoke tests")
struct PlayerSkinSmokeTests {
    private final class ThemeProbeBlock: UIView, PlayerSkinBlock {
        var view: UIView { self }
        var onAction: ((PlayerSkinAction) -> Void)?
        private(set) var renderColor: UIColor?

        func render(_ state: PlayerSkinState, theme: PlayerSkinTheme) {
            renderColor = theme.color(.controlTint)
        }
    }

    @Test("DefaultPlayerSkin renders across layout modes")
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

    @Test("Action handler can be wired")
    func actionWiring() {
        let skin = AssembledPlayerSkin(blueprint: .default)
        skin.onAction = { _ in }
        skin.render(.initial)
        #expect(skin.onAction != nil)
    }

    @Test("PlayerSkinTheme uses overrides and default fallbacks")
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

    @Test("AssembledPlayerSkin passes theme during render")
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
