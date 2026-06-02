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
            ExtraControl(id: "q", iconName: "PlayerWriteNormal", title: "Q", placement: .topMenu),
            ExtraControl(
                id: "x",
                iconName: "PlayerBookmarkListNormal",
                selectedIconName: "PlayerBookmarkListSelected",
                title: "B",
                placement: .leftMenu,
                isSelected: true
            ),
            ExtraControl(id: "n", iconName: "", title: "다음 강의", placement: .floating)
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

    @Test("ExtraControl placement와 selectedIconName을 렌더링")
    func extraControlPlacementsRender() {
        let skin: PlayerSkin = DefaultPlayerSkin()
        skin.setExtraControls([
            ExtraControl(id: "top", iconName: "PlayerWriteNormal", title: "Q", placement: .topMenu),
            ExtraControl(
                id: "left",
                iconName: "PlayerBookmarkListNormal",
                selectedIconName: "PlayerBookmarkListSelected",
                title: "B",
                placement: .leftMenu,
                isSelected: true
            ),
            ExtraControl(id: "float", iconName: "", title: "다음 강의", placement: .floating)
        ])

        skin.render(.initial.updating(isLoading: false, isFullScreenMode: true, layoutMode: .fullScreen))
        skin.view.layoutIfNeeded()

        #expect(skin.view.descendant(accessibilityIdentifier: "lecturePlayer.skin.extra.top") != nil)
        #expect(skin.view.descendant(accessibilityIdentifier: "lecturePlayer.skin.extra.left") != nil)
        #expect(skin.view.descendant(accessibilityIdentifier: "lecturePlayer.skin.extra.float") != nil)
    }

    @Test("구간반복 range block은 started/looping에서 렌더링")
    func sectionRepeatRangeRendersWhenActive() {
        let skin: PlayerSkin = DefaultPlayerSkin()
        skin.render(.initial.updating(
            isLoading: false,
            isFullScreenMode: true,
            sectionRepeat: .started(10),
            layoutMode: .fullScreen
        ))
        skin.view.layoutIfNeeded()

        let startButton = skin.view.descendant(accessibilityIdentifier: "lecturePlayer.skin.sectionRepeatStartButton")
        let endButton = skin.view.descendant(accessibilityIdentifier: "lecturePlayer.skin.sectionRepeatEndButton")
        #expect(startButton?.isHidden == false)
        #expect(endButton?.isHidden == false)
    }

    @Test("lock 상태에서는 재생/진행 조작을 숨기거나 비활성화")
    func lockedStateDisablesInteractiveControls() {
        let skin: PlayerSkin = DefaultPlayerSkin()
        skin.render(.initial.updating(
            isLoading: false,
            controlsVisible: true,
            isFullScreenMode: true,
            isLocked: true,
            layoutMode: .fullScreen
        ))
        skin.view.layoutIfNeeded()

        let playButton = skin.view.descendant(accessibilityIdentifier: "lecturePlayer.skin.playPauseButton")
        let progressSlider = skin.view.descendant(accessibilityIdentifier: "lecturePlayer.skin.progressSlider") as? UIControl
        #expect(playButton?.isEffectivelyHidden == true)
        #expect(progressSlider?.isEnabled == false)
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

private extension UIView {
    var isEffectivelyHidden: Bool {
        if isHidden || alpha == 0 { return true }
        return superview?.isEffectivelyHidden ?? false
    }

    func descendant(accessibilityIdentifier: String) -> UIView? {
        if self.accessibilityIdentifier == accessibilityIdentifier {
            return self
        }
        for subview in subviews {
            if let match = subview.descendant(accessibilityIdentifier: accessibilityIdentifier) {
                return match
            }
        }
        return nil
    }
}
#endif
