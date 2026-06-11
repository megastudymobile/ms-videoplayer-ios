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
@MainActor
public final class PlayerRenderSurfaceView: UIView {
    public var containerView: UIView { self }

    private let placeholderLabel = UILabel()

    /// 시뮬레이터 등 재생 미지원 환경 안내 오버레이 (아이콘 + 텍스트).
    /// `showUnsupportedEnvironment(message:)` 호출 전까지 hidden.
    private let unsupportedOverlay = UIStackView()
    private let unsupportedIconView = UIImageView()
    private let unsupportedLabel = UILabel()

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
        unsupportedOverlay.isHidden = true
    }

    public func engineDidDetach() {
        placeholderLabel.isHidden = false
    }

    public func showUnsupportedEnvironment(message: String) {
        unsupportedLabel.text = message
        placeholderLabel.isHidden = true
        unsupportedOverlay.isHidden = false
        bringSubviewToFront(unsupportedOverlay)
    }

    /// SDK `KollusPlayerAdapter.attach(playerView:to:)` 가 `playerView.frame = containerView.bounds`
    /// + `autoresizingMask = [.flexibleWidth, .flexibleHeight]` 로 add. attach 시점 본
    /// view 의 bounds 가 `.zero` 이거나 layout pass 가 늦으면 autoresize 가 따라가지 못해
    /// video frame 이 작게 표시된다. layout pass 마다 video subview frame = bounds 강제.
    public override func layoutSubviews() {
        super.layoutSubviews()
        for subview in subviews where subview !== placeholderLabel && subview !== unsupportedOverlay {
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
        placeholderLabel.accessibilityIdentifier = "videoPlayer.skin.renderSurface.placeholderLabel"

        addSubview(placeholderLabel)
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            placeholderLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            placeholderLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        configureUnsupportedOverlay()
    }

    private func configureUnsupportedOverlay() {
        unsupportedIconView.image = UIImage(systemName: "exclamationmark.triangle")
        unsupportedIconView.tintColor = UIColor.white.withAlphaComponent(0.7)
        unsupportedIconView.contentMode = .scaleAspectFit
        unsupportedIconView.translatesAutoresizingMaskIntoConstraints = false
        unsupportedIconView.heightAnchor.constraint(equalToConstant: 36).isActive = true
        unsupportedIconView.widthAnchor.constraint(equalToConstant: 36).isActive = true

        unsupportedLabel.textColor = UIColor.white.withAlphaComponent(0.7)
        unsupportedLabel.font = .systemFont(ofSize: 15, weight: .regular)
        unsupportedLabel.textAlignment = .center
        unsupportedLabel.numberOfLines = 0

        unsupportedOverlay.axis = .vertical
        unsupportedOverlay.alignment = .center
        unsupportedOverlay.spacing = 12
        unsupportedOverlay.isHidden = true
        unsupportedOverlay.accessibilityIdentifier = "videoPlayer.skin.renderSurface.unsupportedOverlay"
        unsupportedOverlay.addArrangedSubview(unsupportedIconView)
        unsupportedOverlay.addArrangedSubview(unsupportedLabel)

        addSubview(unsupportedOverlay)
        unsupportedOverlay.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            unsupportedOverlay.centerXAnchor.constraint(equalTo: centerXAnchor),
            unsupportedOverlay.centerYAnchor.constraint(equalTo: centerYAnchor),
            unsupportedOverlay.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 24),
            unsupportedOverlay.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24)
        ])
    }
}

extension PlayerRenderSurfaceView: @MainActor PlayerRenderSurface {}
