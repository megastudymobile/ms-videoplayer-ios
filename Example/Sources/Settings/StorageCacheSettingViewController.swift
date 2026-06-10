//
//  StorageCacheSettingViewController.swift
//  VideoPlayerExample
//
//  Created by JunyoungJung on 2026/06/09.
//
//  저장 용량/캐시 — SLSettingPlayerStorageCacheViewController parity.
//  Kollus storage(KollusDownloadCenter)에서 값을 async 로 조회한다.
//  시뮬레이터는 실재생 미지원이라 storage 가 nil → 모든 값 "—" 표시.
//

import UIKit
import VideoPlayerEngineKollus

@MainActor
final class StorageCacheSettingViewController: SettingsListViewController {
    private static let placeholder = "—"

    private var storageSizeText = placeholder
    private var cacheSizeText = placeholder
    private var playerIDText = placeholder
    private var playerVersionText = placeholder

    override var screenTitle: String { "저장 용량/캐시" }

    override func viewDidLoad() {
        super.viewDidLoad()
        refresh()
    }

    override func buildSections() -> [SettingSection] {
        [
            SettingSection(title: "다운로드 받은 강의 용량", items: [
                SettingItem(title: "다운로드 용량", accessory: .detail(value: { [weak self] in
                    self?.storageSizeText ?? Self.placeholder
                }))
            ]),
            SettingSection(title: "스트리밍 재생 시 사용된 캐시", items: [
                SettingItem(title: "캐시 용량", accessory: .cacheClear(
                    value: { [weak self] in self?.cacheSizeText ?? Self.placeholder },
                    clearTitle: "비우기",
                    onClear: { [weak self] in self?.clearCache() }
                ))
            ]),
            SettingSection(title: "플레이어 정보", items: [
                SettingItem(title: "플레이어 ID", accessory: .detail(value: { [weak self] in
                    self?.playerIDText ?? Self.placeholder
                })),
                SettingItem(title: "플레이어 버전", accessory: .detail(value: { [weak self] in
                    self?.playerVersionText ?? Self.placeholder
                }))
            ])
        ]
    }

    // MARK: - 값 조회/갱신

    private func refresh() {
        guard let downloads = PlayerModuleProvider.shared.downloads else {
            return   // 시뮬레이터/미인증 — 기본 "—" 유지.
        }
        Task { @MainActor [weak self] in
            let metrics = try? await downloads.storageMetrics()
            let id = (try? await downloads.playerID()).flatMap { $0 }
            let version = (try? await downloads.playerVersion()).flatMap { $0 }
            guard let self else { return }
            self.storageSizeText = Self.format(metrics?.downloadedBytes ?? 0)
            self.cacheSizeText = Self.format(metrics?.streamingCacheBytes ?? 0)
            self.playerIDText = id ?? Self.placeholder
            self.playerVersionText = version ?? Self.placeholder
            self.reloadSections()
        }
    }

    private func clearCache() {
        guard let downloads = PlayerModuleProvider.shared.downloads else { return }
        Task { @MainActor [weak self] in
            try? await downloads.clearStreamingCache()
            self?.refresh()
        }
    }

    private static func format(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
