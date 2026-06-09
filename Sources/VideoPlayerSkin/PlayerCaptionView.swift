//
//  PlayerCaptionView.swift
//  VideoPlayerSkin
//
//  Created by 모바일팀_정준영 on 2026/05/19.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import UIKit

public final class PlayerCaptionView: UIView {
    private enum Metric {
        static let primaryBottomOffsetWhenSecondaryVisible: CGFloat = 35
        static let horizontalInset: CGFloat = 10
        /// dev `MGPlayerViewController.kMGPlayerCaptionBottomInset` parity.
        static let defaultBottomInset: CGFloat = 5
    }

    private let primaryLabel = UILabel()
    private let secondaryLabel = LegacySubCaptionLabel()
    private var primaryBottomConstraint: NSLayoutConstraint?
    private var primaryBottomWithSecondaryConstraint: NSLayoutConstraint?
    private var secondaryBottomConstraint: NSLayoutConstraint?
    private var currentState = PlayerCaptionState.initial

    /// 영상 하단으로부터의 자막 여백. dev `captionView.bottom = playerView.bottom - 5` parity.
    public var bottomInset: CGFloat = Metric.defaultBottomInset {
        didSet { updateBottomConstraintConstants() }
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
        render(.initial)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func render(_ state: PlayerCaptionState) {
        currentState = state
        isHidden = state.isVisible == false || (state.hasPrimaryCaption == false && state.hasSecondaryCaption == false)

        primaryLabel.attributedText = attributedCaption(state.primaryText, fontSize: state.fontSize)
        secondaryLabel.attributedText = attributedCaption(state.secondaryText, fontSize: state.fontSize * 0.9)

        primaryLabel.isHidden = state.hasPrimaryCaption == false
        secondaryLabel.isHidden = state.hasSecondaryCaption == false
        updatePrimaryBottomConstraint(hasSecondaryCaption: state.hasSecondaryCaption)
    }

    public func update(text: String, isSecondary: Bool) {
        render(currentState.updating(text: text, isSecondary: isSecondary))
    }

    /// spec-063 P13 — settings panel 의 자막 크기 변경 즉시 반영.
    public func applyFontSize(_ size: Int) {
        var nextState = currentState
        nextState.fontSize = CGFloat(size)
        render(nextState)
    }

    /// AI 자막 on/off 토글 연동. off 면 텍스트가 있어도 숨김.
    public func setVisible(_ visible: Bool) {
        var nextState = currentState
        nextState.isVisible = visible
        render(nextState)
    }
}

extension PlayerCaptionView: PlayerSkinCaptionOverlay {
    public var view: UIView { self }
}

private extension PlayerCaptionView {
    func configureUI() {
        isUserInteractionEnabled = false
        accessibilityIdentifier = "lecturePlayer.captionView"

        [primaryLabel, secondaryLabel].forEach {
            $0.backgroundColor = .clear
            $0.textAlignment = .center
            $0.numberOfLines = 0
            $0.textColor = .white
            $0.layer.shadowColor = UIColor.black.cgColor
            $0.layer.shadowRadius = 3
            $0.layer.shadowOpacity = 1
            $0.layer.shadowOffset = .zero
            $0.layer.masksToBounds = false
            $0.layer.shouldRasterize = true
            $0.layer.rasterizationScale = UIScreen.main.scale
        }
        primaryLabel.accessibilityIdentifier = "lecturePlayer.caption.primaryLabel"
        secondaryLabel.accessibilityIdentifier = "lecturePlayer.caption.secondaryLabel"

        primaryLabel.translatesAutoresizingMaskIntoConstraints = false
        secondaryLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(primaryLabel)
        addSubview(secondaryLabel)

        let primaryBottom = primaryLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -bottomInset)
        let primaryBottomWithSecondary = primaryLabel.bottomAnchor.constraint(
            equalTo: bottomAnchor,
            constant: -(bottomInset + Metric.primaryBottomOffsetWhenSecondaryVisible)
        )
        let secondaryBottom = secondaryLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -bottomInset)
        primaryBottomConstraint = primaryBottom
        primaryBottomWithSecondaryConstraint = primaryBottomWithSecondary
        secondaryBottomConstraint = secondaryBottom

        NSLayoutConstraint.activate([
            primaryLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            primaryLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: Metric.horizontalInset),
            primaryLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -Metric.horizontalInset),
            primaryLabel.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: Metric.horizontalInset),
            primaryBottom,

            secondaryLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            secondaryLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: Metric.horizontalInset),
            secondaryLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -Metric.horizontalInset),
            secondaryLabel.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: Metric.horizontalInset),
            secondaryBottom
        ])
    }

    func updateBottomConstraintConstants() {
        primaryBottomConstraint?.constant = -bottomInset
        primaryBottomWithSecondaryConstraint?.constant = -(bottomInset + Metric.primaryBottomOffsetWhenSecondaryVisible)
        secondaryBottomConstraint?.constant = -bottomInset
    }

    func updatePrimaryBottomConstraint(hasSecondaryCaption: Bool) {
        primaryBottomConstraint?.isActive = hasSecondaryCaption == false
        primaryBottomWithSecondaryConstraint?.isActive = hasSecondaryCaption
    }

    func attributedCaption(_ text: String, fontSize: CGFloat) -> NSAttributedString {
        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedText.isEmpty == false else { return NSAttributedString(string: "") }
        if let htmlCaption = htmlAttributedCaption(normalizedText, fontSize: fontSize) { return htmlCaption }
        return NSAttributedString(string: normalizedText, attributes: captionAttributes(fontSize: fontSize))
    }

    func htmlAttributedCaption(_ text: String, fontSize: CGFloat) -> NSAttributedString? {
        guard text.contains("<"), let data = text.data(using: .utf8) else { return nil }
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        guard let attributedText = try? NSMutableAttributedString(data: data, options: options, documentAttributes: nil) else {
            return nil
        }
        let range = NSRange(location: 0, length: attributedText.length)
        attributedText.addAttributes(captionAttributes(fontSize: fontSize), range: range)
        trimTrailingWhitespaceAndNewlines(attributedText)
        return attributedText
    }

    func trimTrailingWhitespaceAndNewlines(_ attributedText: NSMutableAttributedString) {
        var text = attributedText.string
        while let lastScalar = text.unicodeScalars.last,
              CharacterSet.whitespacesAndNewlines.contains(lastScalar) {
            attributedText.deleteCharacters(in: NSRange(location: attributedText.length - 1, length: 1))
            text = attributedText.string
        }
    }

    func captionAttributes(fontSize: CGFloat) -> [NSAttributedString.Key: Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineBreakMode = .byWordWrapping
        return [
            .font: UIFont(name: "AppleSDGothicNeo-Regular", size: fontSize)
                ?? UIFont.systemFont(ofSize: fontSize, weight: .regular),
            .foregroundColor: UIColor.white,
            .paragraphStyle: paragraphStyle
        ]
    }
}

private final class LegacySubCaptionLabel: UILabel {
    private enum Metric {
        static let topPadding: CGFloat = 12
        static let defaultPadding: CGFloat = 1.5
    }

    override func drawText(in rect: CGRect) {
        let insets = UIEdgeInsets(
            top: Metric.topPadding,
            left: Metric.defaultPadding,
            bottom: Metric.defaultPadding,
            right: Metric.defaultPadding
        )
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        guard size.height > 0 else { return .zero }
        return CGSize(
            width: size.width + (Metric.defaultPadding * 2),
            height: size.height + Metric.topPadding + Metric.defaultPadding
        )
    }
}
