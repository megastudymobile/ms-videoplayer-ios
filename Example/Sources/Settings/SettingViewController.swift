//
//  SettingViewController.swift
//  VideoPlayerExample
//
//  Created by JunyoungJung on 2026/06/05.
//
//  설정 루트 — SLSettingViewController "플레이어 설정" 그룹 parity.
//  데이터 주도(SettingSection/SettingItem) + 단일 유연 셀(SettingCell): 제목 + 설명문구 + N 뱃지 +
//  액세서리(스위치/± 스테퍼/detail+화살표/캐시 비우기). SL 화면/재생 설정 셀 구성을 재현한다.
//
//  값 변경 즉시 재생 반영: 배속/자막은 PlayerControlChannel 로 라이브 적용.
//  (시크 간격은 PlayerViewController 가 매 skip 시 PreferenceManager 를 읽어 이미 라이브.)
//

import UIKit

// MARK: - 데이터 모델

struct SettingSection {
    let title: String
    let items: [SettingItem]
}

/// 행 우측 액세서리 — SL 셀 타입 parity.
enum SettingAccessory {
    /// UISwitch.
    case toggle(get: () -> Bool, set: (Bool) -> Void)
    /// − [값] + 스테퍼. on±는 값 변경 후 reload/라이브 적용까지 포함.
    case stepper(value: () -> String, canDecrement: () -> Bool, canIncrement: () -> Bool,
                 onDecrement: () -> Void, onIncrement: () -> Void)
    /// 우측 값 + 화살표, 탭 시 push.
    case navigation(detail: (() -> String)?, makeViewController: () -> UIViewController)
    /// 우측 회색 값(읽기 전용).
    case detail(value: () -> String)
    /// 우측 값 + "비우기" 버튼.
    case cacheClear(value: () -> String, clearTitle: String, onClear: () -> Void)
}

struct SettingItem {
    let title: String
    let description: String?
    /// 스타일 적용된 설명(예: 자막 "메가스터디" 샘플) — 있으면 description 대신 표시.
    let attributedDescription: NSAttributedString?
    let isNew: Bool
    let accessory: SettingAccessory

    init(title: String, description: String? = nil, attributedDescription: NSAttributedString? = nil,
         isNew: Bool = false, accessory: SettingAccessory) {
        self.title = title
        self.description = description
        self.attributedDescription = attributedDescription
        self.isNew = isNew
        self.accessory = accessory
    }
}

// MARK: - 데이터 주도 설정 테이블 base

/// 설정 화면 공통 테이블 컨트롤러 — 하위 클래스는 `screenTitle`/`buildSections()`만 override.
@MainActor
class SettingsListViewController: UIViewController {
    // SL 환경설정은 엣지투엣지 풀폭 그룹 카드(insetGrouped 둘레 여백 X).
    let tableView = UITableView(frame: .zero, style: .grouped)
    private(set) var sections: [SettingSection] = []

    /// 재생 중 라이브 적용용 채널 — 하위 화면 push 시 전달.
    /// PlayerControlChannel 계약대로 retain cycle 방지를 위해 weak 보관.
    weak var channel: PlayerControlChannel?

    var screenTitle: String { "" }
    func buildSections() -> [SettingSection] { [] }

    final func reloadSections() {
        sections = buildSections()
        tableView.reloadData()
    }

    init(channel: PlayerControlChannel?) {
        self.channel = channel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = screenTitle
        view.backgroundColor = SLPalette.paleGrey
        configureTable()
        reloadSections()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadSections()   // 하위 화면에서 돌아올 때 값 갱신
    }

    private func configureTable() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(SettingCell.self, forCellReuseIdentifier: SettingCell.reuseID)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 58
        // SL parity: paleGrey 배경 + 풀폭 hairline 구분선.
        tableView.backgroundColor = SLPalette.paleGrey
        tableView.separatorInset = .zero
        tableView.separatorColor = SLPalette.hairline
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
}

// MARK: - UITableViewDataSource / Delegate

extension SettingsListViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int { sections.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].items.count
    }

    // SL 그룹 헤더 parity: paleGrey 위 회색 텍스트(비대문자), 높이 42, 좌 inset 20.
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { 42 }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = UIView()
        header.backgroundColor = SLPalette.paleGrey
        let label = UILabel()
        label.text = sections[section].title
        label.font = SLFont.detail()
        label.textColor = SLPalette.grey58
        label.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 20),
            label.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -8)
        ])
        return header
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: SettingCell.reuseID, for: indexPath)
        guard let settingCell = cell as? SettingCell else { return cell }
        settingCell.configure(with: sections[indexPath.section].items[indexPath.row])
        return settingCell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = sections[indexPath.section].items[indexPath.row]
        if case .navigation(_, let make) = item.accessory {
            navigationController?.pushViewController(make(), animated: true)
        }
    }
}

// MARK: - 설정 루트 (SLSettingViewController "플레이어 설정" 그룹 parity)

@MainActor
final class SettingViewController: SettingsListViewController {
    override var screenTitle: String { "환경설정" }

    override func buildSections() -> [SettingSection] {
        var playerItems: [SettingItem] = [
            // persist-only: Example 스트리밍에 WWAN 게이트 없음 (재생 효과 없음).
            SettingItem(
                title: "모바일 데이터 사용 제한",
                description: "Wi-Fi에서만 영상 재생(다운로드)을 합니다.",
                accessory: .toggle(
                    get: { PreferenceManager.allowsWWANLimit },
                    set: { PreferenceManager.allowsWWANLimit = $0 }
                )
            ),
            SettingItem(
                title: "화면/재생 설정",
                description: "화면 제스처, 자동 재생 ON/OFF 등을 설정합니다.",
                accessory: .navigation(detail: nil, makeViewController: { [weak self] in
                    ScreenPlaybackSettingViewController(channel: self?.channel)
                })
            )
        ]
        // 좌수 모드는 SL 과 동일하게 iPad 한정 노출 (persist-only).
        if UIDevice.current.userInterfaceIdiom == .pad {
            playerItems.append(
                SettingItem(
                    title: "좌수 모드",
                    accessory: .toggle(
                        get: { PreferenceManager.useLeftHandedMode },
                        set: { PreferenceManager.useLeftHandedMode = $0 }
                    )
                )
            )
        }
        playerItems.append(
            SettingItem(
                title: "저장 용량/캐시",
                accessory: .navigation(detail: nil, makeViewController: { [weak self] in
                    StorageCacheSettingViewController(channel: self?.channel)
                })
            )
        )

        return [
            SettingSection(title: "플레이어 설정", items: playerItems),
            SettingSection(title: "앱 정보", items: [
                SettingItem(title: "앱 버전", accessory: .detail(value: {
                    Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
                }))
            ])
        ]
    }
}
