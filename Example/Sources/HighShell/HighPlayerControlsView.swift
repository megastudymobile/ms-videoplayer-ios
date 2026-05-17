//
//  HighPlayerControlsView.swift
//  VideoPlayerExample
//
//  Created by 모바일팀_정준영 on 2026/05/17.
//

import UIKit
import VideoPlayerCore

@MainActor
protocol HighPlayerControlsViewDelegate: AnyObject {
    func highPlayerControlsViewDidTapPlayPause(_ view: HighPlayerControlsView)
    func highPlayerControlsViewDidTapStop(_ view: HighPlayerControlsView)
}

final class HighPlayerControlsView: UIView {
    weak var delegate: HighPlayerControlsViewDelegate?

    private let stateLabel = UILabel()
    private let timeLabel = UILabel()
    private let playPauseButton = UIButton(type: .system)
    private let stopButton = UIButton(type: .system)
    private let stackView = UIStackView()

    private(set) var isPlaying = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func render(state: PlaybackState) {
        switch state.status {
        case .idle:
            stateLabel.text = "대기"
            isPlaying = false
        case .preparing:
            stateLabel.text = "준비 중"
            isPlaying = false
        case .readyToPlay:
            stateLabel.text = "재생 준비 완료"
            isPlaying = false
        case .playing:
            stateLabel.text = "재생 중"
            isPlaying = true
        case .paused:
            stateLabel.text = "일시정지"
            isPlaying = false
        case .buffering:
            stateLabel.text = "버퍼링"
            isPlaying = true
        case .finished:
            stateLabel.text = "재생 완료"
            isPlaying = false
        case .failed(let error):
            stateLabel.text = "오류: \(error.localizedDescription)"
            isPlaying = false
        }

        playPauseButton.setTitle(isPlaying ? "Pause" : "Play", for: .normal)
        timeLabel.text = Self.formatTime(currentTime: state.currentTime, duration: state.duration)
    }

    private func configureUI() {
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 8

        stateLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        stateLabel.textColor = .label
        stateLabel.text = "대기"

        timeLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        timeLabel.textColor = .secondaryLabel
        timeLabel.text = "00:00 / 00:00"

        playPauseButton.setTitle("Play", for: .normal)
        playPauseButton.addTarget(self, action: #selector(didTapPlayPause), for: .touchUpInside)

        stopButton.setTitle("Stop", for: .normal)
        stopButton.addTarget(self, action: #selector(didTapStop), for: .touchUpInside)

        let infoStack = UIStackView(arrangedSubviews: [stateLabel, timeLabel])
        infoStack.axis = .vertical
        infoStack.spacing = 4

        let buttonStack = UIStackView(arrangedSubviews: [playPauseButton, stopButton])
        buttonStack.axis = .horizontal
        buttonStack.spacing = 12

        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.distribution = .equalSpacing
        stackView.addArrangedSubview(infoStack)
        stackView.addArrangedSubview(buttonStack)

        addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
        ])
    }

    @objc
    private func didTapPlayPause() {
        delegate?.highPlayerControlsViewDidTapPlayPause(self)
    }

    @objc
    private func didTapStop() {
        delegate?.highPlayerControlsViewDidTapStop(self)
    }

    private static func formatTime(currentTime: TimeInterval, duration: TimeInterval) -> String {
        "\(format(seconds: currentTime)) / \(format(seconds: duration))"
    }

    private static func format(seconds: TimeInterval) -> String {
        let safeSeconds = max(0, Int(seconds))
        let minutes = safeSeconds / 60
        let remains = safeSeconds % 60
        return String(format: "%02d:%02d", minutes, remains)
    }
}
