//
//  PlayerControlChannel.swift
//  VideoPlayerExample
//
//  Created by JunyoungJung on 2026/06/08.
//
//  하단 테스트 콘솔 pane → 플레이어 제어 채널.
//  pane 이 PlayerViewController 구체 타입에 결합하지 않도록 protocol 로만 의존한다 (DIP).
//  pane 측 참조는 retain cycle 방지를 위해 반드시 weak 로 보관할 것.
//

import Foundation
import VideoPlayerCore
import VideoPlayerSkin

@MainActor
protocol PlayerControlChannel: AnyObject {
    /// 현재 skin 상태 스냅샷 (currentTime/duration/rate/lock 등).
    var currentSkinState: PlayerSkinState { get }
    /// 마지막으로 로드된 북마크 목록 (pane 활성화 시 초기값 pull 용 — bookmarksDidLoad 이벤트 누락 대비).
    var loadedBookmarks: [Bookmark] { get }
    /// 엔진 가용 기능 — pane이 미지원 기능 UI를 사전에 비활성/안내한다.
    var availableFeatures: Set<PlayerFeature> { get }

    func togglePlayPause()
    func skip(by delta: TimeInterval)
    func seek(to time: TimeInterval)
    func setPlaybackRate(_ rate: Double)
    func addBookmarkAtCurrentTime()
    func removeBookmark(at position: TimeInterval)
    func setCaptionFontSize(_ size: Int)
    func setCaptionHidden(_ hidden: Bool)
}
