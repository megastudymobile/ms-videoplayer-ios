//
//  CaptionPaneViewController.swift
//  VideoPlayerExample
//
//  Created by JunyoungJung on 2026/06/08.
//
//  자막 테스트 탭 — 표시 on/off, 크기 변경, 현재 자막 텍스트 미리보기.
//  자막 크기는 설정 탭 "자막 크기" 와 동일 소스(PreferenceManager.subtitleSize)를 공유한다 (단일 진실 소스).
//

import UIKit
import VideoPlayerCore
import VideoPlayerSkin

@MainActor
final class CaptionPaneViewController: UIViewController {
    private weak var channel: PlayerControlChannel?

    private let visibleSwitch = UISwitch()
    private let sizeControl = UISegmentedControl(items: SubtitleSize.allCases.map(\.title))
    private let previewLabel = UILabel()

    init(channel: PlayerControlChannel) {
        self.channel = channel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        configureLayout()
        syncFromPreferences()
    }

    private func configureLayout() {
        visibleSwitch.isOn = true
        visibleSwitch.addTarget(self, action: #selector(didToggleVisible), for: .valueChanged)
        let visibleRow = labeledRow(title: "자막 표시", accessory: visibleSwitch)

        sizeControl.addTarget(self, action: #selector(didChangeSize), for: .valueChanged)

        previewLabel.numberOfLines = 0
        previewLabel.textAlignment = .center
        previewLabel.textColor = .secondaryLabel
        previewLabel.font = .systemFont(ofSize: 15)
        previewLabel.text = "현재 자막 미리보기"

        let previewBox = UIView()
        previewBox.backgroundColor = .secondarySystemBackground
        previewBox.layer.cornerRadius = 12
        previewBox.translatesAutoresizingMaskIntoConstraints = false
        previewLabel.translatesAutoresizingMaskIntoConstraints = false
        previewBox.addSubview(previewLabel)
        NSLayoutConstraint.activate([
            previewLabel.topAnchor.constraint(equalTo: previewBox.topAnchor, constant: 16),
            previewLabel.bottomAnchor.constraint(equalTo: previewBox.bottomAnchor, constant: -16),
            previewLabel.leadingAnchor.constraint(equalTo: previewBox.leadingAnchor, constant: 16),
            previewLabel.trailingAnchor.constraint(equalTo: previewBox.trailingAnchor, constant: -16),
            previewBox.heightAnchor.constraint(greaterThanOrEqualToConstant: 80)
        ])

        let stack = UIStackView(arrangedSubviews: [
            visibleRow,
            sectionLabel("자막 크기"),
            sizeControl,
            sectionLabel("현재 자막"),
            previewBox
        ])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }

    private func syncFromPreferences() {
        sizeControl.selectedSegmentIndex = PreferenceManager.subtitleSize
    }

    // MARK: - Actions

    @objc private func didToggleVisible() {
        channel?.setCaptionHidden(visibleSwitch.isOn == false)
    }

    @objc private func didChangeSize() {
        let index = sizeControl.selectedSegmentIndex
        guard let size = SubtitleSize(rawValue: index) else { return }
        PreferenceManager.subtitleSize = size.rawValue   // 설정 탭과 공유하는 단일 소스
        channel?.setCaptionFontSize(size.fontSize)
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .secondaryLabel
        return label
    }

    private func labeledRow(title: String, accessory: UIView) -> UIView {
        let label = UILabel()
        label.text = title
        let row = UIStackView(arrangedSubviews: [label, UIView(), accessory])
        row.axis = .horizontal
        row.alignment = .center
        return row
    }
}

// MARK: - PlayerConsolePane

extension CaptionPaneViewController: PlayerConsolePane {
    func handleEvent(_ event: PlayerEvent) {
        guard case .captionDidUpdate(let text, let isSecondary) = event, isSecondary == false else { return }
        guard isViewLoaded else { return }
        previewLabel.text = text.isEmpty ? "(자막 없음)" : text
    }
}
