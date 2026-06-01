import UIKit

/// leftRail 의 host 주입 추가버튼들(placement .leftMenu): 강의 인덱스/북마크 등.
/// fullScreen 에선 숨김(현 parity). hiddenExtraControlIDs 로 개별 숨김.
public final class ExtraControlsRailBlock: UIView, PlayerSkinBlock {
    public var view: UIView { self }
    public var onAction: ((PlayerSkinAction) -> Void)?

    private let stack = UIStackView()
    private var buttons: [(id: String, button: UIButton)] = []
    private var theme: PlayerSkinTheme = DefaultPlayerSkinTheme()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        stack.axis = .vertical; stack.alignment = .center; stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor), stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor), stack.trailingAnchor.constraint(equalTo: trailingAnchor)])
    }
    @available(*, unavailable) public required init?(coder: NSCoder) { fatalError() }

    /// host 주입 ExtraControl 중 placement == .leftMenu 만 buttons 로 구성.
    public func setExtraControls(_ controls: [ExtraControl], theme: PlayerSkinTheme) {
        self.theme = theme
        buttons.forEach { $0.button.removeFromSuperview() }; buttons.removeAll()
        for control in controls where control.placement == .leftMenu {
            let button = PlayerSkinIconButtonFactory.make()
            PlayerSkinIconButtonFactory.apply(button, assetName: control.iconName, fallbackTitle: control.title, theme: theme)
            button.accessibilityLabel = control.title
            button.accessibilityIdentifier = "lecturePlayer.skin.extra.\(control.id)"
            button.addTarget(self, action: #selector(tap(_:)), for: .touchUpInside)
            stack.addArrangedSubview(button)
            buttons.append((control.id, button))
        }
    }

    public func render(_ state: PlayerSkinState, theme: PlayerSkinTheme) {
        isHidden = (state.layoutMode == .fullScreen)
        for entry in buttons {
            entry.button.isHidden = state.hiddenExtraControlIDs.contains(entry.id)
            entry.button.isEnabled = !state.isLocked
        }
    }

    @objc private func tap(_ sender: UIButton) {
        guard let entry = buttons.first(where: { $0.button === sender }) else { return }
        onAction?(.extraControlTapped(id: entry.id))
    }
}
