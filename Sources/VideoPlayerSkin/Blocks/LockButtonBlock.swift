import UIKit

public final class LockButtonBlock: UIView, PlayerSkinBlock {
    public var view: UIView { self }
    public var onAction: ((PlayerSkinAction) -> Void)?
    private let button = PlayerSkinIconButtonFactory.make()
    public override init(frame: CGRect) {
        super.init(frame: frame); pin(button)
        button.accessibilityIdentifier = "lecturePlayer.skin.lockButton"
        button.addTarget(self, action: #selector(tap), for: .touchUpInside)
    }
    @available(*, unavailable) public required init?(coder: NSCoder) { fatalError() }
    public func render(_ state: PlayerSkinState, theme: PlayerSkinTheme) {
        PlayerSkinIconButtonFactory.apply(button,
            icon: state.isLocked ? .lock : .unlock,
            fallbackTitle: state.isLocked ? "Lock" : "Unlock", theme: theme)
        button.accessibilityLabel = state.isLocked ? "화면 잠금 해제" : "화면 잠금"
        // lock 버튼은 lock 중에도 활성 (현 동작).
    }
    @objc private func tap() { onAction?(.holdToggleRequested) }
    private func pin(_ subview: UIView) { addSubview(subview); NSLayoutConstraint.activate([
        subview.topAnchor.constraint(equalTo: topAnchor), subview.bottomAnchor.constraint(equalTo: bottomAnchor),
        subview.leadingAnchor.constraint(equalTo: leadingAnchor), subview.trailingAnchor.constraint(equalTo: trailingAnchor)]) }
}
