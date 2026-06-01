import UIKit

public final class SettingButtonBlock: UIView, PlayerSkinBlock {
    public var view: UIView { self }
    public var onAction: ((PlayerSkinAction) -> Void)?
    private let button = PlayerSkinIconButtonFactory.make()
    public override init(frame: CGRect) {
        super.init(frame: frame); pin(button)
        button.accessibilityIdentifier = "lecturePlayer.skin.settingMenuButton"
        button.addTarget(self, action: #selector(tap), for: .touchUpInside)
    }
    @available(*, unavailable) public required init?(coder: NSCoder) { fatalError() }
    public func render(_ state: PlayerSkinState, theme: PlayerSkinTheme) {
        PlayerSkinIconButtonFactory.apply(button, icon: .more, fallbackTitle: "Set", theme: theme)
        button.isEnabled = !state.isLocked
        isHidden = (state.layoutMode == .fullScreen)
    }
    @objc private func tap() { onAction?(.settingRequested) }
    private func pin(_ subview: UIView) { addSubview(subview); NSLayoutConstraint.activate([
        subview.topAnchor.constraint(equalTo: topAnchor), subview.bottomAnchor.constraint(equalTo: bottomAnchor),
        subview.leadingAnchor.constraint(equalTo: leadingAnchor), subview.trailingAnchor.constraint(equalTo: trailingAnchor)]) }
}
