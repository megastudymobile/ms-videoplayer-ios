//
//  KollusDownloadListViewController.swift
//  VideoPlayerExample
//
//  Created by 모바일팀_정준영 on 2026/05/17.
//
//  KollusDownloadCenter의 contents AsyncStream을 구독해 다운로드 항목 목록을 표시.
//  Stage 2: 시작/취소/제거 액션 + 캐시/네트워크 설정 액션을 노출.
//

import UIKit
import VideoPlayerEngineKollus

@MainActor
final class KollusDownloadListViewController: UIViewController {
    private let downloads: KollusDownloadCenter
    private var initialMediaContentKey: String

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let footerView = UIView()
    private let mediaContentKeyField = UITextField()
    private let startButton = UIButton(type: .system)
    private let actionsButton = UIButton(type: .system)
    private let statusLabel = UILabel()

    private var snapshots: [KollusContentSnapshot] = []
    private var subscriptionTask: Task<Void, Never>?

    init(downloads: KollusDownloadCenter, initialMediaContentKey: String) {
        self.downloads = downloads
        self.initialMediaContentKey = initialMediaContentKey
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Kollus 다운로드"
        view.backgroundColor = .systemBackground
        configureFooter()
        configureTable()
        subscribeContents()
        refreshSnapshots()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isMovingFromParent || isBeingDismissed {
            subscriptionTask?.cancel()
            subscriptionTask = nil
        }
    }

    private func configureFooter() {
        mediaContentKeyField.placeholder = "mediaContentKey"
        mediaContentKeyField.borderStyle = .roundedRect
        mediaContentKeyField.autocapitalizationType = .none
        mediaContentKeyField.autocorrectionType = .no
        mediaContentKeyField.text = initialMediaContentKey

        var startConfiguration = UIButton.Configuration.filled()
        startConfiguration.title = "다운로드 시작"
        startConfiguration.cornerStyle = .medium
        startButton.configuration = startConfiguration
        startButton.addTarget(self, action: #selector(didTapStart), for: .touchUpInside)

        var actionsConfiguration = UIButton.Configuration.tinted()
        actionsConfiguration.title = "고급 액션"
        actionsConfiguration.cornerStyle = .medium
        actionsButton.configuration = actionsConfiguration
        actionsButton.addTarget(self, action: #selector(didTapActions), for: .touchUpInside)

        statusLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        statusLabel.textColor = .secondaryLabel
        statusLabel.numberOfLines = 0
        statusLabel.text = "다운로드 항목을 불러오는 중..."

        let buttonStack = UIStackView(arrangedSubviews: [startButton, actionsButton])
        buttonStack.axis = .horizontal
        buttonStack.spacing = 12
        buttonStack.distribution = .fillEqually

        let stack = UIStackView(arrangedSubviews: [
            mediaContentKeyField,
            buttonStack,
            statusLabel
        ])
        stack.axis = .vertical
        stack.spacing = 8

        footerView.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: footerView.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: footerView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: footerView.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: footerView.bottomAnchor, constant: -12)
        ])

        footerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(footerView)
        NSLayoutConstraint.activate([
            footerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }

    private func configureTable() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "snapshot")
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: footerView.topAnchor)
        ])
    }

    private func subscribeContents() {
        subscriptionTask = Task { [weak self] in
            guard let self else { return }
            for await snapshots in self.downloads.contents {
                await MainActor.run {
                    self.apply(snapshots: snapshots)
                }
            }
        }
    }

    private func refreshSnapshots() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let latest = try await self.downloads.currentSnapshots()
                self.apply(snapshots: latest)
            } catch {
                self.statusLabel.text = "스냅샷 로드 실패: \(error.localizedDescription)"
            }
        }
    }

    private func apply(snapshots: [KollusContentSnapshot]) {
        self.snapshots = snapshots
        statusLabel.text = "다운로드 항목 \(snapshots.count)개"
        tableView.reloadData()
    }

    @objc
    private func didTapStart() {
        let mediaContentKey = (mediaContentKeyField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !mediaContentKey.isEmpty else {
            statusLabel.text = "mediaContentKey를 입력하세요."
            return
        }
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.downloads.startDownload(mediaContentKey: mediaContentKey)
                self.statusLabel.text = "다운로드 시작 요청 보냄: \(mediaContentKey)"
                self.refreshSnapshots()
            } catch {
                self.statusLabel.text = "다운로드 시작 실패: \(error.localizedDescription)"
            }
        }
    }

    @objc
    private func didTapActions() {
        let alert = UIAlertController(title: "고급 액션", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "스트리밍 캐시 비우기", style: .destructive) { [weak self] _ in
            self?.runAction("clearStreamingCache") { try await $0.clearStreamingCache() }
        })
        alert.addAction(UIAlertAction(title: "DRM 갱신 (만료만)", style: .default) { [weak self] _ in
            self?.runAction("updateDRM(includeExpiredOnly: true)") {
                try await $0.updateDRM(includeExpiredOnly: true)
            }
        })
        alert.addAction(UIAlertAction(title: "DRM 갱신 (전체)", style: .default) { [weak self] _ in
            self?.runAction("updateDRM(includeExpiredOnly: false)") {
                try await $0.updateDRM(includeExpiredOnly: false)
            }
        })
        alert.addAction(UIAlertAction(title: "Stored LMS 전송", style: .default) { [weak self] _ in
            self?.runAction("sendStoredLMS") { try await $0.sendStoredLMS() }
        })
        alert.addAction(UIAlertAction(title: "백그라운드 다운로드 ON", style: .default) { [weak self] _ in
            self?.runAction("setBackgroundDownload(true)") { try await $0.setBackgroundDownload(enabled: true) }
        })
        alert.addAction(UIAlertAction(title: "백그라운드 다운로드 OFF", style: .default) { [weak self] _ in
            self?.runAction("setBackgroundDownload(false)") { try await $0.setBackgroundDownload(enabled: false) }
        })
        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        present(alert, animated: true)
    }

    private func runAction(
        _ label: String,
        _ operation: @MainActor @Sendable @escaping (KollusDownloadCenter) async throws -> Void
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await operation(self.downloads)
                self.statusLabel.text = "\(label) 성공"
                self.refreshSnapshots()
            } catch {
                self.statusLabel.text = "\(label) 실패: \(error.localizedDescription)"
            }
        }
    }
}

extension KollusDownloadListViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        snapshots.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let snapshot = snapshots[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "snapshot", for: indexPath)
        var configuration = UIListContentConfiguration.subtitleCell()
        configuration.text = snapshot.title.isEmpty ? snapshot.id : snapshot.title
        configuration.secondaryText = Self.describe(snapshot: snapshot)
        cell.contentConfiguration = configuration
        return cell
    }

    private static func describe(snapshot: KollusContentSnapshot) -> String {
        let downloadDescription: String
        switch snapshot.download {
        case .notDownloaded:
            downloadDescription = "대기"
        case .inProgress(let percent, let bytes):
            downloadDescription = String(format: "%.1f%% (%lld bytes)", percent, bytes)
        case .completed:
            downloadDescription = "완료"
        }

        return "\(snapshot.id) · \(downloadDescription)"
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let snapshot = snapshots[indexPath.row]
        let cancel = UIContextualAction(style: .normal, title: "Cancel") { [weak self] _, _, completion in
            Task { @MainActor [weak self] in
                guard let self else { completion(false); return }
                do {
                    try await self.downloads.cancelDownload(mediaContentKey: snapshot.id)
                    self.statusLabel.text = "취소 성공: \(snapshot.id)"
                    self.refreshSnapshots()
                    completion(true)
                } catch {
                    self.statusLabel.text = "취소 실패: \(error.localizedDescription)"
                    completion(false)
                }
            }
        }
        let remove = UIContextualAction(style: .destructive, title: "Remove") { [weak self] _, _, completion in
            Task { @MainActor [weak self] in
                guard let self else { completion(false); return }
                do {
                    try await self.downloads.remove(mediaContentKey: snapshot.id)
                    self.statusLabel.text = "제거 성공: \(snapshot.id)"
                    self.refreshSnapshots()
                    completion(true)
                } catch {
                    self.statusLabel.text = "제거 실패: \(error.localizedDescription)"
                    completion(false)
                }
            }
        }
        return UISwipeActionsConfiguration(actions: [remove, cancel])
    }
}
