//
//  PlayerLoadingIndicatorView.swift
//  VideoPlayerSkin
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import UIKit

/// dev `MGPlayerLoadingView` + `M13ProgressViewRing` parity 중앙 ring indicator.
/// skin 이 소유하므로 lecture/cast 등 모든 host 가 동일 로딩 표시를 공유한다.
///
/// dev 상수: diameter 50, ring width 4. ring 색은 host theme 의 `progressFill`(=primarySkyBlue) 주입.
@MainActor
public final class PlayerLoadingIndicatorView: UIView {
    /// dev `MGPlayerLoadingViewMode` parity. clear=투명 배경, black=검은 overlay.
    enum Mode {
        case clear
        case black
    }

    private static let indicatorDiameter: CGFloat = 50.0
    private static let ringWidth: CGFloat = 4.0
    private static let rotationAnimationKey = "playerSkinLoading.rotation"

    private let ringContainerView = UIView()
    private let ringLayer = CAShapeLayer()
    private var isAnimating = false

    public override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure() {
        isUserInteractionEnabled = false
        isHidden = true
        backgroundColor = .clear

        ringContainerView.translatesAutoresizingMaskIntoConstraints = false
        ringContainerView.isUserInteractionEnabled = false
        addSubview(ringContainerView)

        NSLayoutConstraint.activate([
            ringContainerView.centerXAnchor.constraint(equalTo: centerXAnchor),
            ringContainerView.centerYAnchor.constraint(equalTo: centerYAnchor),
            ringContainerView.widthAnchor.constraint(equalToConstant: Self.indicatorDiameter),
            ringContainerView.heightAnchor.constraint(equalToConstant: Self.indicatorDiameter)
        ])

        ringLayer.fillColor = UIColor.clear.cgColor
        ringLayer.lineWidth = Self.ringWidth
        ringLayer.lineCap = .round
        ringLayer.strokeStart = 0.0
        ringLayer.strokeEnd = 0.75  // 부분 호를 회전시켜 미결정형 spinner 로 사용.
        ringContainerView.layer.addSublayer(ringLayer)
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        let diameter = Self.indicatorDiameter
        let inset = Self.ringWidth / 2
        let rect = CGRect(x: 0, y: 0, width: diameter, height: diameter).insetBy(dx: inset, dy: inset)
        ringLayer.frame = ringContainerView.bounds
        ringLayer.path = UIBezierPath(ovalIn: rect).cgPath
    }

    /// ring 색 주입. host theme 의 `progressFill`(primarySkyBlue) 사용.
    func setRingColor(_ color: UIColor) {
        ringLayer.strokeColor = color.cgColor
    }

    func setMode(_ mode: Mode) {
        switch mode {
        case .clear:
            backgroundColor = .clear
        case .black:
            backgroundColor = UIColor.black.withAlphaComponent(0.6)
        }
    }

    func startAnimating() {
        isHidden = false
        guard isAnimating == false else { return }
        isAnimating = true

        let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.fromValue = 0
        rotation.toValue = 2 * Double.pi
        rotation.duration = 1.0
        rotation.repeatCount = .infinity
        rotation.isRemovedOnCompletion = false
        ringContainerView.layer.add(rotation, forKey: Self.rotationAnimationKey)
    }

    func stopAnimating() {
        isAnimating = false
        ringContainerView.layer.removeAnimation(forKey: Self.rotationAnimationKey)
        isHidden = true
    }
}

extension PlayerLoadingIndicatorView: PlayerSkinLoadingOverlay {
    public var view: UIView { self }

    public func configure(theme: PlayerSkinTheme) {
        setRingColor(theme.color(.progressFill))
    }

    public func setLoading(_ isLoading: Bool) {
        if isLoading {
            setMode(.clear)
            startAnimating()
        } else {
            stopAnimating()
        }
    }
}
