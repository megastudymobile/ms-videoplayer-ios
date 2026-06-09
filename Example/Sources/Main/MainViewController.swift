//
//  MainViewController.swift
//  VideoPlayerExample
//
//  Created by JunyoungJung on 2026/06/05.
//
//  진입 화면 — short URL 입력 후 플레이어 + 테스트 콘솔 화면으로 진입.
//  컴포지션 루트: PlayerModuleProviding 구체(PlayerModuleProvider)를 여기서 주입한다.
//

import UIKit
import VideoPlayerCore

@MainActor
final class MainViewController: UIViewController {
    private let urlField = UITextField()
    private let playerButton = UIButton(configuration: .filled())
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

        let stack = UIStackView(arrangedSubviews: [urlField, playerButton])
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
        // 빠른 더블탭으로 컨테이너가 두 번 push 되는 것을 차단.
        guard navigationController?.topViewController === self else { return }
        playerButton.isEnabled = false
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.playerButton.isEnabled = true }
            do {
                let streamingURL = try await self.resolver.resolve(shortURL)
                guard self.navigationController?.topViewController === self else { return }
                let container = PlayerTestConsoleContainerViewController(
                    source: .url(streamingURL),
                    moduleProvider: PlayerModuleProvider.shared
                )
                self.navigationController?.pushViewController(container, animated: true)
            } catch {
                self.presentAlert(message: "재생 준비 실패: \(error.localizedDescription)")
            }
        }
    }

    private func presentAlert(message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }
}
