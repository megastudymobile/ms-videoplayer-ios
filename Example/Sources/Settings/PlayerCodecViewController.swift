//
//  PlayerCodecViewController.swift
//  VideoPlayerExample
//
//  Created by JunyoungJung on 2026/06/05.
//
//  코덱 선택 — PreferenceManager.playerCodec 저장.
//  적용 지점: KollusEnvironment.hardwareDecoderPreferred (다음 재생부터 반영).
//

import UIKit

@MainActor
final class PlayerCodecViewController: UIViewController {
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "플레이어 디코더"
        view.backgroundColor = .systemBackground

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
}

extension PlayerCodecViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        PlayerCodec.allCases.count
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        "변경 사항은 다음 재생부터 적용됩니다."
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let codec = PlayerCodec.allCases[indexPath.row]
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.textLabel?.text = codec.title
        cell.accessoryType = codec.rawValue == PreferenceManager.playerCodec ? .checkmark : .none
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        PreferenceManager.playerCodec = PlayerCodec.allCases[indexPath.row].rawValue
        tableView.reloadData()
    }
}
