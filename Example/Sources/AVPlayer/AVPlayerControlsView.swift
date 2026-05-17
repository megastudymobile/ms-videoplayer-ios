//
//  AVPlayerControlsView.swift
//  VideoPlayerExample
//
//  Created by 모바일팀_정준영 on 2026/05/17.
//
//  Kollus 데모와 동일한 시각 패턴으로 AVPlayerAdapter가 노출하는 기능을 보여준다.
//  AVPlayer는 자막/잠금을 직접 다루지 않으므로 해당 컨트롤은 제외하고,
//  seek / 배속 / display scale 토글을 노출한다.
//

import UIKit

@MainActor
protocol AVPlayerControlsViewDelegate: AnyObject {
    func avPlayerControlsViewDidTapPlayPause(_ view: AVPlayerControlsView)
    func avPlayerControlsViewDidTapStop(_ view: AVPlayerControlsView)
    func avPlayerControlsView(_ view: AVPlayerControlsView, didRequestSeekProgress progress: Double)
    func avPlayerControlsView(_ view: AVPlayerControlsView, didSelectPlaybackRate rate: Double)
    func avPlayerControlsView(_ view: AVPlayerControlsView, didSetDisplayScaled isScaled: Bool)
    func avPlayerControlsViewDidTapClose(_ view: AVPlayerControlsView)
}

final class AVPlayerControlsView: UIView {
    weak var delegate: AVPlayerControlsViewDelegate?

    private let statusLabel = UILabel()
    private let timeLabel = UILabel()
    private let playPauseButton = UIButton(type: .system)
    private let stopButton = UIButton(type: .system)
    private let closeButton = UIButton(type: .system)
    private let progressSlider = UISlider()
    private let rateSegmentedControl = UISegmentedControl()
    private let displayScaleSwitch = UISwitch()
    private let errorLabel = UILabel()
    private let stackView = UIStackView()

    private(set) var renderedState: AVPlayerControlState?

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func render(state: AVPlayerControlState) {
        renderedState = state

        statusLabel.text = state.statusText
        timeLabel.text = state.timeText
        playPauseButton.setTitle(state.playPauseTitle, for: .normal)
        playPauseButton.isEnabled = state.isPlayPauseEnabled
        stopButton.isEnabled = state.isStopEnabled
        progressSlider.isEnabled = state.isSeekEnabled
        progressSlider.value = Float(state.progress)
        displayScaleSwitch.isOn = state.isDisplayScaled
        errorLabel.text = state.errorMessage
        errorLabel.isHidden = state.errorMessage == nil

        configureRates(state.allowedRates, selectedRate: state.selectedRate)
        rateSegmentedControl.isEnabled = state.isRateSelectionEnabled
    }

    private func configureUI() {
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 8

        statusLabel.accessibilityIdentifier = "avPlayer.statusLabel"
        statusLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        statusLabel.textColor = .label
        statusLabel.text = "대기"

        timeLabel.accessibilityIdentifier = "avPlayer.timeLabel"
        timeLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        timeLabel.textColor = .secondaryLabel
        timeLabel.text = "00:00 / 00:00"

        playPauseButton.accessibilityIdentifier = "avPlayer.playPauseButton"
        playPauseButton.setTitle("Play", for: .normal)
        playPauseButton.addTarget(self, action: #selector(didTapPlayPause), for: .touchUpInside)

        stopButton.accessibilityIdentifier = "avPlayer.stopButton"
        stopButton.setTitle("Stop", for: .normal)
        stopButton.addTarget(self, action: #selector(didTapStop), for: .touchUpInside)

        closeButton.accessibilityIdentifier = "avPlayer.closeButton"
        closeButton.setTitle("Close", for: .normal)
        closeButton.addTarget(self, action: #selector(didTapClose), for: .touchUpInside)

        progressSlider.accessibilityIdentifier = "avPlayer.progressSlider"
        progressSlider.minimumValue = 0
        progressSlider.maximumValue = 1
        progressSlider.addTarget(self, action: #selector(didChangeProgress), for: .valueChanged)

        rateSegmentedControl.accessibilityIdentifier = "avPlayer.rateSegmentedControl"
        rateSegmentedControl.addTarget(self, action: #selector(didSelectRate), for: .valueChanged)

        displayScaleSwitch.accessibilityIdentifier = "avPlayer.displayScaleSwitch"
        displayScaleSwitch.addTarget(self, action: #selector(didToggleDisplayScale), for: .valueChanged)

        errorLabel.accessibilityIdentifier = "avPlayer.errorLabel"
        errorLabel.font = .systemFont(ofSize: 13, weight: .regular)
        errorLabel.textColor = .systemRed
        errorLabel.numberOfLines = 0
        errorLabel.isHidden = true

        let headerStack = UIStackView(arrangedSubviews: [statusLabel, UIView(), closeButton])
        headerStack.axis = .horizontal
        headerStack.alignment = .center
        headerStack.spacing = 8

        let actionStack = UIStackView(arrangedSubviews: [playPauseButton, stopButton, rateSegmentedControl])
        actionStack.axis = .horizontal
        actionStack.alignment = .center
        actionStack.distribution = .fill
        actionStack.spacing = 12

        let scaleStack = makeSettingStack(title: "화면 스케일", control: displayScaleSwitch)

        stackView.axis = .vertical
        stackView.spacing = 10
        stackView.addArrangedSubview(headerStack)
        stackView.addArrangedSubview(timeLabel)
        stackView.addArrangedSubview(progressSlider)
        stackView.addArrangedSubview(actionStack)
        stackView.addArrangedSubview(scaleStack)
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
        delegate?.avPlayerControlsViewDidTapPlayPause(self)
    }

    @objc
    private func didTapStop() {
        delegate?.avPlayerControlsViewDidTapStop(self)
    }

    @objc
    private func didTapClose() {
        delegate?.avPlayerControlsViewDidTapClose(self)
    }

    @objc
    private func didChangeProgress() {
        delegate?.avPlayerControlsView(self, didRequestSeekProgress: Double(progressSlider.value))
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

        delegate?.avPlayerControlsView(
            self,
            didSelectPlaybackRate: state.allowedRates[rateSegmentedControl.selectedSegmentIndex]
        )
    }

    @objc
    private func didToggleDisplayScale() {
        delegate?.avPlayerControlsView(self, didSetDisplayScaled: displayScaleSwitch.isOn)
    }

    private static func format(rate: Double) -> String {
        if rate.rounded() == rate {
            return "\(Int(rate))x"
        }
        return String(format: "%.2gx", rate)
    }
}
