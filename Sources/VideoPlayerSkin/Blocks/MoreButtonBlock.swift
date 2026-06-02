import UIKit

public final class MoreButtonBlock: UIView, PlayerSkinBlock {
    public var view: UIView { self }
    public var onAction: ((PlayerSkinAction) -> Void)?
    private let button = PlayerSkinIconButtonFactory.make()
    public override init(frame: CGRect) {
        super.init(frame: frame); pin(button)
        button.accessibilityIdentifier = "lecturePlayer.skin.moreButton"; button.accessibilityLabel = "더보기"
        button.addTarget(self, action: #selector(tap), for: .touchUpInside)
    }
    @available(*, unavailable) public required init?(coder: NSCoder) { fatalError() }
    public func render(_ state: PlayerSkinState, theme: PlayerSkinTheme) {
        PlayerSkinIconButtonFactory.apply(button, icon: .more, fallbackTitle: "Set", theme: theme)
        button.isEnabled = !state.isLocked
        isHidden = state.isLocked
    }
    @objc private func tap() { onAction?(.moreRequested) }
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
