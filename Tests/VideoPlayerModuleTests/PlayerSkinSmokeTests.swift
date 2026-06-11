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

    private final class RenderProbeBlock: UIView, PlayerSkinBlock {
        var view: UIView { self }
        var onAction: ((PlayerSkinAction) -> Void)?
        private(set) var renderedStates: [PlayerSkinState] = []

        func render(_ state: PlayerSkinState, theme: PlayerSkinTheme) {
            renderedStates.append(state)
        }
    }

    private final class CaptionProbeOverlay: UIView, PlayerSkinCaptionOverlay {
        var view: UIView { self }
        var bottomInset: CGFloat = 0
        private(set) var updatedText: String?
        private(set) var fontSize: Int?
        private(set) var isCaptionVisible: Bool?

        override init(frame: CGRect) {
            super.init(frame: frame)
            accessibilityIdentifier = "test.captionOverlay"
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func update(text: String, isSecondary: Bool) {
            updatedText = text
        }

        func applyFontSize(_ size: Int) {
            fontSize = size
        }

        func setVisible(_ visible: Bool) {
            isCaptionVisible = visible
        }
    }

    private final class LoadingProbeOverlay: UIView, PlayerSkinLoadingOverlay {
        var view: UIView { self }
        private(set) var configuredTheme: PlayerSkinTheme?
        private(set) var isLoading = false

        override init(frame: CGRect) {
            super.init(frame: frame)
            accessibilityIdentifier = "test.loadingOverlay"
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func configure(theme: PlayerSkinTheme) {
            configuredTheme = theme
        }

        func setLoading(_ isLoading: Bool) {
            self.isLoading = isLoading
        }
    }

    private final class GestureHUDProbeOverlay: UIView, PlayerSkinGestureHUDOverlay {
        var view: UIView { self }
        private(set) var shownTitle: String?
        private(set) var presentedRate: Double?
        private(set) var didHide = false

        override init(frame: CGRect) {
            super.init(frame: frame)
            accessibilityIdentifier = "test.gestureHUDOverlay"
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func show(icon: String, title: String, detail: String?, emphasized: Bool) {
            shownTitle = title
        }

        func presentRate(_ rate: Double) {
            presentedRate = rate
        }

        func hide() {
            didHide = true
        }
    }

    @Test("AssembledPlayerSkin 기본 blueprint가 모든 layout mode에서 렌더링")
    func assembledPlayerSkinDefaultBlueprintRenders() {
        let skin: PlayerSkin = AssembledPlayerSkin()
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
        let skin: PlayerSkin = AssembledPlayerSkin()
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

        #expect(skin.view.descendant(accessibilityIdentifier: "videoPlayer.skin.extra.top") != nil)
        #expect(skin.view.descendant(accessibilityIdentifier: "videoPlayer.skin.extra.left") != nil)
        #expect(skin.view.descendant(accessibilityIdentifier: "videoPlayer.skin.extra.float") != nil)
    }

    @Test("구간반복 range block은 started/looping에서 렌더링")
    func sectionRepeatRangeRendersWhenActive() {
        let skin: PlayerSkin = AssembledPlayerSkin()
        skin.render(.initial.updating(
            isLoading: false,
            isFullScreenMode: true,
            sectionRepeat: .started(10),
            layoutMode: .fullScreen
        ))
        skin.view.layoutIfNeeded()

        let startButton = skin.view.descendant(accessibilityIdentifier: "videoPlayer.skin.sectionRepeatStartButton")
        let endButton = skin.view.descendant(accessibilityIdentifier: "videoPlayer.skin.sectionRepeatEndButton")
        #expect(startButton?.isHidden == false)
        #expect(endButton?.isHidden == false)
    }

    @Test("lock 상태에서는 재생/진행 조작을 숨기거나 비활성화")
    func lockedStateDisablesInteractiveControls() {
        let skin: PlayerSkin = AssembledPlayerSkin()
        skin.render(.initial.updating(
            isLoading: false,
            controlsVisible: true,
            isFullScreenMode: true,
            isLocked: true,
            layoutMode: .fullScreen
        ))
        skin.view.layoutIfNeeded()

        let playButton = skin.view.descendant(accessibilityIdentifier: "videoPlayer.skin.playPauseButton")
        let progressSlider = skin.view.descendant(accessibilityIdentifier: "videoPlayer.skin.progressSlider") as? UIControl
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

    @Test("AssembledPlayerSkin은 제스처 HUD를 내장하고 PlayerSkin 계약으로 표시한다")
    func assembledPlayerSkinOwnsGestureHUD() {
        let skin: PlayerSkin = AssembledPlayerSkin()
        let hud = skin.view.descendant(accessibilityIdentifier: "videoPlayer.skin.gestureHUDView")

        #expect(hud != nil)
        #expect(hud?.isHidden == true)

        skin.showGestureHUD(icon: "B", title: "밝기")
        #expect(hud?.isHidden == false)

        skin.presentRateGestureHUD(2.0)
        #expect(hud?.isHidden == false)

        skin.hideGestureHUD()
    }

    @Test("AssembledPlayerSkin은 자막 overlay를 내장하고 PlayerSkin 계약으로 갱신한다")
    func assembledPlayerSkinOwnsCaptionOverlay() {
        let skin: PlayerSkin = AssembledPlayerSkin()
        let caption = skin.view.descendant(accessibilityIdentifier: "videoPlayer.skin.captionView") as? PlayerCaptionView
        let primaryLabel = skin.view.descendant(accessibilityIdentifier: "videoPlayer.skin.caption.primaryLabel") as? UILabel

        #expect(caption != nil)
        #expect(caption?.isHidden == true)

        skin.view.frame = CGRect(x: 0, y: 0, width: 320, height: 240)
        skin.view.layoutIfNeeded()
        skin.setCaptionBottomInset(5)
        skin.setCaptionFontSize(18)
        skin.setCaptionVisible(true)
        skin.updateCaption(text: "크롬 브라우저를 실행합니다.", isSecondary: false)
        skin.updateCaptionVideoFrame(CGRect(x: 0, y: 20, width: 320, height: 180))

        #expect(caption?.isHidden == false)
        #expect(primaryLabel?.attributedText?.string.contains("크롬 브라우저") == true)
        #expect(caption?.bottomInset == 5)
    }

    @Test("시킹 프리뷰는 placeholder로 시작, 실패 확정 시 컴팩트 축소, 이미지 후 nil은 무시")
    func seekPreviewViewSwitchesContentMode() {
        let view = PlayerSeekPreviewView()

        // 공급자 없음 — 컴팩트 시작.
        view.beginSession(showsPlaceholder: false)
        #expect(view.mode == .compact)
        let compact = view.contentSize

        // 공급자 있음 — placeholder 시작(이미지 크기), 첫 nil = 실패 확정 → 컴팩트 축소.
        view.beginSession(showsPlaceholder: true)
        #expect(view.mode == .placeholder)
        let expanded = view.contentSize
        #expect(compact.height < expanded.height)
        view.setImage(nil)
        #expect(view.mode == .compact)

        // 이미지 도착 후의 단발 nil은 무시 — 직전 프레임 유지(깜빡임 방지).
        view.beginSession(showsPlaceholder: true)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 16, height: 9)).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 16, height: 9))
        }
        view.setImage(image)
        #expect(view.mode == .image)
        #expect(view.contentSize == expanded)
        view.setImage(nil)
        #expect(view.mode == .image)
    }

    @Test("시킹 프리뷰 presenter는 비활성화 상태에서 begin을 무시")
    func seekPreviewPresenterIgnoresBeginWhenDisabled() {
        let presenter = PlayerSeekPreviewPresenter()
        presenter.isEnabled = false
        presenter.begin()
        #expect(presenter.isActive == false)

        presenter.isEnabled = true
        presenter.begin()
        #expect(presenter.isActive)
        presenter.end()
        #expect(presenter.isActive == false)
    }

    @Test("스크럽 종료 직후 진행바는 보류된 이전 상태로 되돌아가지 않는다")
    func progressSliderKeepsReleasedPositionAfterScrubEnds() throws {
        let block = RenderProbeBlock()
        let blueprint = PlayerSkinBlueprint(
            blocks: [.bottomBar: [{ block }]],
            visibleSlots: [
                .verticalSplit: [.bottomBar],
                .horizontalSplit: [.bottomBar],
                .fullScreen: [.bottomBar]
            ]
        )
        let skin = AssembledPlayerSkin(blueprint: blueprint)

        skin.render(PlayerSkinState(
            playbackState: .init(status: .playing, currentTime: 20, duration: 100, isBuffering: false),
            playbackRate: 1.0,
            controlsVisible: true,
            isFullScreenMode: true,
            isDisplayScaled: false,
            layoutMode: .fullScreen
        ))
        let initialRenderCount = block.renderedStates.count

        block.onAction?(.seekBegan)
        skin.render(PlayerSkinState(
            playbackState: .init(status: .playing, currentTime: 25, duration: 100, isBuffering: false),
            playbackRate: 1.0,
            controlsVisible: true,
            isFullScreenMode: true,
            isDisplayScaled: false,
            layoutMode: .fullScreen
        ))
        #expect(block.renderedStates.count == initialRenderCount)

        block.onAction?(.seekEnded(80))

        let releasedState = try #require(block.renderedStates.last)
        #expect(releasedState.currentTime == 80)
        #expect(abs(releasedState.progress - 0.8) < 0.001)
    }

    @Test("스크럽 중 재생 상태 변경은 재생 버튼에 즉시 반영한다")
    func playbackButtonUpdatesWhileScrubbing() throws {
        let centerControls = CenterPlaybackControlsBlock()
        let probe = RenderProbeBlock()
        let blueprint = PlayerSkinBlueprint(
            blocks: [
                .centerControls: [{ centerControls }],
                .bottomBar: [{ probe }]
            ],
            visibleSlots: [
                .verticalSplit: [.centerControls, .bottomBar],
                .horizontalSplit: [.centerControls, .bottomBar],
                .fullScreen: [.centerControls, .bottomBar]
            ]
        )
        let skin = AssembledPlayerSkin(blueprint: blueprint)

        skin.render(PlayerSkinState(
            playbackState: .init(status: .playing, currentTime: 20, duration: 100, isBuffering: false),
            playbackRate: 1.0,
            controlsVisible: true,
            isFullScreenMode: true,
            isDisplayScaled: false,
            layoutMode: .fullScreen
        ))
        let playButton = try #require(
            skin.view.descendant(accessibilityIdentifier: "videoPlayer.skin.playPauseButton")
        )
        #expect(playButton.accessibilityLabel == "일시정지")
        let probeRenderCount = probe.renderedStates.count

        centerControls.onAction?(.seekBegan)
        skin.render(PlayerSkinState(
            playbackState: .init(status: .paused, currentTime: 20, duration: 100, isBuffering: false),
            playbackRate: 1.0,
            controlsVisible: true,
            isFullScreenMode: true,
            isDisplayScaled: false,
            layoutMode: .fullScreen
        ))

        #expect(probe.renderedStates.count == probeRenderCount)
        #expect(playButton.accessibilityLabel == "재생")

        centerControls.onAction?(.seekEnded(20))
    }

    @Test("HTML 자막의 끝 BR은 빈 줄 높이를 만들지 않는다")
    func captionTrimsTrailingHTMLLineBreak() {
        let caption = PlayerCaptionView()
        let primaryLabel = caption.descendant(accessibilityIdentifier: "videoPlayer.skin.caption.primaryLabel") as? UILabel

        caption.applyFontSize(18)
        caption.setVisible(true)
        caption.update(text: "HAR 파일 생성 방법을 설명합니다.<BR>", isSecondary: false)

        #expect(primaryLabel?.attributedText?.string == "HAR 파일 생성 방법을 설명합니다.")
    }

    @Test("주/보조 자막은 같은 stack에서 단독이면 같은 위치, 동시 표시면 위아래로 배치")
    func captionStackPlacesSingleAndDualCaptions() throws {
        let primaryOnly = PlayerCaptionView()
        primaryOnly.frame = CGRect(x: 0, y: 0, width: 320, height: 240)
        primaryOnly.applyFontSize(18)
        primaryOnly.setVisible(true)
        primaryOnly.update(text: "메인 자막", isSecondary: false)
        primaryOnly.layoutIfNeeded()

        let primaryOnlyLabel = try #require(
            primaryOnly.descendant(accessibilityIdentifier: "videoPlayer.skin.caption.primaryLabel") as? UILabel
        )
        let primaryStack = try #require(primaryOnlyLabel.superview as? UIStackView)
        #expect(primaryStack.axis == .vertical)

        let secondaryOnly = PlayerCaptionView()
        secondaryOnly.frame = CGRect(x: 0, y: 0, width: 320, height: 240)
        secondaryOnly.applyFontSize(18)
        secondaryOnly.setVisible(true)
        secondaryOnly.update(text: "보조 자막", isSecondary: true)
        secondaryOnly.layoutIfNeeded()

        let secondaryOnlyLabel = try #require(
            secondaryOnly.descendant(accessibilityIdentifier: "videoPlayer.skin.caption.secondaryLabel") as? UILabel
        )
        let secondaryStack = try #require(secondaryOnlyLabel.superview as? UIStackView)
        #expect(secondaryStack.axis == .vertical)
        #expect(abs(primaryOnlyLabel.frame.maxY - secondaryOnlyLabel.frame.maxY) < 1)

        let dualCaption = PlayerCaptionView()
        dualCaption.frame = CGRect(x: 0, y: 0, width: 320, height: 240)
        dualCaption.applyFontSize(18)
        dualCaption.setVisible(true)
        dualCaption.update(text: "메인 자막", isSecondary: false)
        dualCaption.update(text: "보조 자막", isSecondary: true)
        dualCaption.layoutIfNeeded()

        let primaryLabel = try #require(
            dualCaption.descendant(accessibilityIdentifier: "videoPlayer.skin.caption.primaryLabel") as? UILabel
        )
        let secondaryLabel = try #require(
            dualCaption.descendant(accessibilityIdentifier: "videoPlayer.skin.caption.secondaryLabel") as? UILabel
        )
        #expect(primaryLabel.superview === secondaryLabel.superview)
        #expect(primaryLabel.isHidden == false)
        #expect(secondaryLabel.isHidden == false)
        #expect(primaryLabel.frame.maxY <= secondaryLabel.frame.minY)
    }

    @Test("PlayerSkinBlueprint가 overlay 구현을 주입한다")
    func playerSkinBlueprintInjectsOverlayImplementations() {
        let caption = CaptionProbeOverlay()
        let loading = LoadingProbeOverlay()
        let gestureHUD = GestureHUDProbeOverlay()
        var blueprint = PlayerSkinBlueprint.default
        blueprint.overlays = [
            .caption: { caption },
            .loading: { loading },
            .gestureHUD: { gestureHUD }
        ]

        let skin: PlayerSkin = AssembledPlayerSkin(blueprint: blueprint)
        skin.view.frame = CGRect(x: 0, y: 0, width: 320, height: 240)
        skin.view.layoutIfNeeded()

        #expect(skin.view.descendant(accessibilityIdentifier: "test.captionOverlay") != nil)
        #expect(skin.view.descendant(accessibilityIdentifier: "test.loadingOverlay") != nil)
        #expect(skin.view.descendant(accessibilityIdentifier: "test.gestureHUDOverlay") != nil)

        skin.updateCaption(text: "주입 자막", isSecondary: false)
        skin.setCaptionFontSize(20)
        skin.setCaptionVisible(true)
        skin.updateCaptionVideoFrame(CGRect(x: 0, y: 20, width: 320, height: 180))
        skin.render(.initial.updating(isLoading: true))
        skin.showGestureHUD(icon: "B", title: "밝기")
        skin.presentRateGestureHUD(2.0)
        skin.hideGestureHUD()

        #expect(caption.updatedText == "주입 자막")
        #expect(caption.fontSize == 20)
        #expect(caption.isCaptionVisible == true)
        #expect(caption.bottomInset == 5)
        #expect(loading.configuredTheme != nil)
        #expect(loading.isLoading == true)
        #expect(gestureHUD.shownTitle == "밝기")
        #expect(gestureHUD.presentedRate == 2.0)
        #expect(gestureHUD.didHide == true)
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
