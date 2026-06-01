import UIKit

public final class CloseButtonBlock: UIView, PlayerSkinBlock {
    public var view: UIView { self }
    public var onAction: ((PlayerSkinAction) -> Void)?
    private let button = PlayerSkinIconButtonFactory.make()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        pin(button); button.accessibilityIdentifier = "lecturePlayer.skin.closeButton"
        button.addTarget(self, action: #selector(tap), for: .touchUpInside)
    }
    @available(*, unavailable) public required init?(coder: NSCoder) { fatalError() }

    public func render(_ state: PlayerSkinState, theme: PlayerSkinTheme) {
        PlayerSkinIconButtonFactory.apply(button, icon: .close, fallbackTitle: "X", theme: theme)
        // close 는 lock 중에도 사용 가능 (현 동작).
    }
    @objc private func tap() { onAction?(.closeRequested) }
    private func pin(_ subview: UIView) { addSubview(subview); NSLayoutConstraint.activate([
        subview.topAnchor.constraint(equalTo: topAnchor), subview.bottomAnchor.constraint(equalTo: bottomAnchor),
        subview.leadingAnchor.constraint(equalTo: leadingAnchor), subview.trailingAnchor.constraint(equalTo: trailingAnchor)]) }
}
