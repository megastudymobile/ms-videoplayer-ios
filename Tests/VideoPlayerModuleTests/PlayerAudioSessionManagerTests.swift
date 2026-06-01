#if canImport(UIKit)

import AVFoundation
import Testing
@testable import VideoPlayerShellSupport

@MainActor
@Suite("PlayerAudioSessionManager 세션 retain/release 동작")
struct PlayerAudioSessionManagerTests {
    @Test("첫 acquire에서만 세션을 활성화한다")
    func acquireActivatesSessionOnlyForFirstRetain() throws {
        let session = FakeAudioSession()
        let manager = PlayerAudioSessionManager(session: session)

        try manager.acquire(category: .playback, mode: .spokenAudio, options: [.mixWithOthers])
        try manager.acquire(category: .playback, mode: .moviePlayback, options: [])

        #expect(
            session.categoryCalls == [
                .init(category: .playback, mode: .spokenAudio, options: [.mixWithOthers])
            ]
        )
        #expect(session.activeCalls == [.init(active: true, options: [])])
    }

    @Test("마지막 retain 해제 후에만 세션을 비활성화한다")
    func releaseDeactivatesSessionOnlyAfterFinalRetain() throws {
        let session = FakeAudioSession()
        let manager = PlayerAudioSessionManager(session: session)

        try manager.acquire()
        try manager.acquire()

        try manager.release()
        #expect(
            session.activeCalls == [.init(active: true, options: [])]
        )

        try manager.release(options: [.notifyOthersOnDeactivation])
        #expect(
            session.activeCalls == [
                .init(active: true, options: []),
                .init(active: false, options: [.notifyOthersOnDeactivation])
            ]
        )
    }

    @Test("활성화 실패 시 세션을 retain하지 않는다")
    func failedActivationDoesNotRetainSession() throws {
        let session = FakeAudioSession()
        session.activationError = FakeAudioSessionError.activationFailed
        let manager = PlayerAudioSessionManager(session: session)

        #expect(throws: (any Error).self) { try manager.acquire() }

        session.activationError = nil
        try manager.acquire()

        #expect(
            session.activeCalls == [
                .init(active: true, options: []),
                .init(active: true, options: [])
            ]
        )
    }

    @Test("acquire 없이 release 호출은 무동작이다")
    func releaseWithoutAcquireIsNoOp() throws {
        let session = FakeAudioSession()
        let manager = PlayerAudioSessionManager(session: session)

        try manager.release()

        #expect(session.categoryCalls.isEmpty)
        #expect(session.activeCalls.isEmpty)
    }

    @Test("첫 acquire의 카테고리 설정 실패 시 세션을 retain하지 않는다")
    func failedFirstAcquireDoesNotRetainSession() throws {
        let session = FakeAudioSession()
        session.categoryError = FakeAudioSessionError.categoryFailed
        let manager = PlayerAudioSessionManager(session: session)

        #expect(throws: (any Error).self) { try manager.acquire() }

        session.categoryError = nil
        try manager.acquire(category: .playback, mode: .moviePlayback, options: [.duckOthers])

        #expect(session.categoryCalls.count == 2)
        #expect(
            session.activeCalls == [.init(active: true, options: [])]
        )
    }
}

private enum FakeAudioSessionError: Error {
    case categoryFailed
    case activationFailed
    case deactivationFailed
}

private struct RecordedCategoryCall: Equatable {
    let category: AVAudioSession.Category
    let mode: AVAudioSession.Mode
    let options: AVAudioSession.CategoryOptions
}

private struct RecordedActiveCall: Equatable {
    let active: Bool
    let options: AVAudioSession.SetActiveOptions
}

private final class FakeAudioSession: PlayerAudioSessionControlling {
    var categoryCalls: [RecordedCategoryCall] = []
    var activeCalls: [RecordedActiveCall] = []
    var categoryError: FakeAudioSessionError?
    var activationError: FakeAudioSessionError?
    var deactivationError: FakeAudioSessionError?

    func setCategory(
        _ category: AVAudioSession.Category,
        mode: AVAudioSession.Mode,
        options: AVAudioSession.CategoryOptions
    ) throws {
        categoryCalls.append(.init(category: category, mode: mode, options: options))

        if let categoryError {
            throw categoryError
        }
    }

    func setActive(_ active: Bool, options: AVAudioSession.SetActiveOptions) throws {
        activeCalls.append(.init(active: active, options: options))

        if active {
            if let activationError {
                throw activationError
            }
        } else if let deactivationError {
            throw deactivationError
        }
    }
}

#endif
