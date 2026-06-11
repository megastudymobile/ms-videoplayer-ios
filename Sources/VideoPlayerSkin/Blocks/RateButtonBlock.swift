import UIKit

/// 영상 우측 floating 회색 원형 배속 버튼.
public final class RateButtonBlock: UIView, PlayerSkinBlock {
    private enum Metric {
        static let inactiveBackgroundAlpha: CGFloat = 0.24
    }

    public var view: UIView { self }
    public var onAction: ((PlayerSkinAction) -> Void)?
    private let button = UIButton(type: .system)
    private var widthConstraint: NSLayoutConstraint?
    private var heightConstraint: NSLayoutConstraint?
    public override init(frame: CGRect) {
        super.init(frame: frame)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitleColor(UIColor(named: "White-03", in: .module, compatibleWith: nil) ?? .white, for: .normal)
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.7
        button.layer.masksToBounds = true
        button.accessibilityIdentifier = "videoPlayer.skin.rateButton"
        addSubview(button)
        let width = button.widthAnchor.constraint(equalToConstant: 36)
        let height = button.heightAnchor.constraint(equalToConstant: 36)
        widthConstraint = width
        heightConstraint = height
        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: topAnchor),
            button.bottomAnchor.constraint(equalTo: bottomAnchor),
            button.leadingAnchor.constraint(equalTo: leadingAnchor),
            button.trailingAnchor.constraint(equalTo: trailingAnchor),
            width,
            height
        ])
        button.addTarget(self, action: #selector(tap), for: .touchUpInside)
    }
    @available(*, unavailable) public required init?(coder: NSCoder) { fatalError() }
    public func render(_ state: PlayerSkinState, theme: PlayerSkinTheme) {
        let size: CGFloat = traitCollection.userInterfaceIdiom == .pad ? 40 : 34
        widthConstraint?.constant = size
        heightConstraint?.constant = size
        button.layer.cornerRadius = size * 0.5
        button.backgroundColor = state.isRatePanelPresented
            ? theme.color(.progressFill)
            : UIColor.white.withAlphaComponent(Metric.inactiveBackgroundAlpha)
        button.titleLabel?.font = theme.font(.rateLabel)
        button.setTitle(String(format: "%.1fx", state.playbackRate), for: .normal)
        button.isEnabled = !state.isLocked
    }
    @objc private func tap() { onAction?(.ratePanelRequested) }
}
