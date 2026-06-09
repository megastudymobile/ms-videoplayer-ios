//
//  BookmarkPaneViewController.swift
//  VideoPlayerExample
//
//  Created by JunyoungJung on 2026/06/08.
//
//  북마크 테스트 탭 — 현재 위치 추가 / 목록 / 탭 시 해당 지점 seek / 스와이프 삭제.
//

import UIKit
import VideoPlayerCore
import VideoPlayerSkin

@MainActor
final class BookmarkPaneViewController: UIViewController {
    private weak var channel: PlayerControlChannel?
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var bookmarks: [Bookmark] = []

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
        configureTable()
        // 활성화 시점에 이미 로드된 목록을 pull — bookmarksDidLoad 이벤트 누락 대비.
        bookmarks = sorted(channel?.loadedBookmarks ?? [])
        tableView.reloadData()
    }

    private func configureTable() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func sorted(_ list: [Bookmark]) -> [Bookmark] {
        list.sorted { $0.position < $1.position }
    }
}

// MARK: - PlayerConsolePane

extension BookmarkPaneViewController: PlayerConsolePane {
    func handleEvent(_ event: PlayerEvent) {
        guard case .bookmarksDidLoad(let loaded) = event else { return }
        bookmarks = sorted(loaded)
        if isViewLoaded { tableView.reloadData() }
    }
}

// MARK: - UITableViewDataSource / Delegate

extension BookmarkPaneViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int { 2 }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        section == 0 ? nil : "북마크 (\(bookmarks.count))"
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? 1 : bookmarks.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        if indexPath.section == 0 {
            cell.textLabel?.text = "현재 위치 추가"
            cell.textLabel?.textColor = view.tintColor
            cell.accessoryType = .none
        } else {
            let bookmark = bookmarks[indexPath.row]
            cell.textLabel?.text = "이동"
            cell.detailTextLabel?.text = PlayerSkinState.formatTime(bookmark.position)
            cell.accessoryType = .disclosureIndicator
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 0 {
            channel?.addBookmarkAtCurrentTime()
        } else {
            channel?.seek(to: bookmarks[indexPath.row].position)
        }
    }

    func tableView(
        _ tableView: UITableView,
        canEditRowAt indexPath: IndexPath
    ) -> Bool {
        indexPath.section == 1
    }

    func tableView(
        _ tableView: UITableView,
        commit editingStyle: UITableViewCell.EditingStyle,
        forRowAt indexPath: IndexPath
    ) {
        guard editingStyle == .delete, indexPath.section == 1 else { return }
        channel?.removeBookmark(at: bookmarks[indexPath.row].position)
        // 엔진의 bookmarksDidLoad 재방출을 기다리지 않고 즉시 로컬 반영 (낙관적 갱신).
        bookmarks.remove(at: indexPath.row)
        tableView.deleteRows(at: [indexPath], with: .automatic)
    }
}
