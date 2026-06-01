import UIKit

/// bottomBar 복합 블럭: 진행 슬라이더 + 현재/총 시간 + 화면모드 버튼.
/// 현 PlayerSkinControlView bottomBar 2D 레이아웃 parity.
public final class ProgressBarBlock: UIView, PlayerSkinBlock {
    public var view: UIView { self }
    public var onAction: ((PlayerSkinAction) -> Void)?

    private let slider = PlayerPlaybackSlider()
    private let currentTimeLabel = UILabel()
    private let durationLabel = UILabel()
    private let screenModeButton = PlayerSkinIconButtonFactory.make()
    private var isSeeking = false
    private var latestDuration: TimeInterval = 0

    public override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }
    @available(*, unavailable) public required init?(coder: NSCoder) { fatalError() }

    public func render(_ state: PlayerSkinState, theme: PlayerSkinTheme) {
        latestDuration = state.duration
        slider.minimumTrackTintColor = theme.color(.progressFill)
        slider.maximumTrackTintColor = theme.color(.progressTrack)
        if let thumb = theme.image(assetName: "PlayerPlaybackSliderCircleNormal") {
            slider.setThumbImage(thumb, for: .normal)
        }
        currentTimeLabel.textColor = theme.color(.timeText); currentTimeLabel.font = theme.font(.time)
        durationLabel.textColor = theme.color(.timeText); durationLabel.font = theme.font(.time)

        if !isSeeking {
            slider.value = state.progress
            currentTimeLabel.text = PlayerSkinState.formatTime(state.currentTime)
        }
        durationLabel.text = PlayerSkinState.formatTime(state.duration)

        let isFull = (state.layoutMode == .fullScreen)
        PlayerSkinIconButtonFactory.apply(screenModeButton,
            assetName: isFull ? "PlayerScreenLandscapeNormal" : "PlayerScreenPortraitNormal",
            fallbackTitle: isFull ? "P" : "L", theme: theme)
        screenModeButton.accessibilityLabel = isFull ? "세로 모드" : "가로 모드"

        slider.isEnabled = !state.isLocked
        screenModeButton.isEnabled = !state.isLocked
    }

    private func configure() {
        slider.minimumValue = 0; slider.maximumValue = 1
        currentTimeLabel.textAlignment = .left; durationLabel.textAlignment = .right
        screenModeButton.accessibilityIdentifier = "lecturePlayer.skin.screenModeButton"
        slider.accessibilityIdentifier = "lecturePlayer.skin.progressSlider"
        [slider, currentTimeLabel, durationLabel, screenModeButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false; addSubview($0)
        }
        NSLayoutConstraint.activate([
            slider.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 24),
            slider.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            slider.heightAnchor.constraint(equalToConstant: 21),

            screenModeButton.leadingAnchor.constraint(equalTo: slider.trailingAnchor, constant: 8),
            screenModeButton.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -20),
            screenModeButton.centerYAnchor.constraint(equalTo: slider.centerYAnchor),

            currentTimeLabel.leadingAnchor.constraint(equalTo: slider.leadingAnchor),
            currentTimeLabel.topAnchor.constraint(equalTo: slider.bottomAnchor, constant: 1),
            durationLabel.trailingAnchor.constraint(equalTo: slider.trailingAnchor),
            durationLabel.topAnchor.constraint(equalTo: slider.bottomAnchor, constant: 1)
        ])
        slider.addTarget(self, action: #selector(seekBegan), for: .touchDown)
        slider.addTarget(self, action: #selector(seekChanged), for: .valueChanged)
        slider.addTarget(self, action: #selector(seekEnded), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        screenModeButton.addTarget(self, action: #selector(screenModeTap), for: .touchUpInside)
    }

    @objc private func seekBegan() { isSeeking = true }
    @objc private func seekChanged() {
        let time = PlayerSkinState.previewTime(for: slider.value, duration: latestDuration)
        currentTimeLabel.text = PlayerSkinState.formatTime(time)
        onAction?(.seekPreviewChanged(time))
    }
    @objc private func seekEnded() {
        let time = PlayerSkinState.previewTime(for: slider.value, duration: latestDuration)
        isSeeking = false
        onAction?(.seekEnded(time))
    }
    @objc private func screenModeTap() { onAction?(.toggleScreenMode) }
}
