import UIKit

/// bottomBar 위 floating host 추가버튼(placement .floating): 다음 강의 등. 타이틀 버튼.
public final class ExtraFloatingBlock: UIView, PlayerSkinBlock {
    public var view: UIView { self }
    public var onAction: ((PlayerSkinAction) -> Void)?

    private let stack = UIStackView()
    private var controls: [ExtraControl] = []
    private var buttons: [(id: String, button: UIButton)] = []
    private var sizeConstraints: [String: (width: NSLayoutConstraint, height: NSLayoutConstraint)] = [:]
    private var needsRebuild = true

    public override init(frame: CGRect) {
        super.init(frame: frame)
        stack.axis = .horizontal; stack.alignment = .center; stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }
    @available(*, unavailable) public required init?(coder: NSCoder) { fatalError() }

    public func setExtraControls(_ controls: [ExtraControl]) {
        self.controls = controls
        needsRebuild = true
    }

    public func render(_ state: PlayerSkinState, theme: PlayerSkinTheme) {
        rebuildButtonsIfNeeded(theme: theme)
        let size = traitCollection.userInterfaceIdiom == .pad
            ? CGSize(width: 110, height: 38)
            : CGSize(width: 85, height: 30)
        for entry in buttons {
            if let constraints = sizeConstraints[entry.id] {
                constraints.width.constant = size.width
                constraints.height.constant = size.height
            }
            entry.button.layer.cornerRadius = size.height * 0.5
            entry.button.isHidden = state.hiddenExtraControlIDs.contains(entry.id)
            entry.button.isEnabled = !state.isLocked
        }
        isHidden = buttons.allSatisfy { $0.button.isHidden }
    }

    private func rebuildButtonsIfNeeded(theme: PlayerSkinTheme) {
        guard needsRebuild else { return }
        buttons.forEach { $0.button.removeFromSuperview() }; buttons.removeAll()
        for control in controls where control.placement == .floating {
            let button = UIButton(type: .system)
            var attributedTitle = AttributedString(control.title)
            attributedTitle.font = theme.font(.extraControlTitle)

            var configuration = UIButton.Configuration.filled()
            configuration.attributedTitle = attributedTitle
            configuration.baseForegroundColor = .white
            configuration.baseBackgroundColor = UIColor.black.withAlphaComponent(0.55)
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8)
            configuration.background.cornerRadius = 15
            button.configuration = configuration
            button.layer.masksToBounds = true
            button.accessibilityIdentifier = "lecturePlayer.skin.extra.\(control.id)"
            button.addTarget(self, action: #selector(tap(_:)), for: .touchUpInside)
            stack.addArrangedSubview(button)
            let width = button.widthAnchor.constraint(equalToConstant: 85)
            let height = button.heightAnchor.constraint(equalToConstant: 30)
            NSLayoutConstraint.activate([width, height])
            sizeConstraints[control.id] = (width, height)
            buttons.append((control.id, button))
        }
        needsRebuild = false
    }

    @objc private func tap(_ sender: UIButton) {
        guard let entry = buttons.first(where: { $0.button === sender }) else { return }
        onAction?(.extraControlTapped(id: entry.id))
    }
}
