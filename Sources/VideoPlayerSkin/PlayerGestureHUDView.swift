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

    private var hideWorkItem: DispatchWorkItem?

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

        applyIcon(icon)
        titleLabel.text = title
        detailLabel.text = detail
        detailLabel.isHidden = detail?.isEmpty != false
        titleLabel.font = emphasized
            ? (UIFont(name: "AppleSDGothicNeo-Bold", size: 40) ?? .systemFont(ofSize: 40, weight: .bold))
            : (UIFont(name: "AppleSDGothicNeo-SemiBold", size: 16) ?? .systemFont(ofSize: 16, weight: .semibold))

        isHidden = false
        alpha = 1

        let workItem = DispatchWorkItem { [weak self] in
            self?.hide()
        }
        hideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: workItem)
    }

    public func presentRate(_ rate: Double) {
        hideWorkItem?.cancel()

        applyIcon("▶")
        titleLabel.text = String(format: "%.1f배속", rate)
        detailLabel.text = nil
        detailLabel.isHidden = true
        titleLabel.font = UIFont(name: "AppleSDGothicNeo-Bold", size: 40) ?? .systemFont(ofSize: 40, weight: .bold)

        isHidden = false
        alpha = 1
    }

    public func hide() {
        UIView.animate(
            withDuration: 0.2,
            delay: 0,
            options: [.curveEaseOut],
            animations: {
                self.alpha = 0
            },
            completion: { finished in
                if finished {
                    self.isHidden = true
                }
            }
        )
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

        addSubview(contentView)
        contentView.addSubview(imageView)
        contentView.addSubview(iconLabel)
        contentView.addSubview(titleLabel)
        contentView.addSubview(detailLabel)

        contentView.translatesAutoresizingMaskIntoConstraints = false
        imageView.translatesAutoresizingMaskIntoConstraints = false
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        detailLabel.translatesAutoresizingMaskIntoConstraints = false

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
            detailLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
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
