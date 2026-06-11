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
        static let horizontalInset: CGFloat = 10
        static let defaultBottomInset: CGFloat = 5
    }

    private let captionStackView = UIStackView()
    private let primaryLabel = UILabel()
    private let secondaryLabel = UILabel()
    private var captionBottomConstraint: NSLayoutConstraint?
    private var currentState = PlayerCaptionState.initial

    /// 영상 하단으로부터의 자막 여백.
    public var bottomInset: CGFloat = Metric.defaultBottomInset {
        didSet { captionBottomConstraint?.constant = -bottomInset }
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

        let secondaryFontSize = state.hasPrimaryCaption ? state.fontSize * 0.9 : state.fontSize
        primaryLabel.attributedText = attributedCaption(state.primaryText, fontSize: state.fontSize)
        secondaryLabel.attributedText = attributedCaption(state.secondaryText, fontSize: secondaryFontSize)

        primaryLabel.isHidden = state.hasPrimaryCaption == false
        secondaryLabel.isHidden = state.hasSecondaryCaption == false
    }

    public func update(text: String, isSecondary: Bool) {
        render(currentState.updating(text: text, isSecondary: isSecondary))
    }

    /// settings panel 의 자막 크기 변경을 즉시 반영한다.
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
        captionStackView.accessibilityIdentifier = "lecturePlayer.caption.stackView"
        captionStackView.axis = .vertical
        captionStackView.alignment = .center
        captionStackView.distribution = .fill
        captionStackView.spacing = 0
        captionStackView.isUserInteractionEnabled = false

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

        captionStackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(captionStackView)
        captionStackView.addArrangedSubview(primaryLabel)
        captionStackView.addArrangedSubview(secondaryLabel)

        let stackBottom = captionStackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -bottomInset)
        captionBottomConstraint = stackBottom

        NSLayoutConstraint.activate([
            captionStackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            captionStackView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: Metric.horizontalInset),
            captionStackView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -Metric.horizontalInset),
            captionStackView.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: Metric.horizontalInset),
            stackBottom
        ])
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
