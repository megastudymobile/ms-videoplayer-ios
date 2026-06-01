import UIKit

/// 가로 fullscreen 우측 메뉴 ^/v (배속 step).
public final class RateStepBlock: UIView, PlayerSkinBlock {
    public enum Step { case up, down }
    public var view: UIView { self }
    public var onAction: ((PlayerSkinAction) -> Void)?
    public var theme: PlayerSkinTheme = .default
    private let step: Step
    private let button = PlayerSkinIconButtonFactory.make()
    public init(_ step: Step) {
        self.step = step; super.init(frame: .zero); pin(button)
        button.accessibilityLabel = step == .up ? "배속 빠르게" : "배속 느리게"
        button.addTarget(self, action: #selector(tap), for: .touchUpInside)
    }
    @available(*, unavailable) public required init?(coder: NSCoder) { fatalError() }
    public func render(_ state: PlayerSkinState) {
        let icon: PlayerSkinIcon = step == .up ? .rateUp : .rateDown
        PlayerSkinIconButtonFactory.apply(button, icon: icon, fallbackTitle: step == .up ? "^" : "v", theme: theme)
        button.isEnabled = !state.isLocked
    }
    @objc private func tap() { onAction?(step == .up ? .rateStepUp : .rateStepDown) }
    private func pin(_ subview: UIView) { addSubview(subview); NSLayoutConstraint.activate([
        subview.topAnchor.constraint(equalTo: topAnchor), subview.bottomAnchor.constraint(equalTo: bottomAnchor),
        subview.leadingAnchor.constraint(equalTo: leadingAnchor), subview.trailingAnchor.constraint(equalTo: trailingAnchor)]) }
}
