//
//  PlayerCaptionView.swift
//  SmartPlayer
//
//  Created by 모바일팀_정준영 on 2026/05/19.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import UIKit

public final class PlayerCaptionView: UIView {
    private enum Metric {
        static let secondarySpacing: CGFloat = 6
        static let horizontalInset: CGFloat = 10
    }

    private let primaryLabel = UILabel()
    private let secondaryLabel = UILabel()
    private var currentState = PlayerCaptionState.initial

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

        primaryLabel.attributedText = attributedCaption(
            state.primaryText,
            fontSize: state.fontSize
        )
        secondaryLabel.attributedText = attributedCaption(
            state.secondaryText,
            fontSize: state.fontSize * 0.9
        )

        primaryLabel.isHidden = state.hasPrimaryCaption == false
        secondaryLabel.isHidden = state.hasSecondaryCaption == false
    }

    public func update(text: String, isSecondary: Bool) {
        render(currentState.updating(text: text, isSecondary: isSecondary))
    }

    /// spec-063 P13 — settings panel 의 자막 크기 변경 즉시 반영용 외부 API.
    public func applyFontSize(_ size: Int) {
        var nextState = currentState
        nextState.fontSize = CGFloat(size)
        render(nextState)
    }
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
            // spec-052 Phase 4.3 — dev SLPlayerCaptionView.m:60/74 shouldRasterize 추가.
            // 자막 layer shadow rendering 성능 hint (dev parity).
            $0.layer.shouldRasterize = true
            $0.layer.rasterizationScale = UIScreen.main.scale
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }

        primaryLabel.accessibilityIdentifier = "lecturePlayer.caption.primaryLabel"
        secondaryLabel.accessibilityIdentifier = "lecturePlayer.caption.secondaryLabel"

        NSLayoutConstraint.activate([
            primaryLabel.topAnchor.constraint(greaterThanOrEqualTo: topAnchor),
            primaryLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: Metric.horizontalInset),
            primaryLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -Metric.horizontalInset),
            primaryLabel.centerXAnchor.constraint(equalTo: centerXAnchor),

            secondaryLabel.topAnchor.constraint(equalTo: primaryLabel.bottomAnchor, constant: Metric.secondarySpacing),
            secondaryLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: Metric.horizontalInset),
            secondaryLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -Metric.horizontalInset),
            secondaryLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            secondaryLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor)
        ])
    }

    func attributedCaption(_ text: String, fontSize: CGFloat) -> NSAttributedString {
        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedText.isEmpty == false else {
            return NSAttributedString(string: "")
        }

        if let htmlCaption = htmlAttributedCaption(normalizedText, fontSize: fontSize) {
            return htmlCaption
        }

        return NSAttributedString(
            string: normalizedText,
            attributes: captionAttributes(fontSize: fontSize)
        )
    }

    func htmlAttributedCaption(_ text: String, fontSize: CGFloat) -> NSAttributedString? {
        guard text.contains("<"), let data = text.data(using: .utf8) else {
            return nil
        }

        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]

        guard let attributedText = try? NSMutableAttributedString(
            data: data,
            options: options,
            documentAttributes: nil
        ) else {
            return nil
        }

        let range = NSRange(location: 0, length: attributedText.length)
        attributedText.addAttributes(captionAttributes(fontSize: fontSize), range: range)
        return attributedText
    }

    func captionAttributes(fontSize: CGFloat) -> [NSAttributedString.Key: Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineBreakMode = .byWordWrapping

        return [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .medium),
            .foregroundColor: UIColor.white,
            .paragraphStyle: paragraphStyle
        ]
    }
}
