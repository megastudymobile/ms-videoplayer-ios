//
//  DownloadCenterViewModel.swift
//  VideoPlayerExample
//
//  Created by JunyoungJung on 2026/06/10.
//
//  DownloadedContent → 화면 행 변환 (순수 로직 — UIKit 무지, 단위 테스트 대상).
//

import Foundation
import VideoPlayerCore

enum DownloadCenterViewModel {
    struct Row: Equatable {
        let id: String
        let title: String
        let statusText: String
        let licenseText: String
        /// 완료 + 라이선스 유효 — 탭 시 오프라인 재생 진입 가능.
        let isPlayable: Bool
        /// 진행 중 — 탭 시 취소 안내.
        let isInProgress: Bool
        /// 재생 불가 사유 (만료 등). isPlayable=false인 완료 항목에서 사용자 안내용.
        let playabilityIssue: PlayerError?
    }

    static func rows(from contents: [DownloadedContent], now: Date = Date()) -> [Row] {
        contents.map { content in
            let issue = content.validateOfflinePlayability(now: now)
            let isCompleted = content.download == .completed
            return Row(
                id: content.id,
                title: content.title.isEmpty ? content.id : content.title,
                statusText: statusText(for: content.download),
                licenseText: licenseText(for: content.license, now: now),
                isPlayable: isCompleted && issue == nil,
                isInProgress: isInProgress(content.download),
                playabilityIssue: isCompleted ? issue : nil
            )
        }
    }

    static func statusText(for status: DownloadedContent.DownloadStatus) -> String {
        switch status {
        case .notDownloaded:
            return "대기"
        case .inProgress(let percent, let bytes):
            return "다운로드 중 \(Int(percent))% (\(formatBytes(bytes)))"
        case .completed:
            return "완료"
        }
    }

    static func licenseText(for license: DownloadedContent.LicenseStatus, now: Date = Date()) -> String {
        switch license {
        case .unknown:
            return "라이선스 정보 없음"
        case .expired:
            return "라이선스 만료 — 갱신 필요"
        case .valid(let constraints):
            var parts: [String] = []
            if let expiresAt = constraints.expiresAt {
                parts.append(expiresAt <= now ? "기한 만료" : "만료일 \(Self.dateFormatter.string(from: expiresAt))")
            }
            if let count = constraints.playCountRemaining {
                parts.append("잔여 \(count)회")
            }
            if let time = constraints.playTimeRemaining {
                parts.append("잔여 \(Int(time / 60))분")
            }
            if constraints.needsRenewalPrompt {
                parts.append("갱신 권장")
            }
            return parts.isEmpty ? "무제한" : parts.joined(separator: " · ")
        }
    }

    static func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    static func metricsText(_ metrics: StorageMetrics) -> String {
        "다운로드 \(formatBytes(metrics.downloadedBytes)) · 스트리밍 캐시 \(formatBytes(metrics.streamingCacheBytes))"
    }

    private static func isInProgress(_ status: DownloadedContent.DownloadStatus) -> Bool {
        if case .inProgress = status { return true }
        return false
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter
    }()
}
