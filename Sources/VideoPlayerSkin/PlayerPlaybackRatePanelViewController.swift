//
//  PlayerPlaybackRatePanelViewController.swift
//  SmartPlayer
//
//  Created by 모바일팀_정준영 on 2026/05/29.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import UIKit

/// 배속 상세 패널. 슬라이더 + ±스텝 + preset 버튼으로 배속을 변경한다.
/// 선택 가능한 배속은 host가 주입한 `availableRates` 목록으로 한정된다 —
/// 슬라이더·±버튼 모두 목록 안의 값으로만 스냅된다.
/// 배경 tap·preset 선택 시 dismiss, slider/± 조작 시에는 dismiss 하지 않는다.
@MainActor
public final class PlayerPlaybackRatePanelViewController: UIViewController {

    /// 사용자가 배속을 변경했을 때 호출. `shouldDismiss` 가 true 면 패널이 자동으로 닫힌다.
    public var onSelectRate: ((Double, _ shouldDismiss: Bool) -> Void)?

    /// 배경 또는 닫기 영역 tap 시.
    public var onDismiss: (() -> Void)?

    private let initialRate: Double
    private let availableRates: [Float]
    private let isFullScreenMode: Bool
    private let anchorFrameInPresenter: CGRect?

    public init(
        initialRate: Double,
        availableRates: [Double],
        isFullScreenMode: Bool = false,
        anchorFrameInPresenter: CGRect? = nil
    ) {
        self.initialRate = initialRate
        // 양수만, 중복 제거 후 오름차순. 비면 1.0 단일 — 정책(PlayerFeaturePolicy)과 같은 정규화.
        let normalized = Array(Set(availableRates.filter { $0 > 0 })).sorted().map(Float.init)
        self.availableRates = normalized.isEmpty ? [1.0] : normalized
        self.isFullScreenMode = isFullScreenMode
        self.anchorFrameInPresenter = anchorFrameInPresenter
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Subviews

    private let dimmingView = UIView()
    private let cardView = UIView()
    private let rateLabel = UILabel()
    private let minusButton = UIButton(type: .custom)
    private let plusButton = UIButton(type: .custom)
    private let slider = UISlider()
    private let minCaptionLabel = UILabel()
    private let maxCaptionLabel = UILabel()
    private let presetStackView = UIStackView()
    private var presetButtons: [UIButton] = []

    // MARK: - State

    private var playbackRate: Float = 1.0 {
        didSet { refreshRateUI(animated: false) }
    }

    private var isSyncingSlider = false

    private var minRate: Float { availableRates.first ?? 1.0 }

    private var maxRate: Float { availableRates.last ?? 1.0 }

    private var isPadDevice: Bool {
        traitCollection.userInterfaceIdiom == .pad
    }

    // MARK: - Lifecycle

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        playbackRate = snapToAllowed(Float(initialRate))

        configureHierarchy()
        configureAppearance()
        configureActions()
        rebuildPresetButtons()
        refreshRateUI(animated: false)
    }

    // MARK: - Layout

    private func configureHierarchy() {
        dimmingView.translatesAutoresizingMaskIntoConstraints = false
        cardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(dimmingView)
        view.addSubview(cardView)

        NSLayoutConstraint.activate([
            dimmingView.topAnchor.constraint(equalTo: view.topAnchor),
            dimmingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimmingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dimmingView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        let panelWidth = isPadDevice ? Metrics.padPanelWidth : Metrics.phonePanelWidth
        let panelHeight = isPadDevice ? Metrics.padPanelHeight : Metrics.phonePanelHeight

        var cardConstraints: [NSLayoutConstraint] = [
            cardView.widthAnchor.constraint(equalToConstant: panelWidth),
            cardView.heightAnchor.constraint(equalToConstant: panelHeight)
        ]
        if isFullScreenMode {
            cardConstraints.append(contentsOf: [
                cardView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
                cardView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
            ])
        } else if let anchorFrameInPresenter {
            cardConstraints.append(contentsOf: [
                cardView.topAnchor.constraint(equalTo: view.topAnchor, constant: anchorFrameInPresenter.maxY + 12),
                cardView.trailingAnchor.constraint(equalTo: view.leadingAnchor, constant: anchorFrameInPresenter.maxX - 15)
            ])
            cardConstraints.append(cardView.leadingAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16))
        } else {
            cardConstraints.append(contentsOf: [
                cardView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                cardView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
            ])
        }
        NSLayoutConstraint.activate(cardConstraints)

        let topRow = UIView()
        topRow.translatesAutoresizingMaskIntoConstraints = false
        topRow.addSubview(minusButton)
        topRow.addSubview(rateLabel)
        topRow.addSubview(plusButton)

        minusButton.translatesAutoresizingMaskIntoConstraints = false
        plusButton.translatesAutoresizingMaskIntoConstraints = false
        rateLabel.translatesAutoresizingMaskIntoConstraints = false

        let captionRow = UIStackView(arrangedSubviews: [minCaptionLabel, maxCaptionLabel])
        captionRow.axis = .horizontal
        captionRow.distribution = .equalSpacing
        captionRow.alignment = .center

        let middleColumn = UIStackView(arrangedSubviews: [slider, captionRow])
        middleColumn.axis = .vertical
        middleColumn.spacing = Metrics.sliderToCaptionSpacing

        let mainColumn = UIStackView(arrangedSubviews: [topRow, middleColumn, presetStackView])
        mainColumn.axis = .vertical
        mainColumn.spacing = isPadDevice ? Metrics.middleToPresetSpacingPad : Metrics.middleToPresetSpacingPhone
        mainColumn.isLayoutMarginsRelativeArrangement = true
        mainColumn.layoutMargins = Metrics.contentLayoutMargins(isPad: isPadDevice)
        mainColumn.translatesAutoresizingMaskIntoConstraints = false

        cardView.addSubview(mainColumn)

        NSLayoutConstraint.activate([
            mainColumn.topAnchor.constraint(equalTo: cardView.topAnchor),
            mainColumn.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            mainColumn.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
            mainColumn.bottomAnchor.constraint(equalTo: cardView.bottomAnchor),

            rateLabel.centerXAnchor.constraint(equalTo: topRow.centerXAnchor),
            rateLabel.centerYAnchor.constraint(equalTo: topRow.centerYAnchor),

            minusButton.centerYAnchor.constraint(equalTo: topRow.centerYAnchor),
            minusButton.trailingAnchor.constraint(equalTo: topRow.centerXAnchor, constant: -60),
            minusButton.heightAnchor.constraint(equalToConstant: 25),
            minusButton.widthAnchor.constraint(equalToConstant: 25),

            plusButton.centerYAnchor.constraint(equalTo: topRow.centerYAnchor),
            plusButton.leadingAnchor.constraint(equalTo: topRow.centerXAnchor, constant: 60),
            plusButton.heightAnchor.constraint(equalToConstant: 25),
            plusButton.widthAnchor.constraint(equalToConstant: 25),

            topRow.heightAnchor.constraint(greaterThanOrEqualToConstant: 30)
        ])

        presetStackView.axis = .horizontal
        presetStackView.spacing = Metrics.presetRowSpacing
        presetStackView.distribution = .fillEqually
        presetStackView.alignment = .fill
    }

    private func configureAppearance() {
        dimmingView.backgroundColor = UIColor.black.withAlphaComponent(0.3)

        cardView.backgroundColor = UIColor(named: "Grey11") ?? UIColor(white: 0.1, alpha: 1.0)
        cardView.layer.cornerRadius = Metrics.contentCornerRadius
        cardView.layer.masksToBounds = true

        let rateFontSize = isPadDevice ? Metrics.rateLabelPadFontSize : Metrics.rateLabelPhoneFontSize
        rateLabel.font = UIFont(name: "AppleSDGothicNeo-Bold", size: rateFontSize)
            ?? .systemFont(ofSize: rateFontSize, weight: .bold)
        rateLabel.textColor = UIColor(named: "White-03") ?? UIColor.white.withAlphaComponent(0.9)
        rateLabel.textAlignment = .center

        minusButton.setImage(UIImage(named: "PlayerRateMinusButton"), for: .normal)
        plusButton.setImage(UIImage(named: "PlayerRatePlusButton"), for: .normal)
        // 호스트 앱 번들에 asset 이 없을 수 있어 text fallback 을 둔다.
        if minusButton.image(for: .normal) == nil {
            minusButton.setTitle("−", for: .normal)
            minusButton.setTitleColor(.white, for: .normal)
            minusButton.titleLabel?.font = .systemFont(ofSize: 22, weight: .regular)
        }
        if plusButton.image(for: .normal) == nil {
            plusButton.setTitle("+", for: .normal)
            plusButton.setTitleColor(.white, for: .normal)
            plusButton.titleLabel?.font = .systemFont(ofSize: 22, weight: .regular)
        }

        slider.minimumValue = minRate
        slider.maximumValue = maxRate
        slider.value = playbackRate
        slider.minimumTrackTintColor = UIColor(named: "primarySkyBlue") ?? .systemBlue
        slider.maximumTrackTintColor = UIColor(named: "grey26") ?? UIColor.white.withAlphaComponent(0.25)

        let thumb = Self.circularSliderThumbImage(
            diameter: Metrics.sliderThumbDiameter,
            fillColor: UIColor(named: "White-03") ?? UIColor.white
        )
        slider.setThumbImage(thumb, for: .normal)
        slider.setThumbImage(thumb, for: .highlighted)

        let captionFontSize = isPadDevice ? Metrics.captionPadFontSize : Metrics.captionPhoneFontSize
        let captionFont = UIFont(name: "AppleSDGothicNeo-Regular", size: captionFontSize)
            ?? .systemFont(ofSize: captionFontSize, weight: .regular)
        let captionColor = (UIColor(named: "White-03") ?? UIColor.white).withAlphaComponent(Metrics.captionAlpha)
        minCaptionLabel.font = captionFont
        maxCaptionLabel.font = captionFont
        minCaptionLabel.textColor = captionColor
        maxCaptionLabel.textColor = captionColor
        minCaptionLabel.textAlignment = .left
        maxCaptionLabel.textAlignment = .right
        minCaptionLabel.text = Self.captionText(for: minRate)
        maxCaptionLabel.text = Self.captionText(for: maxRate)
    }

    private func configureActions() {
        let dimTap = UITapGestureRecognizer(target: self, action: #selector(handleDimmingTap))
        dimmingView.addGestureRecognizer(dimTap)

        minusButton.addTarget(self, action: #selector(handleMinusTap), for: .touchUpInside)
        plusButton.addTarget(self, action: #selector(handlePlusTap), for: .touchUpInside)
        slider.addTarget(self, action: #selector(handleSliderChanged(_:)), for: .valueChanged)
        slider.addTarget(self, action: #selector(handleSliderFinished(_:)),
                         for: [.touchUpInside, .touchUpOutside])
    }

    private func rebuildPresetButtons() {
        presetButtons.forEach { $0.removeFromSuperview() }
        presetButtons.removeAll()

        for view in presetStackView.arrangedSubviews {
            presetStackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        let presets: [Float] = availableRates

        let height = isPadDevice ? Metrics.presetButtonHeightPad : Metrics.presetButtonHeightPhone
        let fontSize = isPadDevice ? Metrics.presetButtonPadFontSize : Metrics.presetButtonPhoneFontSize
        let titleColor = UIColor(named: "White-03") ?? UIColor.white
        let bgColor = UIColor(named: "Grey19") ?? UIColor(white: 0.18, alpha: 1.0)

        for rate in presets {
            let button = UIButton(type: .custom)
            button.translatesAutoresizingMaskIntoConstraints = false
            button.setTitle(String(format: "%.1f", rate), for: .normal)
            button.setTitleColor(titleColor, for: .normal)
            button.titleLabel?.font = UIFont(name: "AppleSDGothicNeo-SemiBold", size: fontSize)
                ?? .systemFont(ofSize: fontSize, weight: .semibold)
            button.backgroundColor = bgColor
            button.layer.cornerRadius = height * 0.5
            button.layer.masksToBounds = true
            button.tag = Int(rate * 100)
            button.addTarget(self, action: #selector(handlePresetTap(_:)), for: .touchUpInside)
            presetStackView.addArrangedSubview(button)
            button.heightAnchor.constraint(equalToConstant: height).isActive = true
            presetButtons.append(button)
        }
    }

    // MARK: - Actions

    @objc private func handleDimmingTap() {
        onDismiss?()
    }

    @objc private func handleMinusTap() {
        stepPlaybackRate(direction: -1)
    }

    @objc private func handlePlusTap() {
        stepPlaybackRate(direction: +1)
    }

    @objc private func handleSliderChanged(_ sender: UISlider) {
        guard !isSyncingSlider else { return }
        let snapped = snapToAllowed(sender.value)
        rateLabel.text = Self.rateText(for: snapped)
    }

    @objc private func handleSliderFinished(_ sender: UISlider) {
        guard !isSyncingSlider else { return }
        let snapped = snapToAllowed(sender.value)
        sender.value = snapped
        if snapped != playbackRate {
            playbackRate = snapped
            onSelectRate?(Double(snapped), false)
        }
    }

    @objc private func handlePresetTap(_ sender: UIButton) {
        let raw = Float(sender.tag) / 100.0
        let snapped = snapToAllowed(raw)
        guard snapped != playbackRate else {
            onSelectRate?(Double(snapped), true)
            return
        }
        playbackRate = snapped
        onSelectRate?(Double(snapped), true)
    }

    private func stepPlaybackRate(direction: Int) {
        guard let index = availableRates.firstIndex(of: snapToAllowed(playbackRate)) else { return }
        let nextIndex = index + direction
        guard availableRates.indices.contains(nextIndex) else { return }
        let next = availableRates[nextIndex]
        guard next != playbackRate else { return }
        playbackRate = next
        onSelectRate?(Double(next), false)
    }

    /// 주입된 허용 배속 중 가장 가까운 값으로 스냅한다.
    private func snapToAllowed(_ value: Float) -> Float {
        availableRates.min(by: { abs($0 - value) < abs($1 - value) }) ?? 1.0
    }

    private func refreshRateUI(animated: Bool) {
        rateLabel.text = Self.rateText(for: playbackRate)
        isSyncingSlider = true
        let updates = { [slider] in slider.value = self.playbackRate }
        if animated {
            UIView.animate(withDuration: Metrics.syncAnimationDuration, animations: updates)
        } else {
            updates()
        }
        isSyncingSlider = false
    }

    // MARK: - Static helpers

    private static func rateText(for rate: Float) -> String {
        String(format: "%.1fx", roundOneDecimal(rate))
    }

    private static func captionText(for rate: Float) -> String {
        String(format: "%.1fx", roundOneDecimal(rate))
    }

    private static func roundOneDecimal(_ value: Float) -> Float {
        (value * 10).rounded() / 10
    }

    private static func circularSliderThumbImage(diameter: CGFloat, fillColor: UIColor) -> UIImage {
        let size = CGSize(width: diameter, height: diameter)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: size)
            fillColor.setFill()
            ctx.cgContext.fillEllipse(in: rect)
        }
    }
}

// MARK: - Metrics

private extension PlayerPlaybackRatePanelViewController {
    enum Metrics {
        static let phonePanelWidth: CGFloat = 343
        static let phonePanelHeight: CGFloat = 166
        static let padPanelWidth: CGFloat = 420
        static let padPanelHeight: CGFloat = 186

        static let contentCornerRadius: CGFloat = 6.7

        static let contentHorizontalPadding: CGFloat = 20
        static let contentVerticalPaddingPhone: CGFloat = 24
        static let contentVerticalPaddingPad: CGFloat = 28

        static let middleToPresetSpacingPhone: CGFloat = 16
        static let middleToPresetSpacingPad: CGFloat = 18
        static let sliderToCaptionSpacing: CGFloat = 4
        static let presetRowSpacing: CGFloat = 8

        static let rateLabelPhoneFontSize: CGFloat = 22
        static let rateLabelPadFontSize: CGFloat = 24
        static let captionPhoneFontSize: CGFloat = 12
        static let captionPadFontSize: CGFloat = 13
        static let captionAlpha: CGFloat = 0.7

        static let presetButtonPhoneFontSize: CGFloat = 15
        static let presetButtonPadFontSize: CGFloat = 16
        static let presetButtonHeightPhone: CGFloat = 32
        static let presetButtonHeightPad: CGFloat = 36

        static let syncAnimationDuration: TimeInterval = 0.15
        static let sliderThumbDiameter: CGFloat = 16

        static func contentLayoutMargins(isPad: Bool) -> UIEdgeInsets {
            let vertical = isPad ? contentVerticalPaddingPad : contentVerticalPaddingPhone
            return UIEdgeInsets(
                top: vertical,
                left: contentHorizontalPadding,
                bottom: vertical,
                right: contentHorizontalPadding
            )
        }
    }
}
