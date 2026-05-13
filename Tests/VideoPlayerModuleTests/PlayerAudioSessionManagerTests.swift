#if canImport(UIKit)

import AVFoundation
import XCTest
@testable import VideoPlayerModule

@MainActor
final class PlayerAudioSessionManagerTests: XCTestCase {
    func testAcquireActivatesSessionOnlyForFirstRetain() throws {
        let session = FakeAudioSession()
        let manager = PlayerAudioSessionManager(session: session)

        try manager.acquire(category: .playback, mode: .spokenAudio, options: [.mixWithOthers])
        try manager.acquire(category: .playback, mode: .moviePlayback, options: [])

        XCTAssertEqual(
            session.categoryCalls,
            [
                .init(category: .playback, mode: .spokenAudio, options: [.mixWithOthers])
            ]
        )
        XCTAssertEqual(session.activeCalls, [.init(active: true, options: [])])
    }

    func testReleaseDeactivatesSessionOnlyAfterFinalRetain() throws {
        let session = FakeAudioSession()
        let manager = PlayerAudioSessionManager(session: session)

        try manager.acquire()
        try manager.acquire()

        try manager.release()
        XCTAssertEqual(
            session.activeCalls,
            [.init(active: true, options: [])]
        )

        try manager.release(options: [.notifyOthersOnDeactivation])
        XCTAssertEqual(
            session.activeCalls,
            [
                .init(active: true, options: []),
                .init(active: false, options: [.notifyOthersOnDeactivation])
            ]
        )
    }

    func testFailedActivationDoesNotRetainSession() throws {
        let session = FakeAudioSession()
        session.activationError = FakeAudioSessionError.activationFailed
        let manager = PlayerAudioSessionManager(session: session)

        XCTAssertThrowsError(try manager.acquire())

        session.activationError = nil
        try manager.acquire()

        XCTAssertEqual(
            session.activeCalls,
            [
                .init(active: true, options: []),
                .init(active: true, options: [])
            ]
        )
    }

    func testReleaseWithoutAcquireIsNoOp() throws {
        let session = FakeAudioSession()
        let manager = PlayerAudioSessionManager(session: session)

        try manager.release()

        XCTAssertTrue(session.categoryCalls.isEmpty)
        XCTAssertTrue(session.activeCalls.isEmpty)
    }

    func testFailedFirstAcquireDoesNotRetainSession() throws {
        let session = FakeAudioSession()
        session.categoryError = FakeAudioSessionError.categoryFailed
        let manager = PlayerAudioSessionManager(session: session)

        XCTAssertThrowsError(try manager.acquire())

        session.categoryError = nil
        try manager.acquire(category: .playback, mode: .moviePlayback, options: [.duckOthers])

        XCTAssertEqual(session.categoryCalls.count, 2)
        XCTAssertEqual(
            session.activeCalls,
            [.init(active: true, options: [])]
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
