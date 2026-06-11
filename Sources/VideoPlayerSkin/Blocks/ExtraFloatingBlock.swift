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
        let usesPadMetrics = traitCollection.userInterfaceIdiom == .pad && state.layoutMode == .fullScreen
        let size = usesPadMetrics
            ? CGSize(width: 110, height: 38)
            : CGSize(width: 85, height: 30)
        for entry in buttons {
            guard let control = controls.first(where: { $0.id == entry.id }) else { continue }
            if let constraints = sizeConstraints[entry.id] {
                constraints.width.constant = size.width
                constraints.height.constant = size.height
            }
            entry.button.layer.cornerRadius = size.height * 0.5
            applyStyle(to: entry.button, control: control, usesPadMetrics: usesPadMetrics, theme: theme)
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
            button.layer.masksToBounds = true
            button.accessibilityIdentifier = "videoPlayer.skin.extra.\(control.id)"
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

    private func applyStyle(
        to button: UIButton,
        control: ExtraControl,
        usesPadMetrics: Bool,
        theme: PlayerSkinTheme
    ) {
        let fontSize: CGFloat = usesPadMetrics ? 17 : 13
        let font = UIFont(name: "AppleSDGothicNeo-Bold", size: fontSize)
            ?? .systemFont(ofSize: fontSize, weight: .bold)
        let foregroundColor = UIColor(named: "Black02", in: .module, compatibleWith: nil)
            ?? UIColor.black
        let title = NSAttributedString(
            string: control.title,
            attributes: [
                .font: font,
                .foregroundColor: foregroundColor,
                .baselineOffset: -1.0
            ]
        )
        button.setAttributedTitle(title, for: .normal)
        button.setAttributedTitle(title, for: .selected)

        guard control.iconName.isEmpty == false else {
            var configuration = UIButton.Configuration.filled()
            var attributedTitle = AttributedString(control.title)
            attributedTitle.font = theme.font(.extraControlTitle)
            configuration.attributedTitle = attributedTitle
            configuration.baseForegroundColor = .white
            configuration.baseBackgroundColor = UIColor.black.withAlphaComponent(0.55)
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8)
            configuration.background.cornerRadius = button.layer.cornerRadius
            button.configuration = configuration
            button.backgroundColor = nil
            button.setImage(nil, for: .normal)
            return
        }

        var configuration = UIButton.Configuration.plain()
        configuration.imagePlacement = .trailing
        configuration.imagePadding = 5
        configuration.contentInsets = .zero
        var attributedTitle = AttributedString(control.title)
        attributedTitle.font = font
        attributedTitle.foregroundColor = foregroundColor
        attributedTitle.baselineOffset = -1.0
        configuration.attributedTitle = attributedTitle
        configuration.baseForegroundColor = foregroundColor
        button.configuration = configuration
        button.backgroundColor = UIColor(named: "White-03", in: .module, compatibleWith: nil)
            ?? UIColor.white.withAlphaComponent(0.9)
        button.setImage(theme.image(assetName: control.iconName)?.withRenderingMode(.alwaysOriginal), for: .normal)
    }

    @objc private func tap(_ sender: UIButton) {
        guard let entry = buttons.first(where: { $0.button === sender }) else { return }
        onAction?(.extraControlTapped(id: entry.id))
    }
}
