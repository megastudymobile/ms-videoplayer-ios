//
//  GestureViewController.swift
//  VideoPlayerExample
//
//  Created by JunyoungJung on 2026/06/05.
//
//  제스처 안내 — 정적 표시 화면 (샘플 GestureViewController parity).
//

import UIKit

@MainActor
final class GestureViewController: UIViewController {
    private let rows: [(String, String)] = [
        ("탭", "컨트롤 표시/숨김"),
        ("좌측 상하 드래그", "밝기 조절"),
        ("우측 상하 드래그", "음량 조절"),
        ("핀치", "화면 확대/축소"),
        ("진행바 드래그", "원하는 위치로 이동")
    ]

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "제스처 설정"
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
    }
}

extension GestureViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.textLabel?.text = rows[indexPath.row].0
        cell.detailTextLabel?.text = rows[indexPath.row].1
        return cell
    }
}
