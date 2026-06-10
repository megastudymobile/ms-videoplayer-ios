//
//  KollusBookmarkStore.swift
//  VideoPlayerModule
//
//  Created by JunyoungJung on 2026/06/10.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

import Foundation
import VideoPlayerCore

/// 낙관적 북마크 캐시.
///
/// Kollus SDK는 로컬 add/remove를 `playerView.bookmarks`에 즉시 반영하지 않는다
/// (서버 동기화 후 reload 시점에만 갱신). SDK 재조회는 직전 낙관적 변경분을 포함하지
/// 못하므로, 마지막 발행 목록을 base로 낙관적 누적을 유지하고 다음 권위 reload 때
/// 자연 수렴시킨다.
struct KollusBookmarkStore: Sendable {
    private(set) var bookmarks: [Bookmark]
    private let duplicateTolerance: TimeInterval

    init(duplicateTolerance: TimeInterval = 0.5, bookmarks: [Bookmark] = []) {
        self.duplicateTolerance = duplicateTolerance
        self.bookmarks = bookmarks
    }

    /// SDK 권위 목록으로 교체 (bookmark delegate reload).
    mutating func replaceAll(_ authoritative: [Bookmark]) {
        bookmarks = authoritative
    }

    /// 낙관적 추가 — tolerance 내 중복 위치는 무시. 갱신된 목록을 반환한다.
    @discardableResult
    mutating func addOptimistically(position: TimeInterval, title: String) -> [Bookmark] {
        if !bookmarks.contains(where: { abs($0.position - position) < duplicateTolerance }) {
            bookmarks.append(Bookmark(position: position, title: title, kind: .user))
            bookmarks.sort { $0.position < $1.position }
        }
        return bookmarks
    }

    /// 낙관적 제거 — tolerance 내 위치 일치 항목 삭제. 갱신된 목록을 반환한다.
    @discardableResult
    mutating func removeOptimistically(position: TimeInterval) -> [Bookmark] {
        bookmarks.removeAll { abs($0.position - position) < duplicateTolerance }
        return bookmarks
    }
}
