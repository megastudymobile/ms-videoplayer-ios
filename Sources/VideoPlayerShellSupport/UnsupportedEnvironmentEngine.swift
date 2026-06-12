//
//  UnsupportedEnvironmentEngine.swift
//  VideoPlayerModule
//
//  Created by 모바일팀_정준영 on 2026/06/01.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import Foundation
import VideoPlayerCore

/// 현재 실행 환경(예: iOS 시뮬레이터)에서 특정 엔진(Kollus 등)이 실제 재생을
/// 제공할 수 없을 때 사용하는 no-op 엔진.
///
/// `bind(renderSurface:)` 시점에 렌더 표면에 "미지원" 안내를 표시하고,
/// 재생 관련 명령(`prepare`/`play`/`seek` 등)은 상태를 바꾸지 않는 no-op 으로 처리한다.
/// 호스트 앱은 시뮬레이터 + Kollus 소스 조합에서 본 엔진으로 라우팅한다.
public actor UnsupportedEnvironmentEngine: PlayerEngineAdapter {
    public nonisolated static let runtimeTraits: EngineRuntimeTraits = .default

    public let outputStream: AsyncStream<PlayerEngineOutput>

    private let outputContinuation: AsyncStream<PlayerEngineOutput>.Continuation
    private let message: String
    private weak var renderSurface: PlayerRenderSurface?
    /// 시뮬레이터에서도 북마크 UI 흐름(추가/목록/삭제)을 테스트할 수 있도록 in-memory 로 보관.
    /// 실재생이 없으므로 영속화하지 않는다.
    private var bookmarks: [Bookmark] = []

    public init(message: String) {
        self.message = message
        var continuation: AsyncStream<PlayerEngineOutput>.Continuation?
        self.outputStream = AsyncStream<PlayerEngineOutput>(bufferingPolicy: .unbounded) {
            continuation = $0
        }
        self.outputContinuation = continuation!
    }

    deinit {
        outputContinuation.finish()
    }

    // MARK: - PlayerEngineAdapter

    public func bind(renderSurface: PlayerRenderSurface) {
        self.renderSurface = renderSurface
        let message = self.message

        Task { @MainActor in
            renderSurface.showUnsupportedEnvironment(message: message)
        }
    }

    public func unbindRenderSurface() {
        renderSurface = nil
    }

    // MARK: - PlayerPlaybackEngine

    public func handle(_ command: PlaybackCommand) async throws {
        switch command {
        case .load,
             .play,
             .pause,
             .seek,
             .seekWithOrigin,
             .setSkipInterval,
             .stop:
            break
        case .addBookmark(let time):
            addBookmark(at: time, title: "")
        case .addBookmarkWithTitle(let time, let title):
            addBookmark(at: time, title: title)
        case .removeBookmark(let time):
            removeBookmark(at: time)
        case .setPlaybackRate,
             .setSubtitleVisible,
             .selectSubtitleTrack,
             .setCaptionFontSize,
             .selectSubtitleFile,
             .setDisplayLocked,
             .setDisplayScaleMode,
             .setDisplayScaled,
             .toggleDisplayScaleMode,
             .toggleDisplayScaling,
             .scroll,
             .stopScroll,
             .changeBandwidth:
            throw PlayerError.unsupportedCommand("UnsupportedEnvironmentEngine does not support \(command)")
        }
    }

    public nonisolated func supports(_ feature: PlayerFeature) -> Bool {
        switch feature {
        case .bookmarks, .titledBookmarks:
            return true
        case .playbackRate,
             .subtitles,
             .externalSubtitles,
             .zoom,
             .scroll,
             .adaptiveStreaming,
             .pictureInPicture,
             .displayScaling,
             .displayLock,
             .seekPreview:
            return false
        }
    }

    private func addBookmark(at time: TimeInterval, title: String) {
        let bookmark = Bookmark(position: time, title: title, kind: .user, createdAt: Date())
        bookmarks.append(bookmark)
        bookmarks.sort { $0.position < $1.position }
        emitBookmarks()
    }

    private func removeBookmark(at time: TimeInterval) {
        bookmarks.removeAll { $0.position == time }
        emitBookmarks()
    }

    private func emitBookmarks() {
        outputContinuation.yield(.event(.bookmarksDidLoad(bookmarks)))
    }
}
