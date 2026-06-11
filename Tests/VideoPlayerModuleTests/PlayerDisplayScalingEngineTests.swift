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
            #expect(error == .engineError("Display lock is not supported by the current playback engine."))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}

private actor DisplayScalingOnlyEngine: PlayerPlaybackEngine, EngineDisplayScalingAbility {
    nonisolated static let runtimeTraits: EngineRuntimeTraits = .default

    let outputStream: AsyncStream<PlayerEngineOutput> = AsyncStream { $0.finish() }

    private(set) var recordedDisplayScale: Bool?
    private(set) var recordedDisplayScaleMode: PlayerDisplayScaleMode?
    private(set) var toggleDisplayScaleModeCallCount = 0

    func prepare(source: PlaybackSource) async throws {}
    func play() async throws {}
    func pause() async throws {}
    func seek(to time: TimeInterval) async throws {}
    func stop(reason: PlayerStopReason) async throws {}

    func setDisplayScaled(_ isScaled: Bool) async throws {
        recordedDisplayScale = isScaled
    }

    func setDisplayScaleMode(_ mode: PlayerDisplayScaleMode) async throws {
        recordedDisplayScaleMode = mode
    }

    func toggleDisplayScaling() async throws {
        toggleDisplayScaleModeCallCount += 1
    }

    func toggleDisplayScaleMode() async throws {
        toggleDisplayScaleModeCallCount += 1
    }
}
