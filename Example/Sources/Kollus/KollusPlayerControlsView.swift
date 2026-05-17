//
//  KollusPlayerControlsView.swift
//  VideoPlayerExample
//
//  Created by 모바일팀_정준영 on 2026/05/17.
//
//  smartlearning LearningPlayerControlsView UI 시각적 복제.
//

import UIKit

@MainActor
protocol KollusPlayerControlsViewDelegate: AnyObject {
    func kollusPlayerControlsViewDidTapPlayPause(_ view: KollusPlayerControlsView)
    func kollusPlayerControlsView(_ view: KollusPlayerControlsView, didRequestSeekProgress progress: Double)
    func kollusPlayerControlsView(_ view: KollusPlayerControlsView, didSelectPlaybackRate rate: Double)
    func kollusPlayerControlsView(_ view: KollusPlayerControlsView, didSetSubtitleVisible isVisible: Bool)
    func kollusPlayerControlsView(_ view: KollusPlayerControlsView, didSetCaptionFontSize fontSize: Int)
    func kollusPlayerControlsView(_ view: KollusPlayerControlsView, didSetDisplayLocked isLocked: Bool)
    func kollusPlayerControlsViewDidTapClose(_ view: KollusPlayerControlsView)
}

final class KollusPlayerControlsView: UIView {
    weak var delegate: KollusPlayerControlsViewDelegate?

    private let statusLabel = UILabel()
    private let timeLabel = UILabel()
    private let playPauseButton = UIButton(type: .system)
    private let closeButton = UIButton(type: .system)
    private let progressSlider = UISlider()
    private let rateSegmentedControl = UISegmentedControl()
    private let subtitleSwitch = UISwitch()
    private let captionSizeLabel = UILabel()
    private let captionSizeStepper = UIStepper()
    private let displayLockSwitch = UISwitch()
    private let errorLabel = UILabel()
    private let stackView = UIStackView()

    private(set) var renderedState: KollusPlayerControlState?

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func render(state: KollusPlayerControlState) {
        renderedState = state

        statusLabel.text = state.statusText
        timeLabel.text = state.timeText
        playPauseButton.setTitle(state.playPauseTitle, for: .normal)
        playPauseButton.isEnabled = state.isPlayPauseEnabled
        progressSlider.isEnabled = state.isSeekEnabled
        progressSlider.value = Float(state.progress)
        subtitleSwitch.isOn = state.isSubtitleVisible
        captionSizeLabel.text = "자막 \(state.captionFontSize)P"
        captionSizeStepper.value = Double(state.captionFontSize)
        displayLockSwitch.isOn = state.isDisplayLocked
        errorLabel.text = state.errorMessage
        errorLabel.isHidden = state.errorMessage == nil
        closeButton.isEnabled = true

        configureRates(state.allowedRates, selectedRate: state.selectedRate)
        rateSegmentedControl.isEnabled = state.isRateSelectionEnabled
    }

    private func configureUI() {
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 8

        statusLabel.accessibilityIdentifier = "kollusPlayer.statusLabel"
        statusLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        statusLabel.textColor = .label
        statusLabel.text = "대기"

        timeLabel.accessibilityIdentifier = "kollusPlayer.timeLabel"
        timeLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        timeLabel.textColor = .secondaryLabel
        timeLabel.text = "00:00 / 00:00"

        playPauseButton.accessibilityIdentifier = "kollusPlayer.playPauseButton"
        playPauseButton.setTitle("Play", for: .normal)
        playPauseButton.addTarget(self, action: #selector(didTapPlayPause), for: .touchUpInside)

        closeButton.accessibilityIdentifier = "kollusPlayer.closeButton"
        closeButton.setTitle("Close", for: .normal)
        closeButton.addTarget(self, action: #selector(didTapClose), for: .touchUpInside)

        progressSlider.accessibilityIdentifier = "kollusPlayer.progressSlider"
        progressSlider.minimumValue = 0
        progressSlider.maximumValue = 1
        progressSlider.addTarget(self, action: #selector(didChangeProgress), for: .valueChanged)

        rateSegmentedControl.accessibilityIdentifier = "kollusPlayer.rateSegmentedControl"
        rateSegmentedControl.addTarget(self, action: #selector(didSelectRate), for: .valueChanged)

        subtitleSwitch.accessibilityIdentifier = "kollusPlayer.subtitleSwitch"
        subtitleSwitch.addTarget(self, action: #selector(didToggleSubtitle), for: .valueChanged)

        captionSizeLabel.accessibilityIdentifier = "kollusPlayer.captionSizeLabel"
        captionSizeLabel.font = .systemFont(ofSize: 13, weight: .regular)
        captionSizeLabel.textColor = .secondaryLabel
        captionSizeLabel.text = "자막 16P"

        captionSizeStepper.accessibilityIdentifier = "kollusPlayer.captionSizeStepper"
        captionSizeStepper.minimumValue = 12
        captionSizeStepper.maximumValue = 30
        captionSizeStepper.stepValue = 1
        captionSizeStepper.addTarget(self, action: #selector(didChangeCaptionSize), for: .valueChanged)

        displayLockSwitch.accessibilityIdentifier = "kollusPlayer.displayLockSwitch"
        displayLockSwitch.addTarget(self, action: #selector(didToggleDisplayLock), for: .valueChanged)

        errorLabel.accessibilityIdentifier = "kollusPlayer.errorLabel"
        errorLabel.font = .systemFont(ofSize: 13, weight: .regular)
        errorLabel.textColor = .systemRed
        errorLabel.numberOfLines = 0
        errorLabel.isHidden = true

        let headerStack = UIStackView(arrangedSubviews: [statusLabel, UIView(), closeButton])
        headerStack.axis = .horizontal
        headerStack.alignment = .center
        headerStack.spacing = 8

        let actionStack = UIStackView(arrangedSubviews: [playPauseButton, rateSegmentedControl])
        actionStack.axis = .horizontal
        actionStack.alignment = .center
        actionStack.distribution = .fill
        actionStack.spacing = 12

        let subtitleStack = makeSettingStack(title: "AI 자막", control: subtitleSwitch)
        let captionSizeStack = UIStackView(arrangedSubviews: [captionSizeLabel, captionSizeStepper])
        captionSizeStack.axis = .horizontal
        captionSizeStack.alignment = .center
        captionSizeStack.distribution = .equalSpacing
        captionSizeStack.spacing = 12
        let displayLockStack = makeSettingStack(title: "화면 잠금", control: displayLockSwitch)

        stackView.axis = .vertical
        stackView.spacing = 10
        stackView.addArrangedSubview(headerStack)
        stackView.addArrangedSubview(timeLabel)
        stackView.addArrangedSubview(progressSlider)
        stackView.addArrangedSubview(actionStack)
        stackView.addArrangedSubview(subtitleStack)
        stackView.addArrangedSubview(captionSizeStack)
        stackView.addArrangedSubview(displayLockStack)
        stackView.addArrangedSubview(errorLabel)

        addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
        ])
    }

    private func configureRates(_ rates: [Double], selectedRate: Double) {
        let existingTitles = (0..<rateSegmentedControl.numberOfSegments).map {
            rateSegmentedControl.titleForSegment(at: $0) ?? ""
        }
        let nextTitles = rates.map { Self.format(rate: $0) }

        if existingTitles != nextTitles {
            rateSegmentedControl.removeAllSegments()
            nextTitles.enumerated().forEach { index, title in
                rateSegmentedControl.insertSegment(withTitle: title, at: index, animated: false)
            }
        }

        if let selectedIndex = rates.firstIndex(of: selectedRate) {
            rateSegmentedControl.selectedSegmentIndex = selectedIndex
        } else {
            rateSegmentedControl.selectedSegmentIndex = UISegmentedControl.noSegment
        }
    }

    private func makeSettingStack(title: String, control: UIView) -> UIStackView {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.textColor = .secondaryLabel
        label.text = title

        let stack = UIStackView(arrangedSubviews: [label, control])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.distribution = .equalSpacing
        stack.spacing = 12
        return stack
    }

    @objc
    private func didTapPlayPause() {
        delegate?.kollusPlayerControlsViewDidTapPlayPause(self)
    }

    @objc
    private func didChangeProgress() {
        delegate?.kollusPlayerControlsView(self, didRequestSeekProgress: Double(progressSlider.value))
    }

    @objc
    private func didSelectRate() {
        guard
            let state = renderedState,
            rateSegmentedControl.selectedSegmentIndex >= 0,
            rateSegmentedControl.selectedSegmentIndex < state.allowedRates.count
        else {
            return
        }

        delegate?.kollusPlayerControlsView(
            self,
            didSelectPlaybackRate: state.allowedRates[rateSegmentedControl.selectedSegmentIndex]
        )
    }

    @objc
    private func didToggleSubtitle() {
        delegate?.kollusPlayerControlsView(self, didSetSubtitleVisible: subtitleSwitch.isOn)
    }

    @objc
    private func didChangeCaptionSize() {
        delegate?.kollusPlayerControlsView(self, didSetCaptionFontSize: Int(captionSizeStepper.value))
    }

    @objc
    private func didToggleDisplayLock() {
        delegate?.kollusPlayerControlsView(self, didSetDisplayLocked: displayLockSwitch.isOn)
    }

    @objc
    private func didTapClose() {
        delegate?.kollusPlayerControlsViewDidTapClose(self)
    }

    private static func format(rate: Double) -> String {
        if rate.rounded() == rate {
            return "\(Int(rate))x"
        }
        return String(format: "%.2gx", rate)
    }
}
