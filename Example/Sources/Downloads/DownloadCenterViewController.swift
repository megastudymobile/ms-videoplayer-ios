//
//  DownloadCenterViewController.swift
//  VideoPlayerExample
//
//  Created by JunyoungJung on 2026/06/10.
//
//  다운로드 센터 — 엔진 중립 PlayerDownloadCenter 계약 시연.
//  URL 등록→다운로드, 목록/진행률, 라이선스 상태·갱신, 실패 이벤트 토스트,
//  완료 항목 오프라인 재생(사전 라이선스 검증) 까지 전 수명주기를 다룬다.
//  Kollus 타입 import 없음 — 계약만 의존 (SDK 교체 시 이 화면 수정 불필요).
//

import UIKit
import VideoPlayerCore

@MainActor
final class DownloadCenterViewController: UIViewController {
    private let center: (any PlayerDownloadCenter)?

    private let urlField = UITextField()
    private let downloadButton = UIButton(configuration: .filled())
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let metricsLabel = UILabel()
    private let toastLabel = UILabel()

    private var rows: [DownloadCenterViewModel.Row] = []
    private var contentsTask: Task<Void, Never>?
    private var eventsTask: Task<Void, Never>?
    private var toastDismissTask: Task<Void, Never>?

    init(center: (any PlayerDownloadCenter)?) {
        self.center = center
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        contentsTask?.cancel()
        eventsTask?.cancel()
        toastDismissTask?.cancel()
    }

    // MARK: - Lifecycle

    /// 루트 nav bar는 메인 화면에서 숨겨져 있다(SceneDelegate) — 이 화면은 back 버튼이 필요하므로 노출.
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent {
            navigationController?.setNavigationBarHidden(true, animated: animated)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "다운로드 센터"
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "라이선스 갱신",
            style: .plain,
            target: self,
            action: #selector(didTapRenewLicenses)
        )
        configureLayout()

        guard center != nil else {
            showEmptyState("시뮬레이터에서는 다운로드를 지원하지 않습니다.\n실기기에서 확인해 주세요.")
            urlField.isEnabled = false
            downloadButton.isEnabled = false
            navigationItem.rightBarButtonItem?.isEnabled = false
            return
        }

        subscribeStreams()
        refreshContents()
        refreshMetrics()
    }

    // MARK: - 스트림 구독

    private func subscribeStreams() {
        guard let center else { return }

        // 목록 스트림 — storage delegate 콜백마다 전체 목록 재발행.
        contentsTask = Task { @MainActor [weak self] in
            for await contents in center.contents {
                self?.apply(contents: contents)
            }
        }

        // 이벤트 스트림 — 실패/완료/라이선스 갱신을 사용자에게 즉시 surfacing.
        eventsTask = Task { @MainActor [weak self] in
            for await event in center.events {
                self?.handle(event: event)
            }
        }
    }

    private func handle(event: DownloadEvent) {
        switch event {
        case .completed(let contentID):
            showToast("다운로드 완료 — \(contentID)")
            refreshMetrics()
        case .failed(let contentID, let error):
            showToast("다운로드 실패(\(contentID)) — \(PlayerErrorPresentation.toastText(for: error))")
        case .licenseRenewalProgressed(let current, let total):
            showToast("라이선스 갱신 \(current)/\(total)")
            refreshContents()
        case .licenseRenewalFailed(let error):
            showToast(PlayerErrorPresentation.toastText(for: error))
        }
    }

    // MARK: - 데이터 갱신

    private func apply(contents: [DownloadedContent]) {
        rows = DownloadCenterViewModel.rows(from: contents)
        tableView.reloadData()
        updateEmptyStateIfNeeded()
    }

    private func refreshContents() {
        guard let center else { return }
        Task { @MainActor [weak self] in
            guard let contents = try? await center.currentContents() else { return }
            self?.apply(contents: contents)
        }
    }

    private func refreshMetrics() {
        guard let center else { return }
        Task { @MainActor [weak self] in
            guard let metrics = try? await center.storageMetrics() else { return }
            self?.metricsLabel.text = DownloadCenterViewModel.metricsText(metrics)
        }
    }

    // MARK: - Actions

    @objc private func didTapDownload() {
        guard let center else { return }
        guard let urlString = urlField.text, urlString.isEmpty == false else {
            showToast("다운로드 URL을 입력하세요")
            return
        }
        downloadButton.isEnabled = false
        Task { @MainActor [weak self] in
            defer { self?.downloadButton.isEnabled = true }
            do {
                let contentID = try await center.resolve(contentURL: urlString)
                try await center.startDownload(contentID: contentID)
                self?.showToast("다운로드 시작 — \(contentID)")
                self?.refreshContents()
            } catch {
                self?.presentError(error)
            }
        }
    }

    @objc private func didTapRenewLicenses() {
        guard let center else { return }
        Task { @MainActor [weak self] in
            do {
                try await center.renewLicenses(scope: .expiredOnly)
                self?.showToast("라이선스 갱신 요청 완료")
            } catch {
                self?.presentError(error)
            }
        }
    }

    private func didSelect(row: DownloadCenterViewModel.Row) {
        if row.isInProgress {
            confirmCancel(row)
            return
        }
        if row.isPlayable {
            playOffline(row)
            return
        }
        if let issue = row.playabilityIssue {
            presentError(issue)
        }
    }

    /// 오프라인 재생 — 사전 검증은 ViewModel(isPlayable)에서 끝났고,
    /// prepare 시 어댑터가 한 번 더 검증한다 (이중 방어).
    private func playOffline(_ row: DownloadCenterViewModel.Row) {
        guard navigationController?.topViewController === self else { return }
        let container = PlayerTestConsoleContainerViewController(
            source: .mediaKey(row.id),
            moduleProvider: PlayerModuleProvider.shared
        )
        navigationController?.pushViewController(container, animated: true)
    }

    private func confirmCancel(_ row: DownloadCenterViewModel.Row) {
        let alert = UIAlertController(
            title: "다운로드 취소",
            message: "\(row.title) 다운로드를 취소할까요?",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "계속 받기", style: .cancel))
        alert.addAction(UIAlertAction(title: "취소", style: .destructive) { [weak self] _ in
            self?.cancelDownload(contentID: row.id)
        })
        present(alert, animated: true)
    }

    private func cancelDownload(contentID: String) {
        guard let center else { return }
        Task { @MainActor [weak self] in
            do {
                try await center.cancelDownload(contentID: contentID)
                self?.refreshContents()
            } catch {
                self?.presentError(error)
            }
        }
    }

    private func remove(contentID: String) {
        guard let center else { return }
        Task { @MainActor [weak self] in
            do {
                try await center.remove(contentID: contentID)
                self?.refreshContents()
                self?.refreshMetrics()
            } catch {
                self?.presentError(error)
            }
        }
    }

    // MARK: - 알림/토스트

    private func presentError(_ error: Error) {
        let message = PlayerErrorPresentation.message(for: error)
        let body = [message.body, message.recoverySuggestion].compactMap { $0 }.joined(separator: "\n\n")
        let alert = UIAlertController(title: message.title, message: body, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }

    private func showToast(_ message: String) {
        toastLabel.text = "  \(message)  "
        view.bringSubviewToFront(toastLabel)
        UIView.animate(withDuration: 0.2) { [weak self] in self?.toastLabel.alpha = 1 }
        toastDismissTask?.cancel()
        toastDismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard Task.isCancelled == false else { return }
            UIView.animate(withDuration: 0.3) { self?.toastLabel.alpha = 0 }
        }
    }

    // MARK: - 빈 상태

    private func showEmptyState(_ message: String) {
        let label = UILabel()
        label.text = message
        label.textColor = .secondaryLabel
        label.font = .systemFont(ofSize: 14)
        label.textAlignment = .center
        label.numberOfLines = 0
        tableView.backgroundView = label
    }

    private func updateEmptyStateIfNeeded() {
        if rows.isEmpty {
            showEmptyState("다운로드한 콘텐츠가 없습니다.\n상단에 다운로드 URL을 입력해 시작하세요.")
        } else {
            tableView.backgroundView = nil
        }
    }

    // MARK: - 레이아웃

    private func configureLayout() {
        urlField.borderStyle = .roundedRect
        urlField.autocapitalizationType = .none
        urlField.autocorrectionType = .no
        urlField.keyboardType = .URL
        urlField.clearButtonMode = .whileEditing
        urlField.placeholder = "다운로드 URL (media_download_url)"
        urlField.accessibilityIdentifier = "downloadCenter.urlField"

        downloadButton.configuration?.title = "다운로드"
        downloadButton.accessibilityIdentifier = "downloadCenter.downloadButton"
        downloadButton.addTarget(self, action: #selector(didTapDownload), for: .touchUpInside)

        metricsLabel.font = .systemFont(ofSize: 13)
        metricsLabel.textColor = .secondaryLabel
        metricsLabel.textAlignment = .center
        metricsLabel.text = " "

        tableView.dataSource = self
        tableView.delegate = self

        toastLabel.textColor = .white
        toastLabel.font = .systemFont(ofSize: 14, weight: .medium)
        toastLabel.textAlignment = .center
        toastLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        toastLabel.layer.cornerRadius = 8
        toastLabel.clipsToBounds = true
        toastLabel.alpha = 0

        let header = UIStackView(arrangedSubviews: [urlField, downloadButton, metricsLabel])
        header.axis = .vertical
        header.spacing = 12

        for subview in [header, tableView, toastLabel] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(subview)
        }

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            tableView.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            toastLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toastLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40),
            toastLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 200),
            toastLabel.heightAnchor.constraint(equalToConstant: 36)
        ])
    }
}

// MARK: - UITableViewDataSource / Delegate

extension DownloadCenterViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        let row = rows[indexPath.row]
        cell.textLabel?.text = row.title
        cell.detailTextLabel?.text = "\(row.statusText) · \(row.licenseText)"
        cell.detailTextLabel?.textColor = row.playabilityIssue == nil ? .secondaryLabel : .systemRed
        cell.accessoryType = row.isPlayable ? .disclosureIndicator : .none
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        didSelect(row: rows[indexPath.row])
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        true
    }

    func tableView(
        _ tableView: UITableView,
        commit editingStyle: UITableViewCell.EditingStyle,
        forRowAt indexPath: IndexPath
    ) {
        guard editingStyle == .delete else { return }
        remove(contentID: rows[indexPath.row].id)
    }
}
