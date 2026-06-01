#if canImport(UIKit)

import AVFoundation
import Foundation
import UIKit
import Testing
@testable import VideoPlayerCore
@testable import VideoPlayerShellSupport

@MainActor
@Suite("PlayerLifecycleCoordinator 생명주기/오디오 인터럽션 처리")
struct PlayerLifecycleCoordinatorTests {
    @Test("백그라운드 재생 비활성 시 백그라운드 진입에서 일시정지한다")
    func didEnterBackgroundPausesWhenBackgroundPlaybackIsDisabled() async throws {
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

    @Test("surfaceless 재생 미지원 시 백그라운드 진입에서 정책을 다운그레이드한다")
    func didEnterBackgroundDowngradesPolicyWhenSurfacelessPlaybackIsUnsupported() async throws {
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

        #expect(
            eventRecorder.events == [.policyDowngraded(reason: .missingContinuesWithoutSurface)]
        )
    }

    @Test("capability가 백그라운드 재생을 허용하면 재생을 유지한다")
    func didEnterBackgroundKeepsPlaybackWhenCapabilityAllowsBackgroundPlayback() async throws {
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

        #expect(controlUseCase.commands.isEmpty)
        #expect(eventRecorder.events.isEmpty)
    }

    @Test("오디오 인터럽션 시작 시 재생을 일시정지한다")
    func audioInterruptionBeganPausesPlayback() async throws {
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

    @Test("start는 멱등이며 stop은 옵저버를 제거한다")
    func startIsIdempotentAndStopRemovesObservers() async throws {
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

        #expect(controlUseCase.commands == [.pause])
    }

    private func waitUntil(
        timeout: TimeInterval = 1.0,
        pollInterval: UInt64 = 10_000_000,
        sourceLocation: SourceLocation = #_sourceLocation,
        condition: @escaping @MainActor () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if condition() {
                return
            }

            try await Task.sleep(nanoseconds: pollInterval)
        }

        Issue.record("조건을 만족하지 못했습니다.", sourceLocation: sourceLocation)
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
