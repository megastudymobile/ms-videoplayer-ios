import UIKit

/// 영상 우측 floating 회색 원형 배속 버튼 (현 PlayerSkinControlView P7 parity).
public final class RateButtonBlock: UIView, PlayerSkinBlock {
    public var view: UIView { self }
    public var onAction: ((PlayerSkinAction) -> Void)?
    private let button = UIButton(type: .system)
    public override init(frame: CGRect) {
        super.init(frame: frame)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.7
        button.backgroundColor = UIColor(white: 0.3, alpha: 0.65)
        button.layer.cornerRadius = 18
        button.layer.masksToBounds = true
        button.accessibilityIdentifier = "lecturePlayer.skin.rateButton"
        addSubview(button)
        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: topAnchor), button.bottomAnchor.constraint(equalTo: bottomAnchor),
            button.leadingAnchor.constraint(equalTo: leadingAnchor), button.trailingAnchor.constraint(equalTo: trailingAnchor),
            button.widthAnchor.constraint(equalToConstant: 36), button.heightAnchor.constraint(equalToConstant: 36)])
        button.addTarget(self, action: #selector(tap), for: .touchUpInside)
    }
    @available(*, unavailable) public required init?(coder: NSCoder) { fatalError() }
    public func render(_ state: PlayerSkinState, theme: PlayerSkinTheme) {
        button.tintColor = theme.color(.controlTint)
        button.titleLabel?.font = theme.font(.rateLabel)
        button.setTitle(String(format: "%.1fx", state.playbackRate), for: .normal)
        button.isEnabled = !state.isLocked
    }
    @objc private func tap() { onAction?(.ratePanelRequested) }
}
