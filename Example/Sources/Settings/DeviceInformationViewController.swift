//
//  DeviceInformationViewController.swift
//  VideoPlayerExample
//
//  Created by JunyoungJung on 2026/06/05.
//
//  기기 정보 표시 — 샘플 DeviceInformationViewController parity.
//

import UIKit

@MainActor
final class DeviceInformationViewController: UIViewController {
    private lazy var rows: [(String, String)] = [
        ("모델", UIDevice.current.model),
        ("기기 이름", UIDevice.current.name),
        ("OS", "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"),
        ("앱 버전", Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"),
        ("빌드", Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"),
        ("식별자", UIDevice.current.identifierForVendor?.uuidString ?? "-")
    ]

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "기기 정보"
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

extension DeviceInformationViewController: UITableViewDataSource {
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
