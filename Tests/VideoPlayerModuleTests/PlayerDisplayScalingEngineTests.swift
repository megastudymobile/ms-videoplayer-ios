import Foundation
import Testing
@testable import VideoPlayerCore

@Suite("Player display scaling engine 검증")
struct PlayerDisplayScalingEngineTests {
    @Test("engine가 scaling만 지원할 때 display scaling 명령을 위임")
    func delegatesDisplayScalingWhenEngineSupportsOnlyScalingControl() async throws {
        let engine = DisplayScalingOnlyEngine()
        let core = PlayerCore(
            engine: engine,
            engineRuntimeTraits: DisplayScalingOnlyEngine.runtimeTraits
        )

        try await core.execute(command: .setDisplayScaleMode(.aspectFill))
        try await core.execute(command: .setDisplayScaled(true))
        try await core.execute(command: .toggleDisplayScaleMode)
        try await core.execute(command: .toggleDisplayScaling)

        #expect(await engine.recordedDisplayScaleMode == .aspectFill)
        #expect(await engine.toggleDisplayScaleModeCallCount == 2)
    }

    @Test("engine가 scaling만 지원할 때 display lock을 거부")
    func rejectsDisplayLockWhenEngineSupportsOnlyScalingControl() async throws {
        let engine = DisplayScalingOnlyEngine()
        let core = PlayerCore(
            engine: engine,
            engineRuntimeTraits: DisplayScalingOnlyEngine.runtimeTraits
        )

        do {
            try await core.execute(command: .setDisplayLocked(true))
            Issue.record("Display lock should fail when only display scaling is supported.")
        } catch let error as PlayerError {
            guard case .unsupportedCommand = error else {
                Issue.record("Unexpected PlayerError: \(error)")
                return
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}

private actor DisplayScalingOnlyEngine: PlayerPlaybackEngine {
    nonisolated static let runtimeTraits: EngineRuntimeTraits = .default

    let outputStream: AsyncStream<PlayerEngineOutput> = AsyncStream { $0.finish() }

    private(set) var recordedDisplayScale: Bool?
    private(set) var recordedDisplayScaleMode: PlayerDisplayScaleMode?
    private(set) var toggleDisplayScaleModeCallCount = 0

    func handle(_ command: PlaybackCommand) async throws {
        switch command {
        case .setDisplayScaled(let isScaled):
            recordedDisplayScale = isScaled
        case .setDisplayScaleMode(let mode):
            recordedDisplayScaleMode = mode
        case .toggleDisplayScaling, .toggleDisplayScaleMode:
            toggleDisplayScaleModeCallCount += 1
        case .load, .play, .pause, .seek, .seekWithOrigin, .setSkipInterval, .stop:
            break
        case .setPlaybackRate, .setSubtitleVisible, .selectSubtitleTrack, .setCaptionFontSize,
             .addBookmark, .addBookmarkWithTitle, .removeBookmark, .selectSubtitleFile,
             .setDisplayLocked, .scroll, .stopScroll, .changeBandwidth:
            throw PlayerError.unsupportedCommand("unsupported")
        }
    }

    nonisolated func supports(_ feature: PlayerFeature) -> Bool {
        switch feature {
        case .displayScaling:
            return true
        case .playbackRate, .subtitles, .externalSubtitles, .bookmarks, .titledBookmarks,
             .zoom, .scroll, .adaptiveStreaming, .pictureInPicture, .displayLock, .seekPreview:
            return false
        }
    }
}
