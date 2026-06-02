import UIKit

/// legacy `SLPlayerRateControlView` parity.
///
/// 중앙 배속 버튼과 상/하 step 버튼을 하나의 복합 뷰에서 배치해
/// 세 버튼의 수직축과 간격을 고정한다.
public final class RateControlBlock: UIView, PlayerSkinBlock {
    private enum Metric {
        static let phoneCenterSize: CGFloat = 34
        static let padCenterSize: CGFloat = 40
        static let stepHeight: CGFloat = 24
        static let stepGap: CGFloat = 16
        static let inactiveBackgroundAlpha: CGFloat = 0.24
    }

    public var view: UIView { self }
    public var onAction: ((PlayerSkinAction) -> Void)?

    private let upButton = UIButton(type: .custom)
    private let centerButton = UIButton(type: .system)
    private let downButton = UIButton(type: .custom)
    private var centerWidthConstraint: NSLayoutConstraint?

    public override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func render(_ state: PlayerSkinState, theme: PlayerSkinTheme) {
        let centerSize: CGFloat = traitCollection.userInterfaceIdiom == .pad ? Metric.padCenterSize : Metric.phoneCenterSize
        centerWidthConstraint?.constant = centerSize
        centerButton.layer.cornerRadius = centerSize * 0.5
        centerButton.backgroundColor = state.isRatePanelPresented
            ? theme.color(.progressFill)
            : UIColor.white.withAlphaComponent(Metric.inactiveBackgroundAlpha)
        centerButton.titleLabel?.font = theme.font(.rateLabel)
        centerButton.setTitleColor(UIColor(named: "White-03", in: .module, compatibleWith: nil) ?? .white, for: .normal)
        centerButton.setTitle(String(format: "%.1fx", state.playbackRate), for: .normal)

        upButton.setImage(theme.image(assetName: "PlayerControlRateUp")?.withRenderingMode(.alwaysOriginal), for: .normal)
        downButton.setImage(theme.image(assetName: "PlayerControlRateDown")?.withRenderingMode(.alwaysOriginal), for: .normal)

        let showsStepButtons = !state.isLocked && state.layoutMode == .fullScreen
        upButton.isHidden = !showsStepButtons
        downButton.isHidden = !showsStepButtons
        upButton.isEnabled = showsStepButtons
        downButton.isEnabled = showsStepButtons
        centerButton.isEnabled = !state.isLocked
    }

    private func configure() {
        backgroundColor = .clear
        centerButton.layer.masksToBounds = true
        centerButton.titleLabel?.adjustsFontSizeToFitWidth = true
        centerButton.titleLabel?.minimumScaleFactor = 0.7
        centerButton.accessibilityIdentifier = "lecturePlayer.skin.rateButton"
        upButton.accessibilityLabel = "배속 빠르게"
        downButton.accessibilityLabel = "배속 느리게"

        [upButton, centerButton, downButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }

        let centerWidth = centerButton.widthAnchor.constraint(equalToConstant: Metric.phoneCenterSize)
        centerWidthConstraint = centerWidth

        NSLayoutConstraint.activate([
            upButton.leadingAnchor.constraint(equalTo: leadingAnchor),
            upButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            upButton.topAnchor.constraint(equalTo: topAnchor),
            upButton.bottomAnchor.constraint(equalTo: centerButton.topAnchor, constant: -Metric.stepGap),
            upButton.heightAnchor.constraint(equalToConstant: Metric.stepHeight),

            centerButton.leadingAnchor.constraint(equalTo: leadingAnchor),
            centerButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            centerButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            centerWidth,
            centerButton.heightAnchor.constraint(equalTo: centerButton.widthAnchor),

            downButton.leadingAnchor.constraint(equalTo: leadingAnchor),
            downButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            downButton.topAnchor.constraint(equalTo: centerButton.bottomAnchor, constant: Metric.stepGap),
            downButton.bottomAnchor.constraint(equalTo: bottomAnchor),
            downButton.heightAnchor.constraint(equalToConstant: Metric.stepHeight)
        ])

        centerButton.addTarget(self, action: #selector(centerTap), for: .touchUpInside)
        upButton.addTarget(self, action: #selector(upTap), for: .touchUpInside)
        downButton.addTarget(self, action: #selector(downTap), for: .touchUpInside)
    }

    @objc private func centerTap() { onAction?(.ratePanelRequested) }
    @objc private func upTap() { onAction?(.rateStepUp) }
    @objc private func downTap() { onAction?(.rateStepDown) }
}
