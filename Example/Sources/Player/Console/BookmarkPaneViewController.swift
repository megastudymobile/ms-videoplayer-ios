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
    private var supportsBookmarks: Bool {
        channel?.availableFeatures.contains(.bookmarks) ?? false
    }
    private var supportsBookmarkRemoval: Bool {
        channel?.availableFeatures.contains(.titledBookmarks) ?? false
    }

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
        updateBackgroundMessage()
    }

    /// 빈 상태/미지원 안내 — 엔진이 북마크 미지원이면 추가 행도 의미가 없으므로 명시한다.
    private func updateBackgroundMessage() {
        let message: String?
        if supportsBookmarks == false {
            message = "현재 엔진은 북마크를 지원하지 않습니다"
        } else if bookmarks.isEmpty {
            message = "북마크 없음 — 현재 위치 추가로 만들 수 있습니다"
        } else {
            message = nil
        }

        guard let message else {
            tableView.backgroundView = nil
            return
        }
        let label = UILabel()
        label.text = message
        label.textColor = .secondaryLabel
        label.font = .systemFont(ofSize: 14)
        label.textAlignment = .center
        label.numberOfLines = 0
        tableView.backgroundView = label
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
        if isViewLoaded {
            tableView.reloadData()
            updateBackgroundMessage()
        }
    }
}

// MARK: - UITableViewDataSource / Delegate

extension BookmarkPaneViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int { 2 }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        section == 0 ? nil : "북마크 (\(bookmarks.count))"
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? (supportsBookmarks ? 1 : 0) : bookmarks.count
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
            guard supportsBookmarks else { return }
            channel?.addBookmarkAtCurrentTime()
        } else {
            guard bookmarks.indices.contains(indexPath.row) else { return }
            channel?.seek(to: bookmarks[indexPath.row].position)
        }
    }

    func tableView(
        _ tableView: UITableView,
        canEditRowAt indexPath: IndexPath
    ) -> Bool {
        indexPath.section == 1 && supportsBookmarkRemoval
    }

    func tableView(
        _ tableView: UITableView,
        commit editingStyle: UITableViewCell.EditingStyle,
        forRowAt indexPath: IndexPath
    ) {
        guard editingStyle == .delete,
              indexPath.section == 1,
              supportsBookmarkRemoval,
              bookmarks.indices.contains(indexPath.row)
        else { return }
        channel?.removeBookmark(at: bookmarks[indexPath.row].position)
        // 엔진의 bookmarksDidLoad 재방출을 기다리지 않고 즉시 로컬 반영 (낙관적 갱신).
        bookmarks.remove(at: indexPath.row)
        tableView.deleteRows(at: [indexPath], with: .automatic)
        updateBackgroundMessage()
    }
}
