//
//  KollusConfigViewController.swift
//  VideoPlayerExample
//
//  Created by 모바일팀_정준영 on 2026/05/17.
//

import UIKit
import VideoPlayerEngineKollus

final class KollusConfigViewController: UIViewController {
    private let statusLabel = UILabel()
    private let mediaContentKeyField = UITextField()
    private let playButton = UIButton(type: .system)
    private let downloadListButton = UIButton(type: .system)
    private let detailsLabel = UILabel()

    private var loadedEnvironment: KollusEnvironment?
    private var moduleFactory: KollusPlayerModuleFactory?

    private func ensureFactory() -> KollusPlayerModuleFactory? {
        guard let environment = loadedEnvironment else {
            return nil
        }
        if let existing = moduleFactory {
            return existing
        }
        let factory = KollusPlayerModuleFactory(environment: environment)
        moduleFactory = factory
        return factory
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Kollus 데모"
        view.backgroundColor = .systemBackground
        configureUI()
        loadEnvironment()
    }

    private func configureUI() {
        statusLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        statusLabel.numberOfLines = 0

        mediaContentKeyField.placeholder = "mediaContentKey 입력"
        mediaContentKeyField.borderStyle = .roundedRect
        mediaContentKeyField.autocapitalizationType = .none
        mediaContentKeyField.autocorrectionType = .no

        var playConfiguration = UIButton.Configuration.filled()
        playConfiguration.title = "Kollus 재생 시작"
        playConfiguration.cornerStyle = .medium
        playButton.configuration = playConfiguration
        playButton.addTarget(self, action: #selector(didTapPlay), for: .touchUpInside)

        var downloadConfiguration = UIButton.Configuration.tinted()
        downloadConfiguration.title = "Kollus 다운로드 목록"
        downloadConfiguration.cornerStyle = .medium
        downloadListButton.configuration = downloadConfiguration
        downloadListButton.addTarget(self, action: #selector(didTapDownloadList), for: .touchUpInside)

        detailsLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        detailsLabel.textColor = .secondaryLabel
        detailsLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [
            statusLabel,
            mediaContentKeyField,
            playButton,
            downloadListButton,
            detailsLabel
        ])
        stack.axis = .vertical
        stack.spacing = 16

        view.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }

    private func loadEnvironment() {
        do {
            let configuration = try KollusEnvironmentLoader.loadFromBundle()
            loadedEnvironment = configuration.environment
            statusLabel.text = "Kollus 환경 로드 성공"
            statusLabel.textColor = .label
            mediaContentKeyField.text = configuration.mediaContentKey
            detailsLabel.text = """
            bundle: \(configuration.environment.applicationBundleID)
            expire: \(configuration.environment.applicationExpireDate)
            """
            playButton.isEnabled = true
            downloadListButton.isEnabled = true
        } catch {
            loadedEnvironment = nil
            statusLabel.text = "Kollus 환경 로드 실패\n\(error.localizedDescription)"
            statusLabel.textColor = .systemRed
            playButton.isEnabled = false
            downloadListButton.isEnabled = false
            detailsLabel.text = "Example/Resources/kollus.local.plist 가 필요합니다. .example 템플릿을 복제하고 자격증명을 채운 뒤 tuist generate를 다시 실행하세요."
        }
    }

    @objc
    private func didTapPlay() {
        guard let factory = ensureFactory() else {
            return
        }
        let mediaContentKey = (mediaContentKeyField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !mediaContentKey.isEmpty else {
            statusLabel.text = "mediaContentKey를 입력하세요."
            statusLabel.textColor = .systemRed
            return
        }

        let player = KollusPlayerShellViewController(
            moduleFactory: factory,
            mediaContentKey: mediaContentKey
        )
        navigationController?.pushViewController(player, animated: true)
    }

    @objc
    private func didTapDownloadList() {
        guard let factory = ensureFactory() else {
            return
        }
        guard let downloads = factory.downloads else {
            statusLabel.text = "다운로드 센터를 사용할 수 없습니다 (storagePath 미설정)."
            statusLabel.textColor = .systemRed
            return
        }
        let vc = KollusDownloadListViewController(
            downloads: downloads,
            initialMediaContentKey: (mediaContentKeyField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        )
        navigationController?.pushViewController(vc, animated: true)
    }
}
