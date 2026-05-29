//
//  PlayerRenderSurfaceView.swift
//  SmartPlayer
//
//  Created by 모바일팀_정준영 on 2026/05/19.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import UIKit
import VideoPlayerCore
import VideoPlayerShellSupport

/// `VideoPlayerShellSupport.PlayerRenderSurface` 의 호스트 앱 측 구현체.
///
/// `AVPlayerAdapter` 또는 `KollusPlayerAdapter` 가 본 view 의 `containerView`(= self) 에
/// 자체 렌더 레이어(`AVPlayerLayer` 등)를 attach 한다. 본 view 는 영상 layer 자체를
/// 다루지 않으며, 영상 준비 전/엔진 detach 상태에서 placeholder 만 표시.
///
/// spec 031 FR-002.
@MainActor
public final class PlayerRenderSurfaceView: UIView, PlayerRenderSurface {
    public var containerView: UIView { self }

    private let placeholderLabel = UILabel()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func engineDidAttach() {
        placeholderLabel.isHidden = true
    }

    public func engineDidDetach() {
        placeholderLabel.isHidden = false
    }

    /// SDK `KollusPlayerAdapter.attach(playerView:to:)` 가 `playerView.frame = containerView.bounds`
    /// + `autoresizingMask = [.flexibleWidth, .flexibleHeight]` 로 add. attach 시점 본
    /// view 의 bounds 가 `.zero` 이거나 layout pass 가 늦으면 autoresize 가 따라가지 못해
    /// video frame 이 작게 표시된다. layout pass 마다 video subview frame = bounds 강제.
    public override func layoutSubviews() {
        super.layoutSubviews()
        for subview in subviews where subview !== placeholderLabel {
            subview.frame = bounds
        }
    }

    private func configureUI() {
        backgroundColor = .black
        clipsToBounds = true

        placeholderLabel.text = "영상 준비 중"
        placeholderLabel.textColor = UIColor.white.withAlphaComponent(0.7)
        placeholderLabel.font = .systemFont(ofSize: 15, weight: .regular)
        placeholderLabel.textAlignment = .center
        placeholderLabel.accessibilityIdentifier = "lecturePlayer.renderSurface.placeholderLabel"

        addSubview(placeholderLabel)
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            placeholderLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            placeholderLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
}
