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
    private static let defaultShortURLString = "https://v.kr.kollus.com/YmJybQjF"
    private static let defaultJWTPlaybackURLString = [
        "https://v.kr.kollus.com/s?",
        "jwt=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.",
        "eyJjdWlkIjoiY2F0ZW5vaWQtc2FtcGxlIiwiZXhwdCI6MjA5NjAwMDI2NiwibWMiOlt7Im1ja2V5IjoiWVRtMTNQQ0EifV19.",
        "fOzQlsg-jPCieTQ7KwE_dkSwM_NLg1gXzRfB-yhrlcU",
        "&custom_key=54081a54c0bb13fa49e3a24ad725bef1"
    ].joined()

    private let urlField = UITextField()
    private let playerButton = UIButton(configuration: .filled())
    private let jwtURLField = UITextField()
    private let jwtPlayerButton = UIButton(configuration: .filled())
    private let resolver = ShortURLResolver()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "VideoPlayer Example"
        view.backgroundColor = .systemBackground
        configureLayout()
    }

    private func configureLayout() {
        configureURLField(
            urlField,
            placeholder: "Kollus short URL",
            text: Self.defaultShortURLString,
            accessibilityIdentifier: "main.urlField"
        )

        playerButton.configuration?.title = "플레이어"
        playerButton.accessibilityIdentifier = "main.playerButton"
        playerButton.addTarget(self, action: #selector(didTapPlayer), for: .touchUpInside)

        configureURLField(
            jwtURLField,
            placeholder: "Kollus JWT URL",
            text: Self.defaultJWTPlaybackURLString,
            accessibilityIdentifier: "main.jwtURLField"
        )

        jwtPlayerButton.configuration?.title = "JWT 플레이어"
        jwtPlayerButton.accessibilityIdentifier = "main.jwtPlayerButton"
        jwtPlayerButton.addTarget(self, action: #selector(didTapJWTPlayer), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [
            urlField,
            playerButton,
            jwtURLField,
            jwtPlayerButton
        ])
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

    private func configureURLField(
        _ field: UITextField,
        placeholder: String,
        text: String,
        accessibilityIdentifier: String
    ) {
        field.borderStyle = .roundedRect
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.keyboardType = .URL
        field.clearButtonMode = .whileEditing
        field.placeholder = placeholder
        field.text = text
        field.accessibilityIdentifier = accessibilityIdentifier
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

    @objc private func didTapJWTPlayer() {
        guard let urlString = jwtURLField.text, urlString.isEmpty == false else {
            presentAlert(message: "JWT URL을 입력하세요.")
            return
        }
        guard navigationController?.topViewController === self else { return }
        jwtPlayerButton.isEnabled = false
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.jwtPlayerButton.isEnabled = true }
            do {
                let playbackURL = try await self.resolver.resolve(urlString)
                guard self.navigationController?.topViewController === self else { return }
                let container = PlayerTestConsoleContainerViewController(
                    source: .url(playbackURL),
                    moduleProvider: PlayerModuleProvider.shared
                )
                self.navigationController?.pushViewController(container, animated: true)
            } catch {
                self.presentAlert(message: "JWT 재생 준비 실패: \(error.localizedDescription)")
            }
        }
    }

    private func presentAlert(message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }
}
