import UIKit

/// bottomBar 위 floating host 추가버튼(placement .floating): 다음 강의 등. 타이틀 버튼.
public final class ExtraFloatingBlock: UIView, PlayerSkinBlock {
    public var view: UIView { self }
    public var onAction: ((PlayerSkinAction) -> Void)?
    public var theme: PlayerSkinTheme = .default

    private let stack = UIStackView()
    private var buttons: [(id: String, button: UIButton)] = []

    public override init(frame: CGRect) {
        super.init(frame: frame)
        stack.axis = .horizontal; stack.alignment = .center; stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor), stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor), stack.trailingAnchor.constraint(equalTo: trailingAnchor)])
    }
    @available(*, unavailable) public required init?(coder: NSCoder) { fatalError() }

    public func setExtraControls(_ controls: [ExtraControl]) {
        buttons.forEach { $0.button.removeFromSuperview() }; buttons.removeAll()
        for control in controls where control.placement == .floating {
            let button = UIButton(type: .system)
            button.setTitle(control.title, for: .normal)
            button.setTitleColor(.white, for: .normal)
            button.titleLabel?.font = theme.font(.extraControlTitle)
            button.backgroundColor = UIColor.black.withAlphaComponent(0.55)
            button.layer.cornerRadius = 6; button.layer.masksToBounds = true
            button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
            button.accessibilityIdentifier = "lecturePlayer.skin.extra.\(control.id)"
            button.addTarget(self, action: #selector(tap(_:)), for: .touchUpInside)
            stack.addArrangedSubview(button)
            buttons.append((control.id, button))
        }
    }

    public func render(_ state: PlayerSkinState) {
        for entry in buttons {
            entry.button.isHidden = state.hiddenExtraControlIDs.contains(entry.id)
            entry.button.isEnabled = !state.isLocked
        }
        isHidden = buttons.allSatisfy { $0.button.isHidden }
    }

    @objc private func tap(_ sender: UIButton) {
        guard let entry = buttons.first(where: { $0.button === sender }) else { return }
        onAction?(.extraControlTapped(id: entry.id))
    }
}
