//
//  RootViewController.swift
//  VideoPlayerExample
//
//  Created by 모바일팀_정준영 on 2026/05/17.
//

import UIKit
import VideoPlayerCore
import VideoPlayerEngineNative
import VideoPlayerShellSupport

final class RootViewController: UIViewController {
    private let urlTextField = UITextField()
    private let playButton = UIButton(type: .system)
    private let samplesStackView = UIStackView()
    private let kollusButton = UIButton(type: .system)
    private let statusLabel = UILabel()

    private static let sampleURLs: [(title: String, url: String)] = [
        (
            "Apple HLS (Basic Stream)",
            "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8"
        ),
        (
            "Big Buck Bunny (MP4)",
            "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
        )
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "VideoPlayer Example"
        view.backgroundColor = .systemBackground
        configureUI()
    }

    private func configureUI() {
        urlTextField.placeholder = "스트리밍 URL 입력 (https://...)"
        urlTextField.borderStyle = .roundedRect
        urlTextField.autocapitalizationType = .none
        urlTextField.autocorrectionType = .no
        urlTextField.keyboardType = .URL
        urlTextField.returnKeyType = .go
        urlTextField.delegate = self
        urlTextField.text = Self.sampleURLs.first?.url

        var playConfiguration = UIButton.Configuration.filled()
        playConfiguration.title = "재생 시작"
        playConfiguration.cornerStyle = .medium
        playButton.configuration = playConfiguration
        playButton.addTarget(self, action: #selector(didTapPlay), for: .touchUpInside)

        statusLabel.font = .systemFont(ofSize: 13, weight: .regular)
        statusLabel.textColor = .secondaryLabel
        statusLabel.numberOfLines = 0
        statusLabel.text = "샘플 URL을 선택하거나 직접 입력하세요."

        samplesStackView.axis = .vertical
        samplesStackView.spacing = 8

        for (index, sample) in Self.sampleURLs.enumerated() {
            let button = UIButton(type: .system)
            var configuration = UIButton.Configuration.tinted()
            configuration.title = sample.title
            configuration.subtitle = sample.url
            configuration.titleAlignment = .leading
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
            button.configuration = configuration
            button.contentHorizontalAlignment = .leading
            button.tag = index
            button.addTarget(self, action: #selector(didTapSample(_:)), for: .touchUpInside)
            samplesStackView.addArrangedSubview(button)
        }

        var kollusConfiguration = UIButton.Configuration.tinted()
        kollusConfiguration.title = "Kollus 데모"
        kollusConfiguration.subtitle = "mediaContentKey 기반 Kollus 엔진 데모"
        kollusConfiguration.cornerStyle = .medium
        kollusButton.configuration = kollusConfiguration
        kollusButton.contentHorizontalAlignment = .leading
        kollusButton.addTarget(self, action: #selector(didTapKollus), for: .touchUpInside)

        let rootStack = UIStackView(arrangedSubviews: [
            urlTextField,
            playButton,
            samplesStackView,
            kollusButton,
            statusLabel
        ])
        rootStack.axis = .vertical
        rootStack.spacing = 16
        rootStack.alignment = .fill

        view.addSubview(rootStack)
        rootStack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            rootStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            rootStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            rootStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }

    @objc
    private func didTapKollus() {
        let configVC = KollusConfigViewController()
        navigationController?.pushViewController(configVC, animated: true)
    }

    @objc
    private func didTapSample(_ sender: UIButton) {
        guard Self.sampleURLs.indices.contains(sender.tag) else {
            return
        }
        urlTextField.text = Self.sampleURLs[sender.tag].url
        statusLabel.text = "선택: \(Self.sampleURLs[sender.tag].title)"
    }

    @objc
    private func didTapPlay() {
        guard let rawText = urlTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              rawText.isEmpty == false,
              let url = URL(string: rawText),
              let scheme = url.scheme,
              scheme.hasPrefix("http") else {
            statusLabel.text = "유효한 http(s) URL을 입력하세요."
            return
        }

        statusLabel.text = "재생 준비 중..."
        Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            let viewController = await self.makeHighShellViewController(source: .url(url))
            self.navigationController?.pushViewController(viewController, animated: true)
            self.statusLabel.text = "재생 시작: \(url.absoluteString)"
        }
    }

    private func makeHighShellViewController(source: PlaybackSource) async -> HighPlayerShellViewController {
        let engine = AVPlayerAdapter()
        let module = await PlayerModuleWiring.makeModule(
            engine: engine,
            engineCapabilities: AVPlayerAdapter.capabilities
        )

        return HighPlayerShellViewController(
            playerModule: module,
            playbackSource: source
        )
    }
}

extension RootViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        didTapPlay()
        return true
    }
}
