//
//  SettingCell.swift
//  VideoPlayerExample
//
//  Created by JunyoungJung on 2026/06/09.
//
//  단일 유연 설정 셀 — SLSettingViewController 셀 타입 parity.
//  디자인 토큰은 SL(UIColor+SLColors / SLMyMenuItemView)에서 그대로 가져왔다:
//   - 흰 셀 + 상/하 hairline(둥근 코너 없음), 좌 20 / 우 15 / 상하 20 inset
//   - title: AppleSDGothicNeo SemiBold 17 (slBlack≈label)
//   - description: AppleSDGothicNeo Light 14 (slGrey58)
//   - detail: Light 17 / 스테퍼 값: SemiBold 20
//

import UIKit

// MARK: - SL 디자인 토큰

/// SL 색상(Color.xcassets) 1:1 — light/dark 동시 대응.
enum SLPalette {
    static let paleGrey = dynamic(light: 0xF3F7FA, dark: 0x252626)   // 테이블 배경
    static let cardWhite = dynamic(light: 0xFFFFFF, dark: 0x181A1A)  // slWhite
    static let grey58 = dynamic(light: 0x949494, dark: 0x616466)     // slGrey58
    static let skyBlue = dynamic(light: 0x3DAED6, dark: 0x237490)    // slPrimarySkyBlue
    static let hairline = dynamic(light: 0xE5E5E5, dark: 0x333333)
    static let lineGrey = dynamic(light: 0xD6D6D6, dark: 0x34393D)   // Line/grey — 스위치 off 테두리

    private static func dynamic(light: Int, dark: Int) -> UIColor {
        UIColor { $0.userInterfaceStyle == .dark ? color(dark) : color(light) }
    }
    private static func color(_ hex: Int) -> UIColor {
        UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

/// SL AppleSDGothicNeo 폰트 — 미설치 시 시스템 폰트로 폴백.
enum SLFont {
    static func title() -> UIFont { named("AppleSDGothicNeo-SemiBold", 17, .semibold) }
    static func sectionHeader() -> UIFont { named("AppleSDGothicNeo-Regular", 14, .regular) }
    static func description() -> UIFont { named("AppleSDGothicNeo-Light", 14, .light) }
    static func detail() -> UIFont { named("AppleSDGothicNeo-Light", 17, .light) }
    static func stepperValue() -> UIFont { .systemFont(ofSize: 17, weight: .light) }
    static func detailButton() -> UIFont { named("AppleSDGothicNeo-SemiBold", 14, .semibold) }
    /// 자막 미리보기 샘플 — SL kSLPlayerSettingCaptionFontNameDefault(Regular), 가변 크기.
    static func captionSample(size: CGFloat) -> UIFont { named("AppleSDGothicNeo-Regular", size, .regular) }

    private static func named(_ name: String, _ size: CGFloat, _ weight: UIFont.Weight) -> UIFont {
        UIFont(name: name, size: size) ?? .systemFont(ofSize: size, weight: weight)
    }
}

@MainActor
final class SettingCell: UITableViewCell {
    static let reuseID = "SettingCell"

    // MARK: - Subviews

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = SLFont.title()
        label.textColor = .label
        label.numberOfLines = 0
        return label
    }()

    private let newBadge: UILabel = {
        let label = UILabel()
        label.text = "N"
        label.font = .systemFont(ofSize: 10, weight: .bold)
        label.textColor = .white
        label.backgroundColor = SLPalette.skyBlue
        label.textAlignment = .center
        label.layer.cornerRadius = 3
        label.clipsToBounds = true
        label.setContentHuggingPriority(.required, for: .horizontal)
        return label
    }()

    private let inlineDetailLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 1
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }()

    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = SLFont.description()
        label.textColor = SLPalette.grey58
        label.numberOfLines = 0
        return label
    }()

    /// 우측 detail 값 (navigation/detail/cacheClear 공용) — Light 17.
    private let detailLabel: UILabel = {
        let label = UILabel()
        label.font = SLFont.detail()
        label.textColor = .label
        label.textAlignment = .right
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }()

    private let toggle: UISwitch = {
        let toggle = UISwitch()
        toggle.tintColor = SLPalette.lineGrey
        toggle.onTintColor = SLPalette.skyBlue
        toggle.thumbTintColor = .white
        return toggle
    }()

    private let chevron: UIImageView = {
        let view = UIImageView(image: UIImage(systemName: "chevron.right"))
        view.tintColor = SLPalette.grey58
        view.contentMode = .scaleAspectFit
        view.setContentHuggingPriority(.required, for: .horizontal)
        return view
    }()

    private lazy var minusButton = makeStepperButton(symbol: "minus")
    private lazy var plusButton = makeStepperButton(symbol: "plus")
    private let stepperValueLabel: UILabel = {
        let label = UILabel()
        label.font = SLFont.stepperValue()
        label.textColor = .label
        label.textAlignment = .center
        return label
    }()

    private lazy var clearButton: UIButton = {
        var config = UIButton.Configuration.bordered()
        config.cornerStyle = .medium
        config.baseForegroundColor = SLPalette.skyBlue
        let button = UIButton(configuration: config)
        button.setContentHuggingPriority(.required, for: .horizontal)
        return button
    }()

    private let accessoryStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 11
        return stack
    }()

    // MARK: - Callbacks

    private var onToggle: ((Bool) -> Void)?
    private var onDecrement: (() -> Void)?
    private var onIncrement: (() -> Void)?
    private var onClear: (() -> Void)?

    // MARK: - Init

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = SLPalette.cardWhite
        // SL 좌 20 / 우 15 inset.
        contentView.directionalLayoutMargins = .init(top: 14, leading: 20, bottom: 14, trailing: 15)
        configureLayout()
        toggle.addAction(UIAction { [weak self] _ in self?.onToggle?(self?.toggle.isOn ?? false) }, for: .valueChanged)
        minusButton.addAction(UIAction { [weak self] _ in self?.onDecrement?() }, for: .touchUpInside)
        plusButton.addAction(UIAction { [weak self] _ in self?.onIncrement?() }, for: .touchUpInside)
        clearButton.addAction(UIAction { [weak self] _ in self?.onClear?() }, for: .touchUpInside)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureLayout() {
        let titleRow = UIStackView(arrangedSubviews: [titleLabel, newBadge, inlineDetailLabel])
        titleRow.axis = .horizontal
        titleRow.alignment = .center
        titleRow.spacing = 6

        let textStack = UIStackView(arrangedSubviews: [titleRow, descriptionLabel])
        textStack.axis = .vertical
        textStack.alignment = .leading
        textStack.spacing = 4

        let mainStack = UIStackView(arrangedSubviews: [textStack, accessoryStack])
        mainStack.axis = .horizontal
        mainStack.alignment = .center
        mainStack.spacing = 12
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.setContentHuggingPriority(.defaultLow, for: .horizontal)
        accessoryStack.setContentHuggingPriority(.required, for: .horizontal)

        contentView.addSubview(mainStack)
        NSLayoutConstraint.activate([
            mainStack.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            mainStack.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
            mainStack.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor),
            contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 58),
            newBadge.widthAnchor.constraint(equalToConstant: 16),
            newBadge.heightAnchor.constraint(equalToConstant: 16),
            chevron.widthAnchor.constraint(equalToConstant: 12),
            stepperValueLabel.widthAnchor.constraint(equalToConstant: 44),
            minusButton.widthAnchor.constraint(equalToConstant: 24),
            minusButton.heightAnchor.constraint(equalToConstant: 24),
            plusButton.widthAnchor.constraint(equalToConstant: 24),
            plusButton.heightAnchor.constraint(equalToConstant: 24)
        ])
    }

    private func makeStepperButton(symbol: String) -> UIButton {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .light))
        config.baseForegroundColor = SLPalette.grey58
        config.contentInsets = .zero
        let button = UIButton(configuration: config)
        button.backgroundColor = .clear
        button.layer.borderColor = SLPalette.grey58.cgColor
        button.layer.borderWidth = 0.5
        button.layer.cornerRadius = 12
        button.clipsToBounds = true
        button.setContentHuggingPriority(.required, for: .horizontal)
        return button
    }

    // MARK: - Configure

    func configure(with item: SettingItem) {
        titleLabel.text = item.title
        newBadge.isHidden = item.isNew == false
        inlineDetailLabel.attributedText = item.inlineAttributedText
        inlineDetailLabel.isHidden = item.inlineAttributedText == nil
        if let attributed = item.attributedDescription {
            descriptionLabel.attributedText = attributed
            descriptionLabel.isHidden = false
        } else {
            descriptionLabel.attributedText = nil
            descriptionLabel.font = SLFont.description()
            descriptionLabel.textColor = SLPalette.grey58
            descriptionLabel.text = item.description
            descriptionLabel.isHidden = (item.description?.isEmpty ?? true)
        }

        accessoryStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        onToggle = nil; onDecrement = nil; onIncrement = nil; onClear = nil

        switch item.accessory {
        case .toggle(let get, let set):
            selectionStyle = .none
            toggle.isOn = get()
            onToggle = set
            accessoryStack.addArrangedSubview(toggle)

        case .stepper(let value, let canDec, let canInc, let onDec, let onInc):
            selectionStyle = .none
            stepperValueLabel.text = value()
            minusButton.isEnabled = canDec()
            plusButton.isEnabled = canInc()
            onDecrement = onDec
            onIncrement = onInc
            [minusButton, stepperValueLabel, plusButton].forEach { accessoryStack.addArrangedSubview($0) }

        case .navigation(let detail, _):
            selectionStyle = .default
            if let detail {
                detailLabel.text = detail()
                accessoryStack.addArrangedSubview(detailLabel)
            }
            accessoryStack.addArrangedSubview(chevron)

        case .action(let detail, _):
            selectionStyle = .default
            if let detail {
                detailLabel.text = detail()
                accessoryStack.addArrangedSubview(detailLabel)
            }
            accessoryStack.addArrangedSubview(chevron)

        case .detail(let value):
            selectionStyle = .none
            detailLabel.text = value()
            accessoryStack.addArrangedSubview(detailLabel)

        case .cacheClear(let value, let clearTitle, let onClearHandler):
            selectionStyle = .none
            detailLabel.text = value()
            onClear = onClearHandler
            clearButton.setTitle(clearTitle, for: .normal)
            accessoryStack.addArrangedSubview(detailLabel)
            accessoryStack.addArrangedSubview(clearButton)
        }
    }
}
