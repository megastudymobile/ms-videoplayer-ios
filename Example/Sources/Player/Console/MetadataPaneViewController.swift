//
//  MetadataPaneViewController.swift
//  VideoPlayerExample
//
//  Created by JunyoungJung on 2026/06/08.
//
//  메타데이터 테스트 탭 — 플레이어 라이브 상태를 읽기 전용으로 표시.
//  onSkinStateChanged fan-out 을 받아 currentTime/duration/배속/lock/displayScale/layoutMode 등을 갱신.
//

import UIKit
import VideoPlayerCore
import VideoPlayerSkin

@MainActor
final class MetadataPaneViewController: UIViewController {
    private weak var channel: PlayerControlChannel?
    private let sourceDescription: String
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var rows: [(title: String, value: String)] = []

    init(channel: PlayerControlChannel, sourceDescription: String) {
        self.channel = channel
        self.sourceDescription = sourceDescription
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.allowsSelection = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        // 활성화 즉시 현재 스냅샷으로 초기 표시.
        if let state = channel?.currentSkinState { rebuild(from: state) }
    }

    private func rebuild(from state: PlayerSkinState) {
        rows = [
            ("소스", sourceDescription),
            ("상태", state.isLoading ? "로딩중" : (state.isPlaying ? "재생중" : "일시정지")),
            ("현재 시간", state.currentTimeText),
            ("전체 길이", state.durationText),
            ("진행률", String(format: "%.1f%%", state.progress * 100)),
            ("배속", String(format: "%.2fx", state.playbackRate)),
            ("잠금", state.isLocked ? "ON" : "OFF"),
            ("디스플레이 확대", state.isDisplayScaled ? "ON" : "OFF"),
            ("스케일 모드", String(describing: state.displayScaleMode)),
            ("구간 반복", Self.describe(state.sectionRepeat)),
            ("전체화면", state.isFullScreenMode ? "ON" : "OFF"),
            ("레이아웃", String(describing: state.layoutMode))
        ]
        if isViewLoaded { tableView.reloadData() }
    }

    private static func describe(_ sectionRepeat: PlayerSkinState.SectionRepeatState) -> String {
        switch sectionRepeat {
        case .idle:
            return "OFF"
        case .started(let start):
            return "시작 \(PlayerSkinState.formatTime(start))"
        case .looping(let start, let end):
            return "\(PlayerSkinState.formatTime(start)) ~ \(PlayerSkinState.formatTime(end))"
        }
    }
}

// MARK: - PlayerConsolePane

extension MetadataPaneViewController: PlayerConsolePane {
    func applySkinState(_ state: PlayerSkinState) {
        rebuild(from: state)
    }
}

// MARK: - UITableViewDataSource

extension MetadataPaneViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        let row = rows[indexPath.row]
        cell.textLabel?.text = row.title
        cell.detailTextLabel?.text = row.value
        cell.detailTextLabel?.numberOfLines = 0
        return cell
    }
}
