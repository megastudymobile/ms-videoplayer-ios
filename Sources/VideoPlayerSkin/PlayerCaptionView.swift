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
        static let secondarySpacing: CGFloat = 35
        static let horizontalInset: CGFloat = 10
        /// dev `MGPlayerViewController.kMGPlayerCaptionBottomInset` parity.
        static let defaultBottomInset: CGFloat = 5
    }

    private let primaryLabel = UILabel()
    private let secondaryLabel = UILabel()
    /// 두 자막 라벨을 쌓는 컨테이너 (hidden 라벨은 stack 이 자동 collapse).
    private let labelStack = UIStackView()
    private var bottomConstraint: NSLayoutConstraint?
    private var currentState = PlayerCaptionState.initial

    /// 영상 하단으로부터의 자막 여백(컨트롤바 위). host 가 조정 가능.
    public var bottomInset: CGFloat = Metric.defaultBottomInset {
        didSet { bottomConstraint?.constant = -bottomInset }
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

        labelStack.axis = .vertical
        labelStack.alignment = .center
        labelStack.spacing = Metric.secondarySpacing
        labelStack.translatesAutoresizingMaskIntoConstraints = false
        labelStack.addArrangedSubview(primaryLabel)
        labelStack.addArrangedSubview(secondaryLabel)
        addSubview(labelStack)

        // captionView 는 영상 영역 전체를 덮고(host 가 fill 앵커), 자막 블럭은 하단(bottomInset 위)에 정렬.
        let bottom = labelStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -bottomInset)
        bottomConstraint = bottom
        NSLayoutConstraint.activate([
            labelStack.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: Metric.horizontalInset),
            bottom,
            labelStack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: Metric.horizontalInset),
            labelStack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -Metric.horizontalInset),
            labelStack.centerXAnchor.constraint(equalTo: centerXAnchor)
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
        return attributedText
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
