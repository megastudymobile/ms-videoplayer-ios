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

        iconLabel.text = icon
        titleLabel.text = title
        detailLabel.text = detail
        detailLabel.isHidden = detail?.isEmpty != false
        titleLabel.font = emphasized
            ? .systemFont(ofSize: 34, weight: .bold)
            : .systemFont(ofSize: 18, weight: .semibold)

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

        iconLabel.text = "▶"
        titleLabel.text = String(format: "%.1f배속", rate)
        detailLabel.text = nil
        detailLabel.isHidden = true
        titleLabel.font = .systemFont(ofSize: 34, weight: .bold)

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

private extension PlayerGestureHUDView {
    func configureUI() {
        isHidden = true
        alpha = 0
        isUserInteractionEnabled = false

        contentView.backgroundColor = UIColor.black.withAlphaComponent(0.64)
        contentView.layer.cornerRadius = 8

        iconLabel.textColor = .white
        iconLabel.font = .systemFont(ofSize: 28, weight: .semibold)
        iconLabel.textAlignment = .center

        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 1
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.75

        detailLabel.textColor = UIColor.white.withAlphaComponent(0.86)
        detailLabel.font = .systemFont(ofSize: 13, weight: .medium)
        detailLabel.textAlignment = .center
        detailLabel.numberOfLines = 1
        detailLabel.adjustsFontSizeToFitWidth = true
        detailLabel.minimumScaleFactor = 0.75

        addSubview(contentView)
        contentView.addSubview(iconLabel)
        contentView.addSubview(titleLabel)
        contentView.addSubview(detailLabel)

        contentView.translatesAutoresizingMaskIntoConstraints = false
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        detailLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            contentView.centerXAnchor.constraint(equalTo: centerXAnchor),
            contentView.centerYAnchor.constraint(equalTo: centerYAnchor),
            contentView.widthAnchor.constraint(greaterThanOrEqualToConstant: 116),
            contentView.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, multiplier: 0.44),
            contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 96),

            iconLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            iconLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            titleLabel.topAnchor.constraint(equalTo: iconLabel.bottomAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            detailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3),
            detailLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            detailLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            detailLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }
}
