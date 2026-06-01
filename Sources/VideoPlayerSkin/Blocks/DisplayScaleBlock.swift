import UIKit

public final class DisplayScaleBlock: UIView, PlayerSkinBlock {
    public var view: UIView { self }
    public var onAction: ((PlayerSkinAction) -> Void)?
    private let button = PlayerSkinIconButtonFactory.make()
    public override init(frame: CGRect) {
        super.init(frame: frame); pin(button)
        button.accessibilityIdentifier = "lecturePlayer.skin.displayScalingButton"
        button.addTarget(self, action: #selector(tap), for: .touchUpInside)
    }
    @available(*, unavailable) public required init?(coder: NSCoder) { fatalError() }
    public func render(_ state: PlayerSkinState, theme: PlayerSkinTheme) {
        PlayerSkinIconButtonFactory.apply(button,
            icon: state.isDisplayScaled ? .displayScaleFill : .displayScaleFit,
            fallbackTitle: state.isDisplayScaled ? "Fit" : "Fill", theme: theme)
        button.accessibilityLabel = state.isDisplayScaled ? "화면 맞춤" : "화면 채움"
        button.isEnabled = !state.isLocked
        // 가로 fullscreen 에선 displayScaling 숨김 (현 동작).
        isHidden = (state.layoutMode == .fullScreen) || (state.layoutMode == .verticalSplit)
    }
    @objc private func tap() { onAction?(.toggleDisplayScaling) }
    private func pin(_ subview: UIView) { addSubview(subview); NSLayoutConstraint.activate([
        subview.topAnchor.constraint(equalTo: topAnchor), subview.bottomAnchor.constraint(equalTo: bottomAnchor),
        subview.leadingAnchor.constraint(equalTo: leadingAnchor), subview.trailingAnchor.constraint(equalTo: trailingAnchor)]) }
}
