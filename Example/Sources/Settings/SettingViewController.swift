//
//  SettingViewController.swift
//  VideoPlayerExample
//
//  Created by JunyoungJung on 2026/06/05.
//
//  설정 루트 — SettingSection/SettingItem 데이터 주도 구성 (OCP).
//  항목 추가 = sections 배열에 행 추가, 테이블 코드 수정 없음.
//

import UIKit

// MARK: - 데이터 모델

struct SettingSection {
    let title: String
    let items: [SettingItem]
}

enum SettingItem {
    /// UISwitch 행 — get/set은 PreferenceManager에 연결.
    case toggle(title: String, get: () -> Bool, set: (Bool) -> Void)
    /// 현재 값 표시 + 탭 시 선택지 시트.
    case picker(title: String, currentTitle: () -> String, options: [(String, () -> Void)])
    /// 하위 화면 push.
    case navigation(title: String, makeViewController: () -> UIViewController)
    /// 읽기 전용 값 표시.
    case info(title: String, value: () -> String)
    /// 확인 후 실행하는 동작 (앱 초기화 등).
    case action(title: String, isDestructive: Bool, handler: () -> Void)
}

// MARK: - SettingViewController

@MainActor
final class SettingViewController: UIViewController {
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var sections: [SettingSection] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "세팅"
        view.backgroundColor = .systemBackground
        configureTable()
        rebuildSections()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()   // 하위 화면(코덱 등)에서 돌아올 때 값 갱신
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

    // MARK: - 섹션 구성 (샘플 SettingViewController 항목 parity)

    private func rebuildSections() {
        sections = [
            SettingSection(title: "재생", items: [
                .toggle(
                    title: "백그라운드 오디오 재생",
                    get: { PreferenceManager.isBackgroundAudioPlay },
                    set: { PreferenceManager.isBackgroundAudioPlay = $0 }
                ),
                .toggle(
                    title: "데이터망 사용 시 알림",
                    get: { PreferenceManager.isUseNetworkData },
                    set: { PreferenceManager.isUseNetworkData = $0 }
                ),
                .navigation(
                    title: "플레이어 디코더 설정",
                    makeViewController: { PlayerCodecViewController() }
                ),
                .picker(
                    title: "시크 간격",
                    currentTitle: { (SeekRange(rawValue: PreferenceManager.seekRange) ?? .r10).title },
                    options: SeekRange.allCases.map { range in
                        (range.title, { PreferenceManager.seekRange = range.rawValue })
                    }
                )
            ]),
            SettingSection(title: "자막", items: [
                .picker(
                    title: "자막 크기",
                    currentTitle: { (SubtitleSize(rawValue: PreferenceManager.subtitleSize) ?? .normal).title },
                    options: SubtitleSize.allCases.map { size in
                        (size.title, { PreferenceManager.subtitleSize = size.rawValue })
                    }
                ),
                .picker(
                    title: "자막 색상",
                    currentTitle: { (SubtitleColor(rawValue: PreferenceManager.subtitleColor) ?? .white).title },
                    options: SubtitleColor.allCases.map { color in
                        (color.title, { PreferenceManager.subtitleColor = color.rawValue })
                    }
                ),
                .toggle(
                    title: "자막 배경 표시",
                    get: { PreferenceManager.isUseSubtitleBackground },
                    set: { PreferenceManager.isUseSubtitleBackground = $0 }
                )
            ]),
            SettingSection(title: "정보", items: [
                .navigation(title: "제스처 설정", makeViewController: { GestureViewController() }),
                .navigation(title: "단축키 설정", makeViewController: { ShortcutViewController() }),
                .navigation(title: "기기 정보", makeViewController: { DeviceInformationViewController() }),
                .navigation(title: "FAQ", makeViewController: { WebViewController() }),
                .info(title: "플레이어 정보", value: {
                    Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
                })
            ]),
            SettingSection(title: "기타", items: [
                .action(title: "앱 초기화", isDestructive: true) { [weak self] in
                    PreferenceManager.reset()
                    self?.tableView.reloadData()
                }
            ])
        ]
        tableView.reloadData()
    }
}

// MARK: - UITableViewDataSource / Delegate

extension SettingViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        sections[section].title
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = sections[indexPath.section].items[indexPath.row]
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)

        switch item {
        case .toggle(let title, let get, let set):
            cell.textLabel?.text = title
            cell.selectionStyle = .none
            let toggle = SettingSwitch()
            toggle.isOn = get()
            toggle.onChange = set
            cell.accessoryView = toggle
        case .picker(let title, let currentTitle, _):
            cell.textLabel?.text = title
            cell.detailTextLabel?.text = currentTitle()
            cell.accessoryType = .disclosureIndicator
        case .navigation(let title, _):
            cell.textLabel?.text = title
            cell.accessoryType = .disclosureIndicator
        case .info(let title, let value):
            cell.textLabel?.text = title
            cell.detailTextLabel?.text = value()
            cell.selectionStyle = .none
        case .action(let title, let isDestructive, _):
            cell.textLabel?.text = title
            cell.textLabel?.textColor = isDestructive ? .systemRed : .label
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = sections[indexPath.section].items[indexPath.row]

        switch item {
        case .toggle, .info:
            break
        case .navigation(_, let makeViewController):
            navigationController?.pushViewController(makeViewController(), animated: true)
        case .picker(let title, _, let options):
            presentPicker(title: title, options: options, anchor: tableView.cellForRow(at: indexPath))
        case .action(let title, let isDestructive, let handler):
            presentConfirm(title: title, isDestructive: isDestructive, handler: handler)
        }
    }

    private func presentPicker(title: String, options: [(String, () -> Void)], anchor: UIView?) {
        let sheet = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
        for (optionTitle, apply) in options {
            sheet.addAction(UIAlertAction(title: optionTitle, style: .default) { [weak self] _ in
                apply()
                self?.tableView.reloadData()
            })
        }
        sheet.addAction(UIAlertAction(title: "취소", style: .cancel))
        sheet.popoverPresentationController?.sourceView = anchor ?? view
        sheet.popoverPresentationController?.sourceRect = anchor?.bounds ?? view.bounds
        present(sheet, animated: true)
    }

    private func presentConfirm(title: String, isDestructive: Bool, handler: @escaping () -> Void) {
        let alert = UIAlertController(title: title, message: "실행할까요?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        alert.addAction(UIAlertAction(title: "확인", style: isDestructive ? .destructive : .default) { _ in
            handler()
        })
        present(alert, animated: true)
    }
}

/// 클로저 콜백 UISwitch — target/action 보일러플레이트 제거용.
private final class SettingSwitch: UISwitch {
    var onChange: ((Bool) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        addTarget(self, action: #selector(handleValueChanged), for: .valueChanged)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func handleValueChanged() {
        onChange?(isOn)
    }
}
