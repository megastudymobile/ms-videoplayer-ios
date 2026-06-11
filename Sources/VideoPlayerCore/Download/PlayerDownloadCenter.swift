//
//  PlayerDownloadCenter.swift
//  VideoPlayerModule
//
//  Created by 모바일팀_정준영 on 2026/06/10.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import Foundation

/// 다운로드 이벤트. 다운로드 실패가 이 스트림으로 전파된다 — 폴링으로 간접 감지하지 않는다.
public enum DownloadEvent: Sendable {
    case completed(contentID: String)
    case failed(contentID: String, error: PlayerError)
    /// 라이선스 일괄 갱신 진행 (current/total)
    case licenseRenewalProgressed(current: Int, total: Int)
    case licenseRenewalFailed(error: PlayerError)
}

public enum LicenseRenewalScope: Sendable, Equatable {
    case all
    case expiredOnly
}

public struct StorageMetrics: Sendable, Equatable {
    /// 다운로드된 콘텐츠 총 용량(byte)
    public let downloadedBytes: Int64
    /// 스트리밍 캐시 누적 용량(byte)
    public let streamingCacheBytes: Int64

    public init(downloadedBytes: Int64, streamingCacheBytes: Int64) {
        self.downloadedBytes = downloadedBytes
        self.streamingCacheBytes = streamingCacheBytes
    }
}

/// 엔진 중립 다운로드/오프라인 운영 계약.
/// host는 이 프로토콜만 의존한다 — 벤더 SDK 타입은 조립 지점(factory) 밖으로 나오지 않는다.
public protocol PlayerDownloadCenter: Actor {
    /// 다운로드 콘텐츠 목록 스냅샷 스트림. 변경 시마다 전체 목록을 재발행한다.
    nonisolated var contents: AsyncStream<[DownloadedContent]> { get }
    /// 개별 다운로드/라이선스 이벤트 스트림.
    nonisolated var events: AsyncStream<DownloadEvent> { get }

    /// 콘텐츠 URL을 등록하고 재생/다운로드용 콘텐츠 ID를 반환한다.
    func resolve(contentURL: String) async throws -> String
    /// 이미 등록된 URL의 콘텐츠 ID 조회. 미등록이면 nil.
    func check(contentURL: String) async throws -> String?
    func startDownload(contentID: String) async throws
    func cancelDownload(contentID: String) async throws
    func remove(contentID: String) async throws
    func clearStreamingCache() async throws
    func renewLicenses(scope: LicenseRenewalScope) async throws
    func currentContents() async throws -> [DownloadedContent]
    func storageMetrics() async throws -> StorageMetrics
}
