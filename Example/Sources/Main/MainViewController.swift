//
//  MainViewController.swift
//  VideoPlayerExample
//
//  Created by JunyoungJung on 2026/06/05.
//
//  진입 화면 — short URL 입력 후 플레이어 진입, 세팅 화면 이동.
//  컴포지션 루트: PlayerModuleProviding 구체(PlayerModuleProvider)를 여기서 주입한다.
//

import UIKit
import VideoPlayerCore

@MainActor
final class MainViewController: UIViewController {
    private let urlField = UITextField()
    private let playerButton = UIButton(configuration: .filled())
    private let settingsButton = UIButton(configuration: .tinted())
    private let resolver = ShortURLResolver()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "VideoPlayer Example"
        view.backgroundColor = .systemBackground
        configureLayout()
    }

    private func configureLayout() {
        urlField.borderStyle = .roundedRect
        urlField.autocapitalizationType = .none
        urlField.autocorrectionType = .no
        urlField.keyboardType = .URL
        urlField.clearButtonMode = .whileEditing
        urlField.placeholder = "Kollus short URL"
        urlField.text = "https://v.kr.kollus.com/YmJybQjF"   // 샘플 앱 기본 URL
        urlField.accessibilityIdentifier = "main.urlField"

        playerButton.configuration?.title = "플레이어"
        playerButton.accessibilityIdentifier = "main.playerButton"
        playerButton.addTarget(self, action: #selector(didTapPlayer), for: .touchUpInside)

        settingsButton.configuration?.title = "세팅"
        settingsButton.accessibilityIdentifier = "main.settingsButton"
        settingsButton.addTarget(self, action: #selector(didTapSettings), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [urlField, playerButton, settingsButton])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }

    // MARK: - Actions

    @objc private func didTapPlayer() {
        guard let shortURL = urlField.text, shortURL.isEmpty == false else {
            presentAlert(message: "short URL을 입력하세요.")
            return
        }
        playerButton.isEnabled = false
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.playerButton.isEnabled = true }
            do {
                let streamingURL = try await self.resolver.resolve(shortURL)
                let player = PlayerViewController(
                    source: .url(streamingURL),
                    moduleProvider: PlayerModuleProvider.shared
                )
                player.modalPresentationStyle = .fullScreen
                self.present(player, animated: false)   // 샘플과 동일: 풀스크린 present
            } catch {
                self.presentAlert(message: "재생 준비 실패: \(error.localizedDescription)")
            }
        }
    }

    @objc private func didTapSettings() {
        navigationController?.pushViewController(SettingViewController(), animated: true)
    }

    private func presentAlert(message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }
}
