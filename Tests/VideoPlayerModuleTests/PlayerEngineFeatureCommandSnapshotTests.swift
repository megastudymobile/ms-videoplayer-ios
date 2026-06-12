#if canImport(UIKit)

import AVFoundation
import Testing
import VideoPlayerCore
@testable import VideoPlayerEngineNative
@testable import VideoPlayerShellSupport

@Suite("엔진 supports/handle 스냅샷")
struct PlayerEngineFeatureCommandSnapshotTests {
    @Test("AVPlayerAdapter supports 신고와 handle 미지원 처리가 일치")
    func avPlayerSupportsMatchesHandle() async throws {
        let adapter = AVPlayerAdapter(player: AVPlayer())
        defer { Task { try? await adapter.handle(.stop) } }

        #expect(PlayerFeature.available(for: adapter) == [.playbackRate, .displayScaling, .seekPreview])
        await expectUnsupported(adapter, command: .setDisplayLocked(true))
        await expectUnsupported(adapter, command: .addBookmark(at: 10))
        await expectNotUnsupported(adapter, command: .setPlaybackRate(1.0))
        await expectNotUnsupported(adapter, command: .setDisplayScaleMode(.aspectFit))
    }

    @Test("UnsupportedEnvironmentEngine supports 신고와 handle 미지원 처리가 일치")
    func unsupportedEnvironmentSupportsMatchesHandle() async {
        let engine = UnsupportedEnvironmentEngine(message: "unsupported")

        #expect(PlayerFeature.available(for: engine) == [.bookmarks, .titledBookmarks])
        await expectUnsupported(engine, command: .setPlaybackRate(1.0))
        await expectUnsupported(engine, command: .setDisplayLocked(true))
        await expectNotUnsupported(engine, command: .addBookmarkWithTitle(at: 10, title: "memo"))
    }
}

private func expectUnsupported(
    _ engine: any PlayerPlaybackEngine,
    command: PlaybackCommand,
    sourceLocation: SourceLocation = #_sourceLocation
) async {
    await #expect(sourceLocation: sourceLocation) {
        try await engine.handle(command)
    } throws: { error in
        guard case PlayerError.unsupportedCommand = error else { return false }
        return true
    }
}

private func expectNotUnsupported(
    _ engine: any PlayerPlaybackEngine,
    command: PlaybackCommand,
    sourceLocation: SourceLocation = #_sourceLocation
) async {
    do {
        try await engine.handle(command)
    } catch PlayerError.unsupportedCommand {
        Issue.record("지원 신고된 명령이 unsupportedCommand를 던짐: \(command)", sourceLocation: sourceLocation)
    } catch {
        return
    }
}

#if canImport(KollusSDKBinary)
import VideoPlayerEngineKollus

extension PlayerEngineFeatureCommandSnapshotTests {
    @MainActor
    @Test("KollusPlayerAdapter supports 신고와 handle 미지원 처리가 일치")
    func kollusSupportsMatchesHandle() async throws {
        let env = KollusEnvironment(
            applicationKey: "k",
            applicationBundleID: "b",
            applicationExpireDate: Date().addingTimeInterval(60 * 60 * 24 * 30)
        )
        let storage = FakeKollusStorage()
        let bootstrapper = KollusSessionBootstrapper(environment: env) { storage }
        let adapter = KollusPlayerAdapter(bootstrapper: bootstrapper, environment: env)

        #expect(PlayerFeature.available(for: adapter) == [
            .playbackRate,
            .subtitles,
            .externalSubtitles,
            .bookmarks,
            .titledBookmarks,
            .zoom,
            .scroll,
            .adaptiveStreaming,
            .displayScaling,
            .seekPreview,
        ])
        await expectUnsupported(adapter, command: .setDisplayLocked(true))
        await expectNotUnsupported(adapter, command: .setPlaybackRate(1.0))
        await expectNotUnsupported(adapter, command: .scroll(by: .zero))
        await expectNotUnsupported(adapter, command: .changeBandwidth(1_000_000))
    }
}
#endif

#endif
