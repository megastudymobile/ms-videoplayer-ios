//
//  SectionRepeatRangeBlock.swift
//  VideoPlayerSkin
//
//  Created by 모바일팀_정준영 on 2026/06/02.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import UIKit

public final class SectionRepeatRangeBlock: UIView, PlayerSkinBlock {
    public var view: UIView { self }
    public var onAction: ((PlayerSkinAction) -> Void)?

    private let stack = UIStackView()
    private let startButton = UIButton(type: .custom)
    private let endButton = UIButton(type: .custom)

    public override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError() }

    public func render(_ state: PlayerSkinState, theme: PlayerSkinTheme) {
        let primaryColor = theme.color(.progressFill)
        let normalFont = theme.font(.sectionRepeatRange)
        let selectedFont = UIFont(name: "AppleSDGothicNeo-SemiBold", size: 15) ?? .systemFont(ofSize: 15, weight: .semibold)

        switch state.sectionRepeat {
        case .idle:
            isHidden = true
            configure(startButton, title: "시작", selected: false, font: normalFont, selectedFont: selectedFont, primaryColor: primaryColor)
            configure(endButton, title: "끝", selected: false, font: normalFont, selectedFont: selectedFont, primaryColor: primaryColor)
        case let .started(start):
            isHidden = state.layoutMode != .fullScreen
            configure(startButton, title: PlayerSkinState.formatTime(start), selected: true, font: normalFont, selectedFont: selectedFont, primaryColor: primaryColor)
            configure(endButton, title: "끝", selected: false, font: normalFont, selectedFont: selectedFont, primaryColor: primaryColor)
        case let .looping(start, end):
            isHidden = state.layoutMode != .fullScreen
            configure(startButton, title: PlayerSkinState.formatTime(start), selected: true, font: normalFont, selectedFont: selectedFont, primaryColor: primaryColor)
            configure(endButton, title: PlayerSkinState.formatTime(end), selected: true, font: normalFont, selectedFont: selectedFont, primaryColor: primaryColor)
        }

        startButton.isEnabled = !state.isLocked
        endButton.isEnabled = !state.isLocked
    }

    private func configure() {
        stack.axis = .horizontal
        stack.alignment = .center
        stack.distribution = .fill
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        [startButton, endButton].forEach {
            $0.backgroundColor = UIColor.black.withAlphaComponent(0.55)
            $0.layer.cornerRadius = 20
            $0.layer.masksToBounds = true
            $0.translatesAutoresizingMaskIntoConstraints = false
            stack.addArrangedSubview($0)
            NSLayoutConstraint.activate([
                $0.widthAnchor.constraint(equalToConstant: 100),
                $0.heightAnchor.constraint(equalToConstant: 40)
            ])
        }
        startButton.accessibilityIdentifier = "videoPlayer.skin.sectionRepeatStartButton"
        endButton.accessibilityIdentifier = "videoPlayer.skin.sectionRepeatEndButton"
        startButton.addTarget(self, action: #selector(startTap), for: .touchUpInside)
        endButton.addTarget(self, action: #selector(endTap), for: .touchUpInside)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }

    private func configure(
        _ button: UIButton,
        title: String,
        selected: Bool,
        font: UIFont,
        selectedFont: UIFont,
        primaryColor: UIColor
    ) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: selected ? selectedFont : font,
            .foregroundColor: selected ? primaryColor : UIColor.white
        ]
        button.setAttributedTitle(NSAttributedString(string: title, attributes: attributes), for: .normal)
        button.isSelected = selected
    }

    @objc private func startTap() { onAction?(.sectionRepeatStartRequested) }
    @objc private func endTap() { onAction?(.sectionRepeatEndRequested) }
}
