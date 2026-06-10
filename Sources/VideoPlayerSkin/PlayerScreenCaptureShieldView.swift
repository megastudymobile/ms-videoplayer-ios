//
//  PlayerScreenCaptureShieldView.swift
//  VideoPlayerModule
//
//  Created by JunyoungJung on 2026/06/10.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

import UIKit

/// 화면 캡처(녹화/미러링) 중 재생 화면을 가리는 전면 차단막.
/// 시각만 가린다 — 컨트롤 터치를 막지 않도록 non-interactive.
final class PlayerScreenCaptureShieldView: UIView {
    private let iconView = UIImageView()
    private let messageLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        isUserInteractionEnabled = false

        iconView.image = UIImage(systemName: "video.slash")
        iconView.tintColor = UIColor.white.withAlphaComponent(0.7)
        iconView.contentMode = .scaleAspectFit

        messageLabel.text = "화면 녹화 중에는 재생 화면이 보호됩니다"
        messageLabel.textColor = UIColor.white.withAlphaComponent(0.7)
        messageLabel.font = .systemFont(ofSize: 15, weight: .regular)
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [iconView, messageLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        iconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 40),
            iconView.heightAnchor.constraint(equalToConstant: 40),
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24)
        ])
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    func setMessage(_ text: String) {
        messageLabel.text = text
    }
}
