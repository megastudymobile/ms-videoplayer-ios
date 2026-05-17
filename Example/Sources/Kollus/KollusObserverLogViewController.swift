//
//  KollusObserverLogViewController.swift
//  VideoPlayerExample
//
//  Created by 모바일팀_정준영 on 2026/05/17.
//

import UIKit

@MainActor
final class KollusObserverLogViewController: UIViewController {
    private let log: KollusObserverLog
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var entries: [KollusObserverLogEntry] = []
    private var listenerId: UUID?

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    init(log: KollusObserverLog) {
        self.log = log
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Kollus Observer 로그"
        view.backgroundColor = .systemBackground

        let clearItem = UIBarButtonItem(
            title: "Clear",
            style: .plain,
            target: self,
            action: #selector(didTapClear)
        )
        let markerItem = UIBarButtonItem(
            title: "Marker",
            style: .plain,
            target: self,
            action: #selector(didTapMarker)
        )
        navigationItem.rightBarButtonItems = [clearItem, markerItem]

        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "entry")
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 80

        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])

        listenerId = log.observe { [weak self] entries in
            self?.apply(entries: entries)
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isMovingFromParent || isBeingDismissed, let id = listenerId {
            log.cancel(id)
            listenerId = nil
        }
    }

    private func apply(entries: [KollusObserverLogEntry]) {
        self.entries = entries
        tableView.reloadData()
        if !entries.isEmpty {
            let indexPath = IndexPath(row: entries.count - 1, section: 0)
            tableView.scrollToRow(at: indexPath, at: .bottom, animated: false)
        }
    }

    @objc
    private func didTapClear() {
        log.clear()
    }

    @objc
    private func didTapMarker() {
        log.append(.init(
            timestamp: Date(),
            kind: .marker,
            title: "사용자 marker",
            detail: "수동으로 marker가 추가되었습니다."
        ))
    }
}

extension KollusObserverLogViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        entries.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "entry", for: indexPath)
        let entry = entries[indexPath.row]
        var configuration = UIListContentConfiguration.subtitleCell()
        configuration.text = "[\(entry.kind.rawValue)] \(entry.title)"
        configuration.secondaryText = "\(Self.timeFormatter.string(from: entry.timestamp))\n\(entry.detail)"
        configuration.secondaryTextProperties.numberOfLines = 0
        configuration.secondaryTextProperties.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        cell.contentConfiguration = configuration
        return cell
    }
}
