//
//  PlayerSeekPreviewView.swift
//  VideoPlayerModule
//
//  Created by 모바일팀_정준영 on 2026/06/10.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import UIKit

/// 시킹 스크럽 프리뷰 모달 — 썸네일 이미지(16:9) + 시간 라벨.
/// 이미지 공급자가 있으면 placeholder로 시작해 모달 크기가 도중에 튀지 않게 하고,
/// 이미지 확보 실패가 확정되면 시간 라벨만 있는 컴팩트 모드로 축소한다.
/// 위치/크기는 presenter가 frame으로 직접 제어한다(120Hz 추적) — Auto Layout 금지.
final class PlayerSeekPreviewView: UIView {
    enum Mode: Equatable {
        /// 시간 라벨만 — 공급자 없음 또는 이미지 확보 실패 확정.
        case compact
        /// 이미지 크기 + placeholder 아이콘 — 첫 이미지 도착 전.
        case placeholder
        /// 썸네일 표시 중.
        case image
    }

    private let imageView = UIImageView()
    private let placeholderIconView = UIImageView(
        image: UIImage(systemName: "photo")
    )
    private let timeLabel = UILabel()
    private(set) var mode: Mode = .compact

    private enum Metric {
        static let imageSize = CGSize(width: 142, height: 80)
        static let labelHeight: CGFloat = 24
        static let compactSize = CGSize(width: 88, height: 32)
        static let placeholderIconSize = CGSize(width: 36, height: 28)
    }

    /// presenter가 frame 계산에 사용하는 현재 모드의 콘텐츠 크기.
    var contentSize: CGSize {
        mode == .compact
            ? Metric.compactSize
            : CGSize(width: Metric.imageSize.width, height: Metric.imageSize.height + Metric.labelHeight)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.black.withAlphaComponent(0.85)
        layer.borderColor = UIColor.white.cgColor
        layer.borderWidth = 1
        layer.cornerRadius = 4
        clipsToBounds = true
        isUserInteractionEnabled = false

        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = .black
        placeholderIconView.contentMode = .scaleAspectFit
        placeholderIconView.tintColor = UIColor.white.withAlphaComponent(0.35)
        timeLabel.textColor = .white
        timeLabel.font = .systemFont(ofSize: 13, weight: .bold)
        timeLabel.textAlignment = .center
        addSubview(imageView)
        addSubview(placeholderIconView)
        addSubview(timeLabel)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    func setTime(_ text: String) {
        timeLabel.text = text
    }

    /// 스크럽 세션 시작 — 공급자가 있으면 placeholder로 시작해 이미지 도착 시
    /// 모달 크기가 커지며 튀는 것을 막는다.
    func beginSession(showsPlaceholder: Bool) {
        mode = showsPlaceholder ? .placeholder : .compact
        imageView.image = nil
        setNeedsLayout()
    }

    /// placeholder 상태의 nil은 "이미지 확보 실패 확정"으로 보고 컴팩트로 축소한다.
    /// 이미 이미지가 표시된 뒤의 단발 nil은 무시 — 직전 프레임 유지(깜빡임 방지).
    func setImage(_ image: UIImage?) {
        if let image {
            mode = .image
            imageView.image = image
        } else if mode == .placeholder {
            mode = .compact
        }
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if mode == .compact {
            imageView.isHidden = true
            placeholderIconView.isHidden = true
            timeLabel.frame = bounds
            return
        }

        imageView.isHidden = false
        placeholderIconView.isHidden = mode != .placeholder
        let imageFrame = CGRect(
            x: 0,
            y: 0,
            width: bounds.width,
            height: bounds.height - Metric.labelHeight
        )
        imageView.frame = imageFrame
        placeholderIconView.bounds = CGRect(origin: .zero, size: Metric.placeholderIconSize)
        placeholderIconView.center = CGPoint(x: imageFrame.midX, y: imageFrame.midY)
        timeLabel.frame = CGRect(
            x: 0,
            y: bounds.height - Metric.labelHeight,
            width: bounds.width,
            height: Metric.labelHeight
        )
    }
}
