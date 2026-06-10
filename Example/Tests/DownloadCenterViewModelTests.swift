//
//  DownloadCenterViewModelTests.swift
//  VideoPlayerExampleTests
//
//  Created by JunyoungJung on 2026/06/10.
//

import Foundation
import Testing
import VideoPlayerCore
@testable import VideoPlayerExample

@Suite("DownloadCenterViewModel 행 변환")
struct DownloadCenterViewModelTests {

    private let now = Date(timeIntervalSince1970: 1_900_000_000)

    @Test("완료 + 유효 라이선스 → 재생 가능")
    func completedWithValidLicense_isPlayable() {
        let content = DownloadedContent(
            id: "mck-1",
            title: "강의 1",
            download: .completed,
            license: .valid(.init(expiresAt: now.addingTimeInterval(3600), playCountRemaining: 3))
        )

        let rows = DownloadCenterViewModel.rows(from: [content], now: now)

        #expect(rows.count == 1)
        #expect(rows[0].isPlayable)
        #expect(rows[0].isInProgress == false)
        #expect(rows[0].playabilityIssue == nil)
        #expect(rows[0].title == "강의 1")
    }

    @Test("완료 + 만료 라이선스 → 재생 불가 + 사유 보존")
    func completedWithExpiredLicense_isNotPlayable() {
        let content = DownloadedContent(id: "mck-2", download: .completed, license: .expired)

        let rows = DownloadCenterViewModel.rows(from: [content], now: now)

        #expect(rows[0].isPlayable == false)
        guard case .licenseRenewalRequired = rows[0].playabilityIssue else {
            Issue.record("licenseRenewalRequired가 아님: \(String(describing: rows[0].playabilityIssue))")
            return
        }
    }

    @Test("진행 중 → isInProgress + 퍼센트 표기")
    func inProgress_showsPercent() {
        let content = DownloadedContent(
            id: "mck-3",
            download: .inProgress(percent: 42, downloadedBytes: 1_048_576)
        )

        let rows = DownloadCenterViewModel.rows(from: [content], now: now)

        #expect(rows[0].isInProgress)
        #expect(rows[0].isPlayable == false)
        #expect(rows[0].statusText.contains("42%"))
    }

    @Test("미진행 항목 → 재생/취소 대상 아님 + 사유 없음")
    func notDownloaded_hasNoIssueAndNoActions() {
        let content = DownloadedContent(id: "mck-4", download: .notDownloaded, license: .expired)

        let rows = DownloadCenterViewModel.rows(from: [content], now: now)

        // 미완료 항목은 만료여도 playabilityIssue를 노출하지 않는다 (완료 항목 전용 안내).
        #expect(rows[0].playabilityIssue == nil)
        #expect(rows[0].isPlayable == false)
        #expect(rows[0].isInProgress == false)
    }

    @Test("제목 없으면 콘텐츠 ID로 대체")
    func emptyTitle_fallsBackToID() {
        let rows = DownloadCenterViewModel.rows(
            from: [DownloadedContent(id: "mck-5", title: "")],
            now: now
        )
        #expect(rows[0].title == "mck-5")
    }

    @Test("라이선스 텍스트 — 제약 조합 표기")
    func licenseText_combinesConstraints() {
        let license = DownloadedContent.LicenseStatus.valid(.init(
            expiresAt: now.addingTimeInterval(86_400),
            playCountRemaining: 5,
            playTimeRemaining: 1_800,
            needsRenewalPrompt: true
        ))

        let text = DownloadCenterViewModel.licenseText(for: license, now: now)

        #expect(text.contains("잔여 5회"))
        #expect(text.contains("잔여 30분"))
        #expect(text.contains("갱신 권장"))
    }

    @Test("제약 없는 유효 라이선스 → 무제한")
    func unconstrained_isUnlimited() {
        #expect(DownloadCenterViewModel.licenseText(for: .valid(.init()), now: now) == "무제한")
    }

    @Test("만료 라이선스 텍스트")
    func expired_text() {
        #expect(DownloadCenterViewModel.licenseText(for: .expired, now: now).contains("만료"))
    }
}
