//
//  AVPlayerRenderSurfaceView.swift
//  VideoPlayerExample
//
//  Created by 모바일팀_정준영 on 2026/05/17.
//

import UIKit
import VideoPlayerCore
import VideoPlayerShellSupport

final class AVPlayerRenderSurfaceView: UIView, PlayerRenderSurface {
    var containerView: UIView {
        self
    }

    private let placeholderLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func engineDidAttach() {
        placeholderLabel.isHidden = true
    }

    func engineDidDetach() {
        placeholderLabel.isHidden = false
    }

    private func configureUI() {
        backgroundColor = .black
        layer.cornerRadius = 8
        clipsToBounds = true

        placeholderLabel.text = "영상 준비 전"
        placeholderLabel.textColor = .white
        placeholderLabel.font = .systemFont(ofSize: 16, weight: .medium)

        addSubview(placeholderLabel)
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            placeholderLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            placeholderLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
}
