import UIKit

/// bottomBar 복합 블럭: 진행 슬라이더 + 현재/총 시간 + 화면모드 버튼.
///
/// **의도적 composite (trade-off):** bottomBar 는 슬라이더 아래 시간 라벨이 놓이는 2D 레이아웃이라
/// stack 기반 슬롯으로 분해 불가 → 4개를 한 블럭에 묶었다. 결과로 host 가 "진행바만" 교체하는
/// Tier2 시나리오는 이 슬롯에서 불가능하고, 통째 교체(이 블럭 대체)만 가능하다.
/// 진행바 단독 교체 수요가 생기면 bottomBar 를 전용 2D 컨테이너 슬롯으로 재설계해야 한다.
public final class ProgressBarBlock: UIView, PlayerSkinBlock {
    public var view: UIView { self }
    public var onAction: ((PlayerSkinAction) -> Void)?

    private let slider = PlayerPlaybackSlider()
    private let currentTimeLabel = UILabel()
    private let durationLabel = UILabel()
    private let screenModeButton = PlayerSkinIconButtonFactory.make()
    private var isSeeking = false
    private var latestDuration: TimeInterval = 0
    private var sliderTopConstraint: NSLayoutConstraint?
    /// 라이브 프리뷰 seek throttle. 드래그는 ~120Hz로 valueChanged를 쏘는데, 매 틱 실제 엔진 seek을
    /// 호출하면(메인스레드 디코드) thumb 추적/애니메이션과 경쟁해 버벅인다. thumb/시간 라벨은 매 틱
    /// 갱신하되, 엔진 seek 유발(onAction)은 이 간격으로 제한한다. 최종 위치는 touchUp의 seekEnded가 보장.
    private var lastPreviewEmit: CFTimeInterval = 0
    private static let previewThrottleInterval: CFTimeInterval = 0.12

    public override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }
    @available(*, unavailable) public required init?(coder: NSCoder) { fatalError() }

    public func render(_ state: PlayerSkinState, theme: PlayerSkinTheme) {
        slider.minimumTrackTintColor = theme.color(.progressFill)
        slider.maximumTrackTintColor = theme.color(.progressTrack)
        if let thumb = theme.icon(.sliderThumb) {
            slider.setThumbImage(thumb, for: .normal)
        }
        currentTimeLabel.textColor = theme.color(.timeText); currentTimeLabel.font = theme.font(.time)
        durationLabel.textColor = theme.color(.timeText); durationLabel.font = theme.font(.time)
        latestDuration = state.duration

        if !isSeeking {
            slider.value = state.progress
            currentTimeLabel.text = PlayerSkinState.formatTime(state.currentTime)
        }
        durationLabel.text = PlayerSkinState.formatTime(state.duration)
        sliderTopConstraint?.constant = state.layoutMode == .fullScreen ? 4 : 12

        let isFull = state.isFullScreenMode
        PlayerSkinIconButtonFactory.apply(screenModeButton,
            icon: isFull ? .screenShrink : .screenExpand,
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
        let sliderTop = slider.topAnchor.constraint(equalTo: topAnchor, constant: 12)
        sliderTopConstraint = sliderTop
        NSLayoutConstraint.activate([
            slider.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 24),
            sliderTop,
            slider.heightAnchor.constraint(equalToConstant: 21),

            screenModeButton.leadingAnchor.constraint(equalTo: slider.trailingAnchor, constant: 8),
            screenModeButton.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -20),
            screenModeButton.bottomAnchor.constraint(equalTo: durationLabel.bottomAnchor, constant: 6),

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

    @objc private func seekBegan() {
        isSeeking = true
        // 드래그 시작 순간엔 첫 프리뷰 seek을 한 interval 미룬다 — touch-down의 pause(Kollus 메인)와
        // 첫 엔진 seek이 겹쳐 시작이 버벅이던 문제 방지. 0으로 리셋하면 첫 seekChanged가 즉시 seek한다.
        lastPreviewEmit = CACurrentMediaTime()
        // 스크러버를 잡는 순간 host 가 재생을 멈춘다(pause).
        onAction?(.seekBegan)
    }
    @objc private func seekChanged() {
        let time = PlayerSkinState.previewTime(for: slider.value, duration: latestDuration)
        // thumb은 UISlider가 네이티브로 추적하고, 시간 라벨은 매 틱 갱신(가벼움).
        currentTimeLabel.text = PlayerSkinState.formatTime(time)
        // 실제 엔진 seek을 유발하는 프리뷰는 throttle — 메인스레드 디코드가 thumb 애니메이션을 막지 않게.
        let now = CACurrentMediaTime()
        guard now - lastPreviewEmit >= Self.previewThrottleInterval else { return }
        lastPreviewEmit = now
        onAction?(.seekPreviewChanged(time))
    }
    @objc private func seekEnded() {
        let time = PlayerSkinState.previewTime(for: slider.value, duration: latestDuration)
        isSeeking = false
        // 릴리스 시 최종 위치는 throttle과 무관하게 항상 정확히 반영.
        onAction?(.seekEnded(time))
    }
    @objc private func screenModeTap() { onAction?(.toggleScreenMode) }
}
