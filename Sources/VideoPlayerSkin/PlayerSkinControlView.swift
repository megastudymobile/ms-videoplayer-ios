//
//  PlayerSkinControlView.swift
//  SmartPlayer
//
//  Created by 모바일팀_정준영 on 2026/05/19.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import UIKit

public final class PlayerSkinControlView: UIView, PlayerSkin {
    /// spec-064 후속 — PlayerSkin 채택. host 가 add 할 실제 뷰.
    public var view: UIView { self }

    /// spec-064 Phase 2 — Rx 제거. skin 은 클로저로 액션을 forward 한다 (패키지 Rx-free 준비).
    /// host(ShellVC) 가 주입해 PlayerSkinAction → reactor action 으로 매핑한다.
    public var onAction: ((PlayerSkinAction) -> Void)?

    private let topBarView = UIView()
    private let bottomBarView = UIView()
    /// spec-063 P7 — dev `MGPlayerSkinView` 의 center horizontal control stack parity.
    /// backward/play/forward 를 영상 영역 floating 으로 분리 (bottomBarView 의 progress 와 별개).
    /// 세로: 영상 letterbox 영역 좌측 정렬, 가로 fullscreen: 영상 중앙 정렬.
    private let centerControlsContainerView = UIView()
    private let leftMenuStackView = UIStackView()
    /// spec-063 P3 — dev `MGPlayerSkinView` 가로 fullscreen 우측 vertical control.
    /// dev 우측 stack 구조: `^` (rate up) / `1.0x` (rate label) / `v` (rate down). 음량/밝기는
    /// 신 모듈에서 swipe gesture (`handlePan`) 로 처리하므로 우측 메뉴는 rate 전용으로 한정.
    private let rightMenuStackView = UIStackView()
    private let rateUpButton = UIButton(type: .system)
    private let rateDownButton = UIButton(type: .system)
    private let titleLabel = UILabel()
    private let closeButton = UIButton(type: .system)
    private let displayScalingButton = UIButton(type: .system)
    /// spec-062 C5 — dev `MGPlayerSkinView` top bar `holdButton` parity.
    /// dev asset: normal `PlayerUnlockNormal` (잠금해제 상태 표시), selected `PlayerLockNormal` (잠금 상태 표시).
    /// dev `MGPlayerSkinView.m:676-695` 의 image 매핑 + `didSelectHold` 콜백.
    private let lockButton = UIButton(type: .system)
    /// spec-062 C5 — dev `MGPlayerSkinView` top bar `moreButton` parity.
    /// dev asset: `PlayerMoreNormal`. dev `MGPlayerSkinView.m:700-712` 의 `didSelectMore:` 콜백.
    private let moreButton = UIButton(type: .system)
    private let playPauseButton = UIButton(type: .system)
    private let backwardButton = UIButton(type: .system)
    private let forwardButton = UIButton(type: .system)
    /// spec-062 C6 — dev `MGPlayerSkinView` 의 `backwardLabel`/`forwardLabel` parity.
    /// dev `MGPlayerSkinView.m:1525-1531` `setBackwardForwardInterval:` 가 seek 간격(10)을
    /// 12pt SemiBold + slWhite03 색 attributedString 으로 button center 위 overlay 한다.
    private let backwardIntervalLabel = UILabel()
    private let forwardIntervalLabel = UILabel()
    private let screenModeButton = UIButton(type: .system)
    private let rateButton = UIButton(type: .system)
    private let settingMenuButton = UIButton(type: .system)
    /// spec-064 Phase 1 — host 주입 추가 버튼(ExtraControl). skin 은 의미를 모르고 id 만 forward.
    /// leftMenu: sectionRepeat 와 setting 사이 아이콘 버튼. floating: bottomBar 위 타이틀 버튼(다음 강의).
    private var extraControls: [ExtraControl] = []
    private var leftMenuExtraButtons: [(id: String, button: UIButton)] = []
    private var floatingExtraButtons: [(id: String, button: UIButton)] = []
    /// spec-063 P2 — dev `MGPlayerSkinView` 가로 fullscreen 좌측 메뉴의 `sectionRepeatButton` parity.
    /// dev `MGPlayerSkinView.h:368` `sectionRepeatButton` 1:1.
    /// asset 미존재 시 fallback "AB" 텍스트 사용.
    private let sectionRepeatButton = UIButton(type: .system)
    private let currentTimeLabel = UILabel()
    private let durationLabel = UILabel()
    private let progressSlider = PlayerPlaybackSlider()
    private let spacerView = UIView()

    private var latestState = PlayerSkinState.initial
    private var rateOptions: [Double] = [1.0]
    private var isSeeking = false
    /// spec-063 P4 — center 컨트롤(`backwardButton`/`playPauseButton`/`forwardButton`) 가
    /// mode 별로 좌측 정렬(verticalSplit/horizontalSplit) vs 중앙 정렬(fullScreen) 전환.
    /// 두 constraint 를 미리 만들고 mode 변경 시 active 토글.
    private var centerControlsLeadingConstraint: NSLayoutConstraint?
    private var centerControlsCenterXConstraint: NSLayoutConstraint?

    public override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
        configureActions()
        render(.initial)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func configure(title: String, maxPlaybackRate: Double) {
        titleLabel.text = title
        updateRateMenu(maxPlaybackRate: maxPlaybackRate)
    }

    /// spec-063 P13 — settings panel 의 스킵 간격 변경 즉시 반영용 외부 API.
    /// 내부 `setSkipInterval(seconds:)` 를 외부에서 호출 가능하게 wrap.
    public func updateSkipIntervalLabel(seconds: Int) {
        setSkipInterval(seconds: seconds)
    }

    public func render(_ state: PlayerSkinState) {
        latestState = state

        // spec-054 P2a — lock state (hold 버튼) 시 control 가시성 차단.
        // dev `holdButton` (MGPlayerSkinView.h:302) → 영상/close 만 visible, 나머지 차단.
        let isLocked = state.isLocked
        let baseVisible = state.controlsVisible && !isLocked
        topBarView.alpha = state.controlsVisible ? 1 : 0  // close 는 lock 중에도 사용 가능
        bottomBarView.alpha = baseVisible ? 1 : 0
        leftMenuStackView.alpha = baseVisible ? 1 : 0
        rightMenuStackView.alpha = baseVisible ? 1 : 0
        // spec-063 P7 — centerControls / rateButton 도 baseVisible 게이트.
        centerControlsContainerView.alpha = baseVisible ? 1 : 0
        rateButton.alpha = baseVisible ? 1 : 0

        // spec-063 P10-A — isLoading gate 제거. dev `MGPlayerSkinView` 는 controls 항상 활성.
        // 시뮬레이터/영상 로드 전에도 흰색 유지 (lock 만 disable).
        playPauseButton.isEnabled = !isLocked
        backwardButton.isEnabled = !isLocked
        forwardButton.isEnabled = !isLocked
        progressSlider.isEnabled = !isLocked
        rateButton.isEnabled = !isLocked
        rateUpButton.isEnabled = !isLocked
        rateDownButton.isEnabled = !isLocked

        setPlayPauseButton(isPlaying: state.isPlaying)
        setDisplayScalingButton(isDisplayScaled: state.isDisplayScaled)
        // spec-063 P10-B — screenMode 아이콘은 layoutMode 기반으로 분기.
        // fullScreen 일 때 ✚(축소), 그 외 ⛶(확대). isFullScreenMode 만 의존하면 initial state 미동기화 시 잘못된 아이콘 표시.
        setScreenModeButton(isFullScreenMode: state.layoutMode == .fullScreen)
        setLockButton(isLocked: isLocked)
        setSectionRepeatButton(state: state.sectionRepeat)
        playPauseButton.accessibilityLabel = state.isPlaying ? "일시정지" : "재생"

        // spec-062 C5 — 잠금 상태에서 close / lockButton 외 top bar 버튼 차단.
        // dev `MGPlayerSkinView.m:1946-1947` `holdButton.userInteractionEnabled` 등 parity.
        displayScalingButton.isEnabled = !isLocked
        moreButton.isEnabled = !isLocked
        // spec-063 followup — leftMenu / rightMenu 버튼도 lock 시 차단 (dev 동등).
        // P10-A — isLoading gate 제거.
        sectionRepeatButton.isEnabled = !isLocked
        settingMenuButton.isEnabled = !isLocked

        if isSeeking == false {
            progressSlider.value = state.progress
            currentTimeLabel.text = state.currentTimeText
        }

        durationLabel.text = state.durationText
        // spec-062 C7 — dev `SLPlayerManager.m:42` `playbackRateText:` 가 `%.1fx` 포맷
        // (`1.0x`, `1.5x`, `2.0x`) 으로 표시한다. parity 유지.
        rateButton.setTitle(String(format: "%.1fx", state.playbackRate), for: .normal)

        // spec-063 P1 — chrome 분기. mode 별 표시/배치를 1:1 매핑.
        applyLayoutMode(state.layoutMode)

        // spec-064 Phase 1 — host 주입 추가 버튼(다음 강의 등) 가시성/잠금 적용.
        renderExtraControls(state)
    }

    /// spec-064 Phase 1 — host(강의 등)가 추가 버튼을 주입한다. 기존 동적 버튼을 교체한다.
    /// `.leftMenu` 는 sectionRepeat 와 setting 사이 아이콘, `.floating` 은 bottomBar 위 타이틀 버튼.
    public func setExtraControls(_ controls: [ExtraControl]) {
        leftMenuExtraButtons.forEach { $0.button.removeFromSuperview() }
        floatingExtraButtons.forEach { $0.button.removeFromSuperview() }
        leftMenuExtraButtons.removeAll()
        floatingExtraButtons.removeAll()
        extraControls = controls

        for control in controls {
            switch control.placement {
            case .leftMenu:
                let button = makeExtraIconButton(control)
                // sectionRepeat(index 0) 다음, setting(마지막) 앞에 순서대로 삽입 — dev leftMenu parity.
                let insertIndex = 1 + leftMenuExtraButtons.count
                leftMenuStackView.insertArrangedSubview(button, at: insertIndex)
                button.widthAnchor.constraint(equalToConstant: Metric.iconButtonSize).isActive = true
                button.heightAnchor.constraint(equalToConstant: Metric.iconButtonSize).isActive = true
                leftMenuExtraButtons.append((control.id, button))
            case .floating:
                let button = makeExtraFloatingButton(control)
                addSubview(button)
                button.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    button.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -Metric.sideInset),
                    button.bottomAnchor.constraint(equalTo: bottomBarView.topAnchor, constant: -12),
                    button.heightAnchor.constraint(equalToConstant: 36)
                ])
                floatingExtraButtons.append((control.id, button))
            }
        }
        renderExtraControls(latestState)
    }
}

private extension PlayerSkinControlView {
    enum Metric {
        // dev `MGPlayerSkinView.m:65` — kSLPlayerTopBottomHeight = 50pt.
        static let topBarHeight: CGFloat = 50
        static let bottomBarHeight: CGFloat = 50
        // dev `MGPlayerSkinView.m:60` — kSLPlayerHorizontalInset = 20pt.
        static let sideInset: CGFloat = 20
        static let iconButtonSize: CGFloat = 44
        static let leftMenuWidth: CGFloat = 48
        // spec-052 Phase 4.2 — dev kMGPlayerSkinProgressSliderHeight 21pt.
        static let progressSliderHeight: CGFloat = 21
        static let progressTopInset: CGFloat = 4
        static let timeTopInset: CGFloat = 1
        // spec-063 P10-E + P14 — dev `MGPlayerSkinView` center control inter-button spacing parity.
        // P10 의 80pt 는 과도. 사용자 visual 확인 결과 56pt 정도가 레거시 일치.
        static let centerControlSpacing: CGFloat = 56
        // spec-063 P10-D — dev 의 floating rate button 크기 32pt parity (44 → 32).
        static let floatingRateButtonSize: CGFloat = 36
    }

    func configureUI() {
        // backgroundColor 는 .clear 유지. dev `MGPlayerSkinView.m:621` 의 RGBAColor(0,0,0,0.5)
        // 는 SkinView 전체에 적용 = controls hidden 시점에도 영상 어두워짐. swift 의 render()
        // 가 topBar/bottomBar/leftMenu 만 alpha 토글 → 별도 dim layer 추가 필요 (큰 작업).
        // 본 commit 에서는 적용 보류 — Phase 4.4 marker / 4.5 settings 와 함께 별도 spec.
        backgroundColor = .clear

        configureBar(topBarView)
        configureBar(bottomBarView)

        // spec-052 Phase 4.1 — dev kMGPlayerSkinTitleLabelFontSize 16pt + AppleSDGothicNeo Regular.
        // swift system font Regular 로 매칭 (AppleSDGothicNeo 직접 사용 시 폰트 family 등록 추가 필요).
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 16, weight: .regular)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.textAlignment = .left
        titleLabel.numberOfLines = 1

        // spec-052 Phase 4.1 — dev Asset Catalog PNG 사용. setButtonImageOrTitle 가 asset
        // 없을 시 SF Symbol fallback.
        configureIconButton(closeButton, imageName: "PlayerCloseNormal")
        configureIconButton(displayScalingButton, imageName: "PlayerScreenScalingAspectFitNormal")
        configureIconButton(playPauseButton, imageName: "PlayerPlayNormal")
        configureIconButton(backwardButton, imageName: "PlayerBackwardNormal")
        configureIconButton(forwardButton, imageName: "PlayerForwardNormal")
        configureIconButton(screenModeButton, imageName: "PlayerScreenPortraitNormal")
        // spec-062 C5 — top bar lock/more 버튼 초기 image (normal state = unlocked icon).
        // dev `MGPlayerSkinView.m:676-695` lockImage(`PlayerUnlockNormal`) for Normal state.
        configureIconButton(lockButton, imageName: "PlayerUnlockNormal")
        configureIconButton(moreButton, imageName: "PlayerMoreNormal")

        // spec-062 C6 — dev `MGPlayerSkinView.m:1525-1531`, `:1983-1990` parity.
        // font: AppleSDGothicNeo SemiBold 12pt → 신은 system semibold 12pt 로 대체.
        // color: dev `slWhite03` (white α0.9 추정) — currentTimeLabel 과 동일 매핑.
        configureSkipIntervalLabel(backwardIntervalLabel)
        configureSkipIntervalLabel(forwardIntervalLabel)
        setSkipInterval(seconds: 10)

        closeButton.accessibilityIdentifier = "lecturePlayer.skin.closeButton"
        displayScalingButton.accessibilityIdentifier = "lecturePlayer.skin.displayScalingButton"
        playPauseButton.accessibilityIdentifier = "lecturePlayer.skin.playPauseButton"
        progressSlider.accessibilityIdentifier = "lecturePlayer.skin.progressSlider"
        screenModeButton.accessibilityIdentifier = "lecturePlayer.skin.screenModeButton"
        rateButton.accessibilityIdentifier = "lecturePlayer.skin.rateButton"
        lockButton.accessibilityIdentifier = "lecturePlayer.skin.lockButton"
        moreButton.accessibilityIdentifier = "lecturePlayer.skin.moreButton"
        lockButton.accessibilityLabel = "화면 잠금"
        moreButton.accessibilityLabel = "더보기"

        // spec-052 Phase 4.2 — dev kMGPlayerSkinPlaybackTimeLabelFontSize 11pt + Regular.
        // dev `playbackTimeLabel.textColor = slWhite03` (90% white 추정) → white.alpha(0.9).
        currentTimeLabel.textColor = UIColor.white.withAlphaComponent(0.9)
        currentTimeLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        // spec-063 P10-C — slider 아래 좌측 정렬 (dev parity).
        currentTimeLabel.textAlignment = .left

        // spec-052 Phase 4.2 — dev kMGPlayerSkinTotalPlaybackTimeLabelFontSize 11pt + Regular.
        durationLabel.textColor = UIColor.white.withAlphaComponent(0.9)
        durationLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        // spec-063 P10-C — slider 아래 우측 정렬 (dev parity).
        durationLabel.textAlignment = .right

        progressSlider.minimumValue = 0
        progressSlider.maximumValue = 1
        // parity-I3 — dev `MGPlayerSkinView` 의 progress tint 는 `slPrimarySkyBlue` Asset Catalog 색.
        progressSlider.minimumTrackTintColor = UIColor(named: "primarySkyBlue") ?? .systemBlue
        // spec-052 Phase 4.2 — dev `SLPlayerPlaybackSlider` maximumTrack = slLineGrey03 (Line/grey-03).
        progressSlider.maximumTrackTintColor = UIColor(named: "Line/grey-03") ?? UIColor.white.withAlphaComponent(0.35)
        // spec-052 Phase 4.2 — dev thumbImage = "PlayerPlaybackSliderCircleNormal" Asset.
        if let thumbImage = UIImage(named: "PlayerPlaybackSliderCircleNormal") {
            progressSlider.setThumbImage(thumbImage, for: .normal)
        }

        // spec-063 P7 — dev `SLPlayerRateControlView` 의 floating 회색 원형 parity.
        // bottomBar inline 에서 영상 우측 끝 floating 으로 분리.
        rateButton.tintColor = .white
        rateButton.setTitleColor(.white, for: .normal)
        rateButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        rateButton.titleLabel?.adjustsFontSizeToFitWidth = true
        rateButton.titleLabel?.minimumScaleFactor = 0.7
        rateButton.backgroundColor = UIColor(white: 0.3, alpha: 0.65)
        rateButton.layer.cornerRadius = 22
        rateButton.layer.masksToBounds = true
        rateButton.accessibilityIdentifier = "lecturePlayer.skin.rateButton"

        leftMenuStackView.axis = .vertical
        leftMenuStackView.alignment = .center
        leftMenuStackView.distribution = .equalSpacing
        leftMenuStackView.spacing = 12
        // spec-052 Phase 4.1 — dev `MGPlayerSkinView.m:560` leftMenuStackView.backgroundColor = clearColor.
        leftMenuStackView.backgroundColor = .clear
        leftMenuStackView.layoutMargins = UIEdgeInsets(top: 12, left: 0, bottom: 12, right: 0)
        leftMenuStackView.isLayoutMarginsRelativeArrangement = true

        configureIconButton(settingMenuButton, imageName: "PlayerMoreNormal")
        // spec-063 P2 — sectionRepeat 버튼 (가로 fullscreen 전용).
        // Asset Catalog 실 이름: PlayerRepeatNormal (idle/started), PlayerRepeatSelected (looping).
        configureIconButton(sectionRepeatButton, imageName: "PlayerRepeatNormal")
        sectionRepeatButton.accessibilityIdentifier = "lecturePlayer.skin.sectionRepeatButton"
        sectionRepeatButton.accessibilityLabel = "구간 반복"

        settingMenuButton.isEnabled = true
        settingMenuButton.accessibilityIdentifier = "lecturePlayer.skin.settingMenuButton"

        // spec-064 Phase 1 — 고정 버튼은 sectionRepeat(범용) → setting(범용) 2개만.
        // 강의 인덱스/북마크 = host 주입 ExtraControl 로 `setExtraControls(_:)` 가 둘 사이에 동적 삽입.
        // dev leftMenu 순서: sectionRepeat → lectureIndex → bookmark → setting (parity 유지).
        [sectionRepeatButton, settingMenuButton].forEach { button in
            leftMenuStackView.addArrangedSubview(button)
            button.widthAnchor.constraint(equalToConstant: Metric.iconButtonSize).isActive = true
            button.heightAnchor.constraint(equalToConstant: Metric.iconButtonSize).isActive = true
        }

        // spec-063 P3 — 가로 fullscreen 우측 vertical: rateUp / rateDown.
        rightMenuStackView.axis = .vertical
        rightMenuStackView.alignment = .center
        rightMenuStackView.distribution = .equalSpacing
        rightMenuStackView.spacing = 12
        rightMenuStackView.backgroundColor = .clear
        rightMenuStackView.layoutMargins = UIEdgeInsets(top: 12, left: 0, bottom: 12, right: 0)
        rightMenuStackView.isLayoutMarginsRelativeArrangement = true

        // spec-063 followup — Asset Catalog 실 이름 매핑.
        configureIconButton(rateUpButton, imageName: "PlayerRatePlusButton")
        configureIconButton(rateDownButton, imageName: "PlayerRateMinusButton")
        rateUpButton.accessibilityIdentifier = "lecturePlayer.skin.rateUpButton"
        rateDownButton.accessibilityIdentifier = "lecturePlayer.skin.rateDownButton"
        rateUpButton.accessibilityLabel = "배속 빠르게"
        rateDownButton.accessibilityLabel = "배속 느리게"

        [rateUpButton, rateDownButton].forEach { button in
            rightMenuStackView.addArrangedSubview(button)
            button.widthAnchor.constraint(equalToConstant: Metric.iconButtonSize).isActive = true
            button.heightAnchor.constraint(equalToConstant: Metric.iconButtonSize).isActive = true
        }

        addSubview(topBarView)
        addSubview(bottomBarView)
        // spec-063 P7 — centerControls + rateButton 을 bottomBarView 와 분리하여 영상 영역 floating.
        addSubview(centerControlsContainerView)
        addSubview(rateButton)
        addSubview(leftMenuStackView)
        addSubview(rightMenuStackView)

        topBarView.addSubview(closeButton)
        topBarView.addSubview(titleLabel)
        topBarView.addSubview(displayScalingButton)
        // spec-062 C5 — dev `MGPlayerSkinView.m:1076-1077` 의 topMenuStackView 에
        // `holdButton`, `moreButton` 을 add 한 parity. 신은 stackView 없이 trailing chain
        // (우→좌: more → lock → displayScaling) 로 배치.
        topBarView.addSubview(lockButton)
        topBarView.addSubview(moreButton)
        topBarView.addSubview(spacerView)

        // spec-063 P7 — center 컨트롤은 centerControlsContainerView 안.
        centerControlsContainerView.addSubview(backwardButton)
        centerControlsContainerView.addSubview(playPauseButton)
        centerControlsContainerView.addSubview(forwardButton)
        centerControlsContainerView.addSubview(backwardIntervalLabel)
        centerControlsContainerView.addSubview(forwardIntervalLabel)

        // bottomBarView 는 progress 전용 (currentTime / slider / duration / screenMode).
        bottomBarView.addSubview(currentTimeLabel)
        bottomBarView.addSubview(progressSlider)
        bottomBarView.addSubview(durationLabel)
        bottomBarView.addSubview(screenModeButton)

        setupConstraints()
        updateRateMenu(maxPlaybackRate: 2.0)
    }

    func configureBar(_ view: UIView) {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.52)
    }

    /// spec-062 C6 — seek 버튼 center 위의 "10" 숫자 라벨.
    /// dev `MGPlayerSkinView.m:1983-1990` `backwardForwardNormalAttributes`:
    /// font `AppleSDGothicNeo SemiBold 12pt`, color `slWhite03`.
    /// 신은 system semibold 12pt + white α0.9 매핑.
    func configureSkipIntervalLabel(_ label: UILabel) {
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = UIColor.white.withAlphaComponent(0.9)
        label.textAlignment = .center
        label.numberOfLines = 1
        label.isUserInteractionEnabled = false
    }

    /// spec-062 C6 — dev `setBackwardForwardInterval:` (`MGPlayerSkinView.m:1525-1531`) parity.
    func setSkipInterval(seconds: Int) {
        let text = "\(seconds)"
        backwardIntervalLabel.text = text
        forwardIntervalLabel.text = text
    }

    func configureIconButton(_ button: UIButton, imageName: String) {
        button.tintColor = .white
        setButtonImageOrTitle(
            button,
            imageName: imageName,
            fallbackTitle: fallbackTitle(for: imageName)
        )
        button.imageView?.contentMode = .scaleAspectFit
    }

    func fallbackTitle(for imageName: String) -> String {
        switch imageName {
        case "PlayerCloseNormal", "xmark":
            return "X"
        case "PlayerScreenScalingAspectFitNormal", "arrow.up.left.and.arrow.down.right":
            return "Fill"
        case "PlayerScreenScalingAspectFillNormal", "arrow.down.right.and.arrow.up.left":
            return "Fit"
        case "PlayerPlayNormal", "play.fill":
            return "Play"
        case "PlayerBackwardNormal", "gobackward.10":
            return "-10"
        case "PlayerForwardNormal", "goforward.10":
            return "+10"
        case "PlayerIndexlListNormal", "list.bullet":
            return "List"
        case "PlayerBookmarkListNormal", "bookmark":
            return "BM"
        case "PlayerMoreNormal", "gearshape":
            return "Set"
        case "PlayerPauseNormal", "pause.fill":
            return "II"
        case "PlayerScreenLandscapeNormal", "rectangle.expand.vertical", "rectangle.landscape.rotate":
            return "L"
        case "PlayerScreenPortraitNormal", "rectangle.portrait":
            return "P"
        case "PlayerUnlockNormal", "lock.open":
            return "Unlock"
        case "PlayerLockNormal", "lock.fill", "lock":
            return "Lock"
        case "PlayerRepeatNormal", "repeat":
            return "AB"
        case "PlayerRepeatSelected", "repeat.1":
            return "AB●"
        case "PlayerRatePlusButton", "chevron.up":
            return "^"
        case "PlayerRateMinusButton", "chevron.down":
            return "v"
        default:
            return ""
        }
    }

    func setupConstraints() {
        [
            topBarView,
            bottomBarView,
            leftMenuStackView,
            closeButton,
            titleLabel,
            displayScalingButton,
            lockButton,
            moreButton,
            spacerView,
            backwardButton,
            backwardIntervalLabel,
            playPauseButton,
            forwardButton,
            forwardIntervalLabel,
            currentTimeLabel,
            progressSlider,
            durationLabel,
            screenModeButton,
            rateButton,
            sectionRepeatButton,
            rightMenuStackView,
            rateUpButton,
            rateDownButton,
            centerControlsContainerView
        ].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        currentTimeLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        durationLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        progressSlider.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        screenModeButton.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        rateButton.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let currentTimePreferredWidth = currentTimeLabel.widthAnchor.constraint(equalToConstant: 52)
        currentTimePreferredWidth.priority = .defaultHigh
        let durationPreferredWidth = durationLabel.widthAnchor.constraint(equalToConstant: 52)
        durationPreferredWidth.priority = .defaultHigh
        let screenModePreferredWidth = screenModeButton.widthAnchor.constraint(equalToConstant: Metric.iconButtonSize)
        screenModePreferredWidth.priority = .defaultHigh
        let ratePreferredWidth = rateButton.widthAnchor.constraint(equalToConstant: 52)
        ratePreferredWidth.priority = .defaultHigh

        NSLayoutConstraint.activate([
            topBarView.topAnchor.constraint(equalTo: topAnchor),
            topBarView.leadingAnchor.constraint(equalTo: leadingAnchor),
            topBarView.trailingAnchor.constraint(equalTo: trailingAnchor),
            topBarView.heightAnchor.constraint(equalToConstant: Metric.topBarHeight),

            closeButton.leadingAnchor.constraint(equalTo: topBarView.safeAreaLayoutGuide.leadingAnchor, constant: Metric.sideInset),
            closeButton.centerYAnchor.constraint(equalTo: topBarView.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: Metric.iconButtonSize),
            closeButton.heightAnchor.constraint(equalToConstant: Metric.iconButtonSize),

            titleLabel.leadingAnchor.constraint(equalTo: closeButton.trailingAnchor, constant: 8),
            titleLabel.centerYAnchor.constraint(equalTo: topBarView.centerYAnchor),

            spacerView.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 8),
            spacerView.trailingAnchor.constraint(equalTo: displayScalingButton.leadingAnchor, constant: -8),
            spacerView.centerYAnchor.constraint(equalTo: topBarView.centerYAnchor),

            // spec-062 C5 — dev top bar 우측 순서 (`MGPlayerSkinView.m:1076-1077`):
            // `screenScalingButton → holdButton → moreButton` (우측 끝 = moreButton).
            // 신은 좌→우: displayScaling → lock → more.
            displayScalingButton.trailingAnchor.constraint(equalTo: lockButton.leadingAnchor, constant: -4),
            displayScalingButton.centerYAnchor.constraint(equalTo: topBarView.centerYAnchor),
            displayScalingButton.widthAnchor.constraint(equalToConstant: Metric.iconButtonSize),
            displayScalingButton.heightAnchor.constraint(equalToConstant: Metric.iconButtonSize),

            lockButton.trailingAnchor.constraint(equalTo: moreButton.leadingAnchor, constant: -4),
            lockButton.centerYAnchor.constraint(equalTo: topBarView.centerYAnchor),
            lockButton.widthAnchor.constraint(equalToConstant: Metric.iconButtonSize),
            lockButton.heightAnchor.constraint(equalToConstant: Metric.iconButtonSize),

            moreButton.trailingAnchor.constraint(equalTo: topBarView.safeAreaLayoutGuide.trailingAnchor, constant: -Metric.sideInset),
            moreButton.centerYAnchor.constraint(equalTo: topBarView.centerYAnchor),
            moreButton.widthAnchor.constraint(equalToConstant: Metric.iconButtonSize),
            moreButton.heightAnchor.constraint(equalToConstant: Metric.iconButtonSize),

            leftMenuStackView.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: Metric.sideInset),
            leftMenuStackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            leftMenuStackView.widthAnchor.constraint(equalToConstant: Metric.leftMenuWidth),

            // spec-063 P3 — 가로 fullscreen 우측 vertical menu.
            rightMenuStackView.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -Metric.sideInset),
            rightMenuStackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            rightMenuStackView.widthAnchor.constraint(equalToConstant: Metric.leftMenuWidth),

            // spec-063 P7 — bottomBarView 는 progress 전용 layout.
            bottomBarView.leadingAnchor.constraint(equalTo: leadingAnchor),
            bottomBarView.trailingAnchor.constraint(equalTo: trailingAnchor),
            bottomBarView.bottomAnchor.constraint(equalTo: bottomAnchor),
            bottomBarView.heightAnchor.constraint(equalToConstant: Metric.bottomBarHeight),

            // spec-063 P7 — center 컨트롤 container. bottomBar 위 영상 영역 floating.
            // height = iconButtonSize, top 은 topBar 보다 아래 + bottomBar 위 영상 영역 vertical 중앙.
            centerControlsContainerView.heightAnchor.constraint(equalToConstant: Metric.iconButtonSize),
            centerControlsContainerView.topAnchor.constraint(greaterThanOrEqualTo: topBarView.bottomAnchor, constant: 8),
            centerControlsContainerView.bottomAnchor.constraint(lessThanOrEqualTo: bottomBarView.topAnchor, constant: -8),
            centerControlsContainerView.centerYAnchor.constraint(equalTo: centerYAnchor),

            backwardButton.leadingAnchor.constraint(equalTo: centerControlsContainerView.leadingAnchor),
            backwardButton.centerYAnchor.constraint(equalTo: centerControlsContainerView.centerYAnchor),
            backwardButton.widthAnchor.constraint(equalToConstant: Metric.iconButtonSize),
            backwardButton.heightAnchor.constraint(equalToConstant: Metric.iconButtonSize),

            playPauseButton.leadingAnchor.constraint(equalTo: backwardButton.trailingAnchor, constant: Metric.centerControlSpacing),
            playPauseButton.centerYAnchor.constraint(equalTo: centerControlsContainerView.centerYAnchor),
            playPauseButton.widthAnchor.constraint(equalToConstant: Metric.iconButtonSize),
            playPauseButton.heightAnchor.constraint(equalToConstant: Metric.iconButtonSize),

            forwardButton.leadingAnchor.constraint(equalTo: playPauseButton.trailingAnchor, constant: Metric.centerControlSpacing),
            forwardButton.trailingAnchor.constraint(equalTo: centerControlsContainerView.trailingAnchor),
            forwardButton.centerYAnchor.constraint(equalTo: centerControlsContainerView.centerYAnchor),
            forwardButton.widthAnchor.constraint(equalToConstant: Metric.iconButtonSize),
            forwardButton.heightAnchor.constraint(equalToConstant: Metric.iconButtonSize),

            // spec-062 C6 — "10" 텍스트 overlay (dev MGPlayerSkinView.m:1250-1265 parity).
            backwardIntervalLabel.centerXAnchor.constraint(equalTo: backwardButton.centerXAnchor),
            backwardIntervalLabel.centerYAnchor.constraint(equalTo: backwardButton.centerYAnchor),
            forwardIntervalLabel.centerXAnchor.constraint(equalTo: forwardButton.centerXAnchor),
            forwardIntervalLabel.centerYAnchor.constraint(equalTo: forwardButton.centerYAnchor),

            // spec-063 P7 — rate button: 영상 우측 끝 floating (centerControls 와 같은 centerY).
            rateButton.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -Metric.sideInset),
            rateButton.centerYAnchor.constraint(equalTo: centerControlsContainerView.centerYAnchor),
            rateButton.widthAnchor.constraint(equalToConstant: Metric.floatingRateButtonSize),
            rateButton.heightAnchor.constraint(equalToConstant: Metric.floatingRateButtonSize),

            // spec-063 P10-C/F — bottomBar progress layout 재배치 (dev parity):
            //   상단 row: progressSlider | screenModeButton (우측 끝)
            //   하단 row: currentTimeLabel (slider 좌측 정렬) ↔ durationLabel (slider 우측 정렬)
            progressSlider.leadingAnchor.constraint(equalTo: bottomBarView.safeAreaLayoutGuide.leadingAnchor, constant: Metric.sideInset + 4),
            progressSlider.topAnchor.constraint(equalTo: bottomBarView.topAnchor, constant: Metric.progressTopInset),
            progressSlider.heightAnchor.constraint(equalToConstant: Metric.progressSliderHeight),

            screenModeButton.leadingAnchor.constraint(equalTo: progressSlider.trailingAnchor, constant: 8),
            screenModeButton.trailingAnchor.constraint(equalTo: bottomBarView.safeAreaLayoutGuide.trailingAnchor, constant: -Metric.sideInset),
            // dev `MGPlayerSkinView.m:1232` — screenModeButton.bottom = totalPlaybackTimeLabel.bottom.
            screenModeButton.bottomAnchor.constraint(equalTo: durationLabel.bottomAnchor),
            screenModePreferredWidth,
            screenModeButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 0),
            screenModeButton.heightAnchor.constraint(equalToConstant: Metric.iconButtonSize),

            // 시간 label 은 progress slider 아래쪽 좌/우 (dev `MGPlayerSkinView` parity).
            currentTimeLabel.leadingAnchor.constraint(equalTo: progressSlider.leadingAnchor),
            currentTimeLabel.topAnchor.constraint(equalTo: progressSlider.bottomAnchor, constant: Metric.timeTopInset),
            currentTimePreferredWidth,
            currentTimeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 24),

            durationLabel.trailingAnchor.constraint(equalTo: progressSlider.trailingAnchor),
            durationLabel.topAnchor.constraint(equalTo: progressSlider.bottomAnchor, constant: Metric.timeTopInset),
            durationPreferredWidth,
            durationLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 24)
        ])

        // spec-063 P4 + P7 — centerControlsContainerView 자체의 leading/centerX 토글.
        // verticalSplit/horizontalSplit: leading (영상 좌측 inset 정렬).
        // fullScreen: centerX (영상 중앙 정렬).
        let leading = centerControlsContainerView.leadingAnchor.constraint(
            equalTo: safeAreaLayoutGuide.leadingAnchor,
            constant: Metric.sideInset
        )
        let centerX = centerControlsContainerView.centerXAnchor.constraint(equalTo: centerXAnchor)
        leading.isActive = true
        centerX.isActive = false
        centerControlsLeadingConstraint = leading
        centerControlsCenterXConstraint = centerX
    }

    func configureActions() {
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        displayScalingButton.addTarget(self, action: #selector(displayScalingButtonTapped), for: .touchUpInside)
        playPauseButton.addTarget(self, action: #selector(playPauseButtonTapped), for: .touchUpInside)
        backwardButton.addTarget(self, action: #selector(backwardButtonTapped), for: .touchUpInside)
        forwardButton.addTarget(self, action: #selector(forwardButtonTapped), for: .touchUpInside)
        screenModeButton.addTarget(self, action: #selector(screenModeButtonTapped), for: .touchUpInside)
        rateButton.addTarget(self, action: #selector(rateButtonTapped), for: .touchUpInside)
        settingMenuButton.addTarget(self, action: #selector(settingMenuButtonTapped), for: .touchUpInside)
        // spec-062 C5 — top bar lock/more 버튼 액션 emit.
        lockButton.addTarget(self, action: #selector(lockButtonTapped), for: .touchUpInside)
        moreButton.addTarget(self, action: #selector(moreButtonTapped), for: .touchUpInside)
        // spec-063 P2 — sectionRepeat 버튼 tap → 기존 `.sectionRepeatToggleRequested` 액션 재사용.
        sectionRepeatButton.addTarget(self, action: #selector(sectionRepeatButtonTapped), for: .touchUpInside)
        // spec-063 P3 — 우측 rate up/down 버튼.
        rateUpButton.addTarget(self, action: #selector(rateUpButtonTapped), for: .touchUpInside)
        rateDownButton.addTarget(self, action: #selector(rateDownButtonTapped), for: .touchUpInside)
        progressSlider.addTarget(self, action: #selector(progressSliderTouchBegan), for: .touchDown)
        progressSlider.addTarget(self, action: #selector(progressSliderValueChanged), for: .valueChanged)
        progressSlider.addTarget(self, action: #selector(progressSliderTouchEnded), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }

    func updateRateMenu(maxPlaybackRate: Double) {
        // parity I1 — Reactor `rateOptions(maxRate:)` 와 동일 candidates (0.5~4.0).
        rateOptions = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.25, 2.5, 2.75, 3.0, 3.5, 4.0]
            .filter { $0 <= maxPlaybackRate }

        if rateOptions.isEmpty {
            rateOptions = [1.0]
        }
    }

    @objc func closeButtonTapped() {
        onAction?(.closeRequested)
    }

    @objc func displayScalingButtonTapped() {
        onAction?(.toggleDisplayScaling)
    }

    @objc func playPauseButtonTapped() {
        onAction?(.togglePlayPause)
    }

    @objc func backwardButtonTapped() {
        onAction?(.skipBackward)
    }

    @objc func forwardButtonTapped() {
        onAction?(.skipForward)
    }

    @objc func screenModeButtonTapped() {
        onAction?(.toggleScreenMode)
    }

    /// spec-062 Phase D4 — dev `MGPlayerSkinView didSelectPlaybackRateCenter` parity.
    /// 이전: rateOptions 배열의 다음 값으로 즉시 cycle (라벨 tap = 다음 배속).
    /// 현재: `.ratePanelRequested` emit → Shell 이 `PlayerPlaybackRatePanelViewController` 표시.
    @objc func rateButtonTapped() {
        onAction?(.ratePanelRequested)
    }

    @objc func settingMenuButtonTapped() {
        onAction?(.settingRequested)
    }

    /// spec-064 Phase 1 — host 주입 추가 버튼 tap. sender 로 id 를 역조회해 `.extraControlTapped` emit.
    /// (iOS 12 타깃이라 UIAction 미사용 → sender 매칭 방식.)
    @objc func extraControlButtonTapped(_ sender: UIButton) {
        let entry = leftMenuExtraButtons.first { $0.button === sender }
            ?? floatingExtraButtons.first { $0.button === sender }
        guard let entry else { return }
        onAction?(.extraControlTapped(id: entry.id))
    }

    /// spec-062 C5 — dev `MGPlayerSkinView.m:690-694` `didSelectHold` parity.
    @objc func lockButtonTapped() {
        onAction?(.holdToggleRequested)
    }

    /// spec-062 C5 — dev `MGPlayerSkinView.m:707-711` `didSelectMore:` parity.
    @objc func moreButtonTapped() {
        onAction?(.moreRequested)
    }

    /// spec-063 P2 — dev `MGPlayerSkinView.h:368` `sectionRepeatButton` parity.
    /// 기존 actionSheet 의 "구간 반복" 진입과 동일 mutation (`sectionRepeatAdvance`) 경로.
    @objc func sectionRepeatButtonTapped() {
        onAction?(.sectionRepeatToggleRequested)
    }

    /// spec-063 P3 — dev 가로 우측 메뉴 ^/v 버튼 parity.
    @objc func rateUpButtonTapped() {
        onAction?(.rateStepUp)
    }

    @objc func rateDownButtonTapped() {
        onAction?(.rateStepDown)
    }

    @objc func progressSliderTouchBegan() {
        isSeeking = true
    }

    @objc func progressSliderValueChanged() {
        let previewTime = PlayerSkinState.previewTime(
            for: progressSlider.value,
            duration: latestState.duration
        )
        currentTimeLabel.text = PlayerSkinState.formatTime(previewTime)
        onAction?(.seekPreviewChanged(previewTime))
    }

    @objc func progressSliderTouchEnded() {
        let targetTime = PlayerSkinState.previewTime(
            for: progressSlider.value,
            duration: latestState.duration
        )
        isSeeking = false
        onAction?(.seekEnded(targetTime))
    }

    func setPlayPauseButton(isPlaying: Bool) {
        let imageName = isPlaying ? "PlayerPauseNormal" : "PlayerPlayNormal"
        let fallbackTitle = isPlaying ? "II" : "Play"
        setButtonImageOrTitle(playPauseButton, imageName: imageName, fallbackTitle: fallbackTitle)
    }

    func setDisplayScalingButton(isDisplayScaled: Bool) {
        let imageName = isDisplayScaled ? "PlayerScreenScalingAspectFillNormal" : "PlayerScreenScalingAspectFitNormal"
        let fallbackTitle = isDisplayScaled ? "Fit" : "Fill"
        setButtonImageOrTitle(displayScalingButton, imageName: imageName, fallbackTitle: fallbackTitle)
        displayScalingButton.accessibilityLabel = isDisplayScaled ? "화면 맞춤" : "화면 채움"
    }

    /// spec-062 C5 — dev `MGPlayerSkinView.m:676-688` parity:
    /// - normal state (unlocked) → asset `PlayerUnlockNormal` (`자물쇠 열림` 아이콘)
    /// - selected state (locked) → asset `PlayerLockNormal` (`자물쇠 닫힘` 아이콘)
    /// dev 는 `setImage:forState:` + `selected` 토글, 신은 image 직접 교체.
    func setLockButton(isLocked: Bool) {
        let imageName = isLocked ? "PlayerLockNormal" : "PlayerUnlockNormal"
        let fallbackTitle = isLocked ? "Lock" : "Unlock"
        setButtonImageOrTitle(lockButton, imageName: imageName, fallbackTitle: fallbackTitle)
        lockButton.accessibilityLabel = isLocked ? "화면 잠금 해제" : "화면 잠금"
    }

    func setScreenModeButton(isFullScreenMode: Bool) {
        // spec-063 P14 — asset 매핑 swap. visual 검증 결과:
        //   `PlayerScreenLandscapeNormal` = ✚ 모양 (4-corner inward, 축소)
        //   `PlayerScreenPortraitNormal` = ⛌ 모양 (4-corner outward, 확대)
        // verticalSplit (현재 세로) → 가로로 가는 trigger = 확대 ⛌ = PortraitNormal
        // fullScreen (현재 가로) → 세로로 돌아가는 trigger = 축소 ✚ = LandscapeNormal
        let imageName = isFullScreenMode ? "PlayerScreenLandscapeNormal" : "PlayerScreenPortraitNormal"
        let fallbackTitle = isFullScreenMode ? "P" : "L"
        setButtonImageOrTitle(screenModeButton, imageName: imageName, fallbackTitle: fallbackTitle)
        screenModeButton.accessibilityLabel = isFullScreenMode ? "세로 모드" : "가로 모드"
    }

    /// spec-063 P2 — sectionRepeat state 별 asset 매핑. dev `MGPlayerSkinView` 의 3-state asset 1:1.
    /// asset 미존재 시 fallback 텍스트("AB" / "AB●") 사용.
    func setSectionRepeatButton(state: PlayerSkinState.SectionRepeatState) {
        // dev `MGPlayerSkinView` sectionRepeat 3-state asset 매핑.
        // 신 Asset Catalog: idle/started = `PlayerRepeatNormal`, looping = `PlayerRepeatSelected`.
        let imageName: String
        let fallbackTitle: String
        switch state {
        case .idle:
            imageName = "PlayerRepeatNormal"
            fallbackTitle = "AB"
        case .started:
            imageName = "PlayerRepeatNormal"
            fallbackTitle = "AB"
        case .looping:
            imageName = "PlayerRepeatSelected"
            fallbackTitle = "AB●"
        }
        setButtonImageOrTitle(sectionRepeatButton, imageName: imageName, fallbackTitle: fallbackTitle)
    }

    /// spec-063 P1 — `PlayerSkinLayoutMode` 별 chrome 분기.
    /// - verticalSplit (iPhone portrait): title / leftMenu / displayScaling hidden. screenMode 노출 (= 가로 toggle).
    ///   center 컨트롤 좌측 정렬 (dev `MGPlayerSkinView` 세로 동등).
    /// - horizontalSplit (iPad landscape split): title / leftMenu 노출. displayScaling 노출. center 좌측 정렬.
    /// - fullScreen (phone landscape / iPad fullscreen toggle): 모든 chrome 노출. center centerX 정렬.
    /// dev `MGPlayerSkinView` 의 `updateControlWithIsFullScreenMode:` (`MGPlayerSkinView.m:641`) 등가.
    func applyLayoutMode(_ mode: PlayerSkinLayoutMode) {
        switch mode {
        case .verticalSplit:
            titleLabel.isHidden = true
            leftMenuStackView.isHidden = true
            rightMenuStackView.isHidden = true
            displayScalingButton.isHidden = true
            // spec-063 P10-E — 레거시 세로도 center 중앙 정렬 (dev `MGPlayerSkinView` 세로 visual 동등).
            setCenterAlignment(.center)
            applyLeftMenuFullScreenLayout(false)
        case .horizontalSplit:
            titleLabel.isHidden = false
            leftMenuStackView.isHidden = false
            rightMenuStackView.isHidden = true  // split (iPad 부분 분할) 에선 rightMenu 부재 (dev 동등).
            displayScalingButton.isHidden = false
            setCenterAlignment(.center)
            applyLeftMenuFullScreenLayout(false)
        case .fullScreen:
            titleLabel.isHidden = false
            leftMenuStackView.isHidden = false
            rightMenuStackView.isHidden = false
            // spec-063 P9 — 가로 fullscreen 은 이미 가로 상태 → top displayScaling(=화면비율 토글) 은
            // dev `MGPlayerSkinView.m:670` 가 noop. 신은 hidden 처리해 chrome 단순화.
            displayScalingButton.isHidden = true
            setCenterAlignment(.center)
            // spec-063 P8 — 가로 fullscreen 좌측 = sectionRepeat 1개. listMenu/bookmarkMenu/settingMenu 는
            // top moreButton actionSheet 에 진입 경로 있으므로 leftMenu 에선 hidden.
            applyLeftMenuFullScreenLayout(true)
        }
    }

    /// spec-063 P8 — leftMenuStackView 의 부분 hidden.
    /// fullScreen=true 면 sectionRepeat 만 남기고 listMenu/bookmarkMenu/settingMenu hidden.
    /// false 면 전체 노출 (단 stackView 자체 isHidden 은 mode 별로 별도 분기).
    func applyLeftMenuFullScreenLayout(_ fullScreen: Bool) {
        settingMenuButton.isHidden = fullScreen
        // spec-064 Phase 1 — leftMenu host 추가 버튼(인덱스/북마크)도 fullScreen 에서 hidden (dev parity).
        // hiddenExtraControlIDs 와의 결합 최종 처리는 renderExtraControls(_:) 가 담당.
        leftMenuExtraButtons.forEach { $0.button.isHidden = fullScreen }
    }

    /// spec-064 Phase 1 — host 추가 버튼 가시성/잠금 적용.
    /// leftMenu 버튼: fullScreen 모드 OR hiddenExtraControlIDs 면 숨김.
    /// floating 버튼(다음 강의): hiddenExtraControlIDs 면 숨김 + controls 가시성 alpha.
    func renderExtraControls(_ state: PlayerSkinState) {
        let isLocked = state.isLocked
        let baseVisible = state.controlsVisible && !isLocked
        let leftMenuHiddenByMode = (state.layoutMode == .fullScreen)
        for entry in leftMenuExtraButtons {
            entry.button.isHidden = leftMenuHiddenByMode || state.hiddenExtraControlIDs.contains(entry.id)
            entry.button.isEnabled = !isLocked
        }
        for entry in floatingExtraButtons {
            entry.button.isHidden = state.hiddenExtraControlIDs.contains(entry.id)
            entry.button.alpha = baseVisible ? 1 : 0
            entry.button.isEnabled = !isLocked
        }
    }

    /// leftMenu 배치용 아이콘 버튼 (강의 인덱스/북마크).
    func makeExtraIconButton(_ control: ExtraControl) -> UIButton {
        let button = UIButton(type: .system)
        configureIconButton(button, imageName: control.iconName)
        button.isEnabled = true
        button.accessibilityLabel = control.title
        button.accessibilityIdentifier = "lecturePlayer.skin.extra.\(control.id)"
        button.addTarget(self, action: #selector(extraControlButtonTapped(_:)), for: .touchUpInside)
        return button
    }

    /// floating 배치용 타이틀 버튼 (다음 강의). 구 nextEpisodeButton styling parity.
    func makeExtraFloatingButton(_ control: ExtraControl) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(control.title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        button.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        button.layer.cornerRadius = 6
        button.layer.masksToBounds = true
        button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        button.accessibilityIdentifier = "lecturePlayer.skin.extra.\(control.id)"
        button.addTarget(self, action: #selector(extraControlButtonTapped(_:)), for: .touchUpInside)
        return button
    }

    enum CenterAlignment { case leading, center }

    /// spec-063 P4 — center 컨트롤(`backwardButton`/`playPauseButton`/`forwardButton`) 정렬 토글.
    /// `setupConstraints()` 가 두 constraint 모두 생성 후 active 만 토글.
    func setCenterAlignment(_ alignment: CenterAlignment) {
        guard let leading = centerControlsLeadingConstraint,
              let centerX = centerControlsCenterXConstraint else { return }
        switch alignment {
        case .leading:
            centerX.isActive = false
            leading.isActive = true
        case .center:
            leading.isActive = false
            centerX.isActive = true
        }
    }

    /// spec-052 Phase 4.1 — Asset Catalog 의 dev PNG (e.g. `PlayerCloseNormal`) 우선 시도,
    /// 미존재 시 SF Symbol fallback, 둘 다 실패 시 fallbackTitle text 표시.
    /// dev visual parity = Asset 사용. SF Symbol 은 simulator 또는 자산 누락 시 안전망.
    func setButtonImageOrTitle(
        _ button: UIButton,
        imageName: String,
        fallbackTitle: String
    ) {
        if let assetImage = UIImage(named: imageName) {
            button.setImage(assetImage.withRenderingMode(.alwaysTemplate), for: .normal)
            button.setTitle(nil, for: .normal)
        } else if #available(iOS 13.0, *), let systemImage = UIImage(systemName: imageName) {
            button.setImage(systemImage, for: .normal)
            button.setTitle(nil, for: .normal)
        } else {
            button.setImage(nil, for: .normal)
            button.setTitle(fallbackTitle, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        }
    }
}
