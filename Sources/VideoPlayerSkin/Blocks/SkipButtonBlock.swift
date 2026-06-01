import UIKit

/// 10초 뒤로/앞으로. 버튼 위 "10" 오버레이 포함 (현 PlayerSkinControlView C6 parity).
public final class SkipButtonBlock: UIView, PlayerSkinBlock {
    public enum Direction { case backward, forward }
    public var view: UIView { self }
    public var onAction: ((PlayerSkinAction) -> Void)?

    private let direction: Direction
    private let button = PlayerSkinIconButtonFactory.make()
    private let intervalLabel = UILabel()

    public init(_ direction: Direction) {
        self.direction = direction
        super.init(frame: .zero)
        pin(button)
        intervalLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        intervalLabel.textColor = UIColor.white.withAlphaComponent(0.9)
        intervalLabel.textAlignment = .center
        intervalLabel.isUserInteractionEnabled = false
        intervalLabel.text = "10"
        intervalLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(intervalLabel)
        NSLayoutConstraint.activate([
            intervalLabel.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            intervalLabel.centerYAnchor.constraint(equalTo: button.centerYAnchor)
        ])
        button.addTarget(self, action: #selector(tap), for: .touchUpInside)
    }
    @available(*, unavailable) public required init?(coder: NSCoder) { fatalError() }

    public func setInterval(seconds: Int) { intervalLabel.text = "\(seconds)" }

    public func render(_ state: PlayerSkinState, theme: PlayerSkinTheme) {
        intervalLabel.font = theme.font(.skipInterval)
        intervalLabel.textColor = theme.color(.controlTint).withAlphaComponent(0.9)
        let icon: PlayerSkinIcon = direction == .backward ? .skipBackward : .skipForward
        PlayerSkinIconButtonFactory.apply(
            button,
            icon: icon,
            fallbackTitle: direction == .backward ? "-10" : "+10",
            theme: theme
        )
        button.isEnabled = !state.isLocked
    }
    @objc private func tap() { onAction?(direction == .backward ? .skipBackward : .skipForward) }
    private func pin(_ subview: UIView) {
        addSubview(subview)
        NSLayoutConstraint.activate([
            subview.topAnchor.constraint(equalTo: topAnchor),
            subview.bottomAnchor.constraint(equalTo: bottomAnchor),
            subview.leadingAnchor.constraint(equalTo: leadingAnchor),
            subview.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }
}
