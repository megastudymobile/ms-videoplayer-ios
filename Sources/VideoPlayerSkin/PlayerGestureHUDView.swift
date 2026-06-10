//
//  PlayerGestureHUDView.swift
//  SmartPlayer
//
//  Created by 모바일팀_정준영 on 2026/05/19.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import UIKit

public final class PlayerGestureHUDView: UIView {
    private let contentView = UIView()
    private let imageView = UIImageView()
    private let iconLabel = UILabel()
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let rateBadgeView = UIView()
    private let rateBadgeLabel = UILabel()
    private let rateBadgeImageView = UIImageView()

    private var hideWorkItem: DispatchWorkItem?
    public var displayDuration: TimeInterval = 2.0

    public override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func show(
        icon: String,
        title: String,
        detail: String? = nil,
        emphasized: Bool = false
    ) {
        hideWorkItem?.cancel()
        layer.removeAllAnimations()
        rateBadgeView.layer.removeAllAnimations()

        applyIcon(icon)
        titleLabel.text = title
        detailLabel.text = detail
        detailLabel.isHidden = detail?.isEmpty != false
        titleLabel.font = emphasized
            ? (UIFont(name: "AppleSDGothicNeo-Bold", size: 40) ?? .systemFont(ofSize: 40, weight: .bold))
            : (UIFont(name: "AppleSDGothicNeo-SemiBold", size: 16) ?? .systemFont(ofSize: 16, weight: .semibold))

        isHidden = false
        alpha = 1
        contentView.isHidden = false
        rateBadgeView.isHidden = true

        guard displayDuration > 0 else { return }
        let workItem = DispatchWorkItem { [weak self] in
            self?.hide()
        }
        hideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + displayDuration, execute: workItem)
    }

    public func presentRate(_ rate: Double) {
        hideWorkItem?.cancel()
        layer.removeAllAnimations()
        rateBadgeView.layer.removeAllAnimations()

        rateBadgeLabel.attributedText = NSAttributedString(
            string: "\(Int(rate))배속",
            attributes: [
                .font: UIFont(name: "AppleSDGothicNeo-Regular", size: UIDevice.current.userInterfaceIdiom == .pad ? 16 : 14)
                    ?? .systemFont(ofSize: UIDevice.current.userInterfaceIdiom == .pad ? 16 : 14, weight: .regular),
                .foregroundColor: UIColor.white,
                .kern: -0.38
            ]
        )
        rateBadgeImageView.image = UIImage(
            named: UIDevice.current.userInterfaceIdiom == .pad ? "PlayerFast2xGuideIconForPad" : "PlayerFast2xGuideIconForPhone",
            in: .module,
            with: nil
        )

        isHidden = false
        alpha = 1
        contentView.isHidden = true
        rateBadgeView.isHidden = false
        rateBadgeView.alpha = 1
    }

    public func hide() {
        hideWorkItem?.cancel()
        UIView.animate(
            withDuration: 0.2,
            delay: 0,
            options: [.curveEaseOut],
            animations: {
                self.alpha = 0
                self.rateBadgeView.alpha = 0
            },
            completion: { finished in
                if finished {
                    self.isHidden = true
                    self.rateBadgeView.isHidden = true
                    self.contentView.isHidden = false
                }
            }
        )
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        rateBadgeView.layer.cornerRadius = rateBadgeView.bounds.height * 0.5
    }
}

extension PlayerGestureHUDView: PlayerSkinGestureHUDOverlay {
    public var view: UIView { self }
}

private extension PlayerGestureHUDView {
    func configureUI() {
        accessibilityIdentifier = "lecturePlayer.gestureHUDView"
        isHidden = true
        alpha = 0
        isUserInteractionEnabled = false

        contentView.backgroundColor = .clear
        rateBadgeView.accessibilityIdentifier = "lecturePlayer.gestureHUD.rateBadgeView"
        rateBadgeView.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        rateBadgeView.isHidden = true
        rateBadgeView.clipsToBounds = true

        iconLabel.textColor = .white
        iconLabel.font = UIFont(name: "AppleSDGothicNeo-SemiBold", size: 28) ?? .systemFont(ofSize: 28, weight: .semibold)
        iconLabel.textAlignment = .center
        imageView.contentMode = .scaleAspectFit

        titleLabel.textColor = UIColor(named: "primarySkyBlue03") ?? UIColor(named: "primarySkyBlue") ?? .white
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 1
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.75

        detailLabel.textColor = UIColor.white.withAlphaComponent(0.86)
        detailLabel.font = UIFont(name: "AppleSDGothicNeo-Regular", size: 14) ?? .systemFont(ofSize: 14, weight: .regular)
        detailLabel.textAlignment = .center
        detailLabel.numberOfLines = 1
        detailLabel.adjustsFontSizeToFitWidth = true
        detailLabel.minimumScaleFactor = 0.75
        rateBadgeLabel.accessibilityIdentifier = "lecturePlayer.gestureHUD.rateBadgeLabel"
        rateBadgeLabel.backgroundColor = .clear
        rateBadgeLabel.textAlignment = .center
        rateBadgeLabel.numberOfLines = 1
        rateBadgeImageView.accessibilityIdentifier = "lecturePlayer.gestureHUD.rateBadgeImageView"
        rateBadgeImageView.backgroundColor = .clear
        rateBadgeImageView.contentMode = .scaleAspectFit

        addSubview(contentView)
        addSubview(rateBadgeView)
        contentView.addSubview(imageView)
        contentView.addSubview(iconLabel)
        contentView.addSubview(titleLabel)
        contentView.addSubview(detailLabel)
        rateBadgeView.addSubview(rateBadgeLabel)
        rateBadgeView.addSubview(rateBadgeImageView)

        contentView.translatesAutoresizingMaskIntoConstraints = false
        rateBadgeView.translatesAutoresizingMaskIntoConstraints = false
        imageView.translatesAutoresizingMaskIntoConstraints = false
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        rateBadgeLabel.translatesAutoresizingMaskIntoConstraints = false
        rateBadgeImageView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            contentView.centerXAnchor.constraint(equalTo: centerXAnchor),
            contentView.centerYAnchor.constraint(equalTo: centerYAnchor),
            contentView.widthAnchor.constraint(greaterThanOrEqualToConstant: 116),
            contentView.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, multiplier: 0.44),
            contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 96),

            imageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            imageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 44),
            imageView.heightAnchor.constraint(equalToConstant: 44),

            iconLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            iconLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            detailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3),
            detailLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            detailLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            detailLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),

            rateBadgeView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 37),
            rateBadgeView.centerXAnchor.constraint(equalTo: centerXAnchor),
            rateBadgeView.heightAnchor.constraint(greaterThanOrEqualToConstant: 32),

            rateBadgeLabel.leadingAnchor.constraint(equalTo: rateBadgeView.leadingAnchor, constant: 14),
            rateBadgeLabel.topAnchor.constraint(greaterThanOrEqualTo: rateBadgeView.topAnchor, constant: 6),
            rateBadgeLabel.bottomAnchor.constraint(lessThanOrEqualTo: rateBadgeView.bottomAnchor, constant: -6),
            rateBadgeLabel.centerYAnchor.constraint(equalTo: rateBadgeView.centerYAnchor),
            rateBadgeLabel.trailingAnchor.constraint(equalTo: rateBadgeImageView.leadingAnchor, constant: -6),

            rateBadgeImageView.centerYAnchor.constraint(equalTo: rateBadgeView.centerYAnchor),
            rateBadgeImageView.widthAnchor.constraint(equalToConstant: 18),
            rateBadgeImageView.heightAnchor.constraint(equalToConstant: 18),
            rateBadgeImageView.trailingAnchor.constraint(equalTo: rateBadgeView.trailingAnchor, constant: -14)
        ])
    }

    func applyIcon(_ icon: String) {
        let assetImage = UIImage(named: icon, in: .module, with: nil) ?? UIImage(named: icon)
        let symbolImage = assetImage == nil ? UIImage(systemName: icon) : nil

        if let image = assetImage ?? symbolImage {
            imageView.image = symbolImage == nil ? image : image.withRenderingMode(.alwaysTemplate)
            imageView.tintColor = .white
            imageView.isHidden = false
            iconLabel.isHidden = true
            iconLabel.text = nil
        } else {
            imageView.image = nil
            imageView.isHidden = true
            iconLabel.isHidden = false
            iconLabel.text = icon
        }
    }
}
