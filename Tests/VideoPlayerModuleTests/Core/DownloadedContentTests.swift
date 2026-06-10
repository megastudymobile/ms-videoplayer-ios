//
//  DownloadedContentTests.swift
//  VideoPlayerModuleTests
//
//  Created by JunyoungJung on 2026/06/10.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

import Foundation
import Testing
import VideoPlayerCore

@Suite("DownloadedContent 오프라인 라이선스 사전 검증")
struct DownloadedContentTests {

    private let now = Date(timeIntervalSince1970: 1_900_000_000)

    private func content(license: DownloadedContent.LicenseStatus) -> DownloadedContent {
        DownloadedContent(id: "mck", download: .completed, license: license)
    }

    @Test("만료 상태는 갱신 필요 에러")
    func expiredLicense_requiresRenewal() {
        let error = content(license: .expired).validateOfflinePlayability(now: now)
        guard case .licenseRenewalRequired = error else {
            Issue.record("licenseRenewalRequired가 아님: \(String(describing: error))")
            return
        }
    }

    @Test("만료일 도과는 갱신 필요 에러")
    func pastExpiryDate_requiresRenewal() {
        let license = DownloadedContent.LicenseStatus.valid(.init(
            expiresAt: now.addingTimeInterval(-1)
        ))
        let error = content(license: license).validateOfflinePlayability(now: now)
        guard case .licenseRenewalRequired = error else {
            Issue.record("licenseRenewalRequired가 아님: \(String(describing: error))")
            return
        }
    }

    @Test("재생 횟수 소진은 licenseExpired")
    func exhaustedPlayCount_isLicenseExpired() {
        let license = DownloadedContent.LicenseStatus.valid(.init(
            expiresAt: now.addingTimeInterval(3600),
            playCountRemaining: 0
        ))
        let error = content(license: license).validateOfflinePlayability(now: now)
        guard case .licenseExpired = error else {
            Issue.record("licenseExpired가 아님: \(String(describing: error))")
            return
        }
    }

    @Test("재생 시간 소진은 licenseExpired")
    func exhaustedPlayTime_isLicenseExpired() {
        let license = DownloadedContent.LicenseStatus.valid(.init(
            playTimeRemaining: 0
        ))
        let error = content(license: license).validateOfflinePlayability(now: now)
        guard case .licenseExpired = error else {
            Issue.record("licenseExpired가 아님: \(String(describing: error))")
            return
        }
    }

    @Test("제약 없는 유효 라이선스는 통과", arguments: [
        DownloadedContent.LicenseStatus.unknown,
        .valid(.init()),
        .valid(.init(expiresAt: Date(timeIntervalSince1970: 2_000_000_000), playCountRemaining: 3, playTimeRemaining: 600))
    ])
    func validLicense_passes(license: DownloadedContent.LicenseStatus) {
        #expect(content(license: license).validateOfflinePlayability(now: now) == nil)
    }
}
