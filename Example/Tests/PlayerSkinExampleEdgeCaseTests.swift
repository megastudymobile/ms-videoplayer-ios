//
//  PlayerSkinExampleEdgeCaseTests.swift
//  VideoPlayerExampleTests
//
//  Created by JunyoungJung on 2026/06/11.
//

import Testing
import UIKit
import VideoPlayerCore
import VideoPlayerSkin
@testable import VideoPlayerExample

@MainActor
@Suite("Example skin 엣지케이스")
struct PlayerSkinExampleEdgeCaseTests {
    @Test("LIVE 배지는 duration 미해석 VOD에는 표시하지 않는다")
    func liveBadgeIgnoresDurationUnknownVOD() {
        let block = LiveBadgeBlock()
        let state = PlayerSkinState(
            playbackState: PlaybackState(
                status: .readyToPlay,
                currentTime: 0,
                duration: 0,
                isBuffering: false,
                isLive: false
            ),
            playbackRate: 1.0,
            controlsVisible: true,
            isFullScreenMode: false,
            isDisplayScaled: false
        )

        block.render(state, theme: .default)

        #expect(block.view.isHidden)
    }

    @Test("LIVE 배지는 실제 live 상태에서만 표시한다")
    func liveBadgeShowsForLiveStream() {
        let block = LiveBadgeBlock()
        let state = PlayerSkinState(
            playbackState: PlaybackState(
                status: .playing,
                currentTime: 10,
                duration: 0,
                isBuffering: false,
                isLive: true
            ),
            playbackRate: 1.0,
            controlsVisible: true,
            isFullScreenMode: false,
            isDisplayScaled: false
        )

        block.render(state, theme: .default)

        #expect(block.view.isHidden == false)
    }

    @Test("북마크 미지원이면 추가 행을 노출하지 않는다")
    func bookmarkPaneHidesAddRowWhenUnsupported() {
        let channel = FakePlayerControlChannel(availableFeatures: [])
        let pane = BookmarkPaneViewController(channel: channel)
        pane.loadViewIfNeeded()

        #expect(pane.tableView(UITableView(), numberOfRowsInSection: 0) == 0)
    }

    @Test("add-only 북마크 엔진은 삭제 swipe를 노출하지 않는다")
    func bookmarkPaneHidesDeletionForAddOnlyEngine() {
        let channel = FakePlayerControlChannel(
            loadedBookmarks: [
                Bookmark(position: 10, title: "10", kind: .user)
            ],
            availableFeatures: [.bookmarks]
        )
        let pane = BookmarkPaneViewController(channel: channel)
        pane.loadViewIfNeeded()

        #expect(pane.tableView(UITableView(), numberOfRowsInSection: 0) == 1)
        #expect(pane.tableView(UITableView(), numberOfRowsInSection: 1) == 1)
        #expect(pane.tableView(UITableView(), canEditRowAt: IndexPath(row: 0, section: 1)) == false)
    }
}

@MainActor
private final class FakePlayerControlChannel: PlayerControlChannel {
    var currentSkinState: PlayerSkinState = .initial
    var loadedBookmarks: [Bookmark]
    var availableFeatures: Set<PlayerFeature>

    private(set) var addedBookmarkCount = 0
    private(set) var removedBookmarkPositions: [TimeInterval] = []

    init(
        loadedBookmarks: [Bookmark] = [],
        availableFeatures: Set<PlayerFeature>
    ) {
        self.loadedBookmarks = loadedBookmarks
        self.availableFeatures = availableFeatures
    }

    func togglePlayPause() {}
    func skip(by delta: TimeInterval) {}
    func seek(to time: TimeInterval) {}
    func setPlaybackRate(_ rate: Double) {}
    func addBookmarkAtCurrentTime() { addedBookmarkCount += 1 }
    func removeBookmark(at position: TimeInterval) { removedBookmarkPositions.append(position) }
    func setCaptionFontSize(_ size: Int) {}
    func setCaptionHidden(_ hidden: Bool) {}
}
