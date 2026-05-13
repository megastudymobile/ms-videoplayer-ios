#if canImport(UIKit)

import AVFoundation
import UIKit
import XCTest
@testable import VideoPlayerModule

@MainActor
final class PlayerLifecycleCoordinatorTests: XCTestCase {
    func testDidEnterBackgroundPausesWhenBackgroundPlaybackIsDisabled() async throws {
        let controlUseCase = RecordingControlPlaybackUseCase()
        let notificationCenter = NotificationCenter()
        let coordinator = PlayerLifecycleCoordinator(
            controlUseCase: controlUseCase,
            policy: .default,
            engineCapabilities: [],
            notificationCenter: notificationCenter
        )

        coordinator.start()
        notificationCenter.post(name: UIApplication.didEnterBackgroundNotification, object: nil)

        try await waitUntil {
            controlUseCase.commands == [.pause]
        }
    }

    func testDidEnterBackgroundDowngradesPolicyWhenSurfacelessPlaybackIsUnsupported() async throws {
        let controlUseCase = RecordingControlPlaybackUseCase()
        let notificationCenter = NotificationCenter()
        let eventRecorder = EventRecorder()
        let coordinator = PlayerLifecycleCoordinator(
            controlUseCase: controlUseCase,
            policy: PlayerFeaturePolicy(
                allowsBackgroundPlayback: true,
                maxPlaybackRate: 2.0,
                allowsAutoplay: true
            ),
            engineCapabilities: [],
            notificationCenter: notificationCenter,
            onEvent: { event in
                eventRecorder.append(event)
            }
        )

        coordinator.start()
        notificationCenter.post(name: UIApplication.didEnterBackgroundNotification, object: nil)

        try await waitUntil {
            controlUseCase.commands == [.pause]
        }

        XCTAssertEqual(
            eventRecorder.events,
            [.policyDowngraded(reason: .missingContinuesWithoutSurface)]
        )
    }

    func testDidEnterBackgroundKeepsPlaybackWhenCapabilityAllowsBackgroundPlayback() async throws {
        let controlUseCase = RecordingControlPlaybackUseCase()
        let notificationCenter = NotificationCenter()
        let eventRecorder = EventRecorder()
        let coordinator = PlayerLifecycleCoordinator(
            controlUseCase: controlUseCase,
            policy: PlayerFeaturePolicy(
                allowsBackgroundPlayback: true,
                maxPlaybackRate: 2.0,
                allowsAutoplay: true
            ),
            engineCapabilities: [.continuesWithoutSurface],
            notificationCenter: notificationCenter,
            onEvent: { event in
                eventRecorder.append(event)
            }
        )

        coordinator.start()
        notificationCenter.post(name: UIApplication.didEnterBackgroundNotification, object: nil)

        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertTrue(controlUseCase.commands.isEmpty)
        XCTAssertTrue(eventRecorder.events.isEmpty)
    }

    func testAudioInterruptionBeganPausesPlayback() async throws {
        let controlUseCase = RecordingControlPlaybackUseCase()
        let notificationCenter = NotificationCenter()
        let coordinator = PlayerLifecycleCoordinator(
            controlUseCase: controlUseCase,
            policy: .default,
            engineCapabilities: [],
            notificationCenter: notificationCenter
        )

        coordinator.start()
        notificationCenter.post(
            name: AVAudioSession.interruptionNotification,
            object: nil,
            userInfo: [
                AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue
            ]
        )

        try await waitUntil {
            controlUseCase.commands == [.pause]
        }
    }

    func testStartIsIdempotentAndStopRemovesObservers() async throws {
        let controlUseCase = RecordingControlPlaybackUseCase()
        let notificationCenter = NotificationCenter()
        let coordinator = PlayerLifecycleCoordinator(
            controlUseCase: controlUseCase,
            policy: .default,
            engineCapabilities: [],
            notificationCenter: notificationCenter
        )

        coordinator.start()
        coordinator.start()
        notificationCenter.post(name: UIApplication.didEnterBackgroundNotification, object: nil)

        try await waitUntil {
            controlUseCase.commands == [.pause]
        }

        coordinator.stop()
        notificationCenter.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(controlUseCase.commands, [.pause])
    }

    private func waitUntil(
        timeout: TimeInterval = 1.0,
        pollInterval: UInt64 = 10_000_000,
        file: StaticString = #filePath,
        line: UInt = #line,
        condition: @escaping @MainActor () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if condition() {
                return
            }

            try await Task.sleep(nanoseconds: pollInterval)
        }

        XCTFail("조건을 만족하지 못했습니다.", file: file, line: line)
    }
}

@MainActor
private final class RecordingControlPlaybackUseCase: ControlPlaybackUseCaseProtocol {
    private(set) var commands: [PlaybackCommand] = []

    func execute(command: PlaybackCommand) async throws {
        commands.append(command)
    }
}

@MainActor
private final class EventRecorder {
    private(set) var events: [PlayerEvent] = []

    func append(_ event: PlayerEvent) {
        events.append(event)
    }
}

#endif
