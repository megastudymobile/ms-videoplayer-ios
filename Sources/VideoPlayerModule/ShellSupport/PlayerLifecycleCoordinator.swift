//
//  PlayerLifecycleCoordinator.swift
//  VideoPlayerModule
//
//  Created by 모바일개발팀_정준영 on 2026/04/17.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

import AVFoundation
import UIKit
import VideoPlayerCore

@MainActor
public final class PlayerLifecycleCoordinator {
    private let controlUseCase: ControlPlaybackUseCaseProtocol
    private let policy: PlayerFeaturePolicy
    private let engineCapabilities: EngineCapabilities
    private let onEvent: ((PlayerEvent) -> Void)?
    private let notificationCenter: NotificationCenter
    private var observers: [NSObjectProtocol] = []

    public init(
        controlUseCase: ControlPlaybackUseCaseProtocol,
        policy: PlayerFeaturePolicy,
        engineCapabilities: EngineCapabilities,
        notificationCenter: NotificationCenter = .default,
        onEvent: ((PlayerEvent) -> Void)? = nil
    ) {
        self.controlUseCase = controlUseCase
        self.policy = policy
        self.engineCapabilities = engineCapabilities
        self.notificationCenter = notificationCenter
        self.onEvent = onEvent
    }

    public func start() {
        guard observers.isEmpty else {
            return
        }

        observers.append(
            notificationCenter.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handleDidEnterBackground()
                }
            }
        )

        observers.append(
            notificationCenter.addObserver(
                forName: AVAudioSession.interruptionNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                Task { @MainActor [weak self] in
                    self?.handleAudioInterruption(notification)
                }
            }
        )
    }

    public func stop() {
        observers.forEach(notificationCenter.removeObserver(_:))
        observers.removeAll()
    }

    private func handleDidEnterBackground() {
        guard policy.allowsBackgroundPlayback else {
            pauseForLifecycleTransition()
            return
        }

        guard engineCapabilities.contains(.continuesWithoutSurface) else {
            onEvent?(.policyDowngraded(reason: .missingContinuesWithoutSurface))
            pauseForLifecycleTransition()
            return
        }
    }

    private func handleAudioInterruption(_ notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: typeValue)
        else {
            return
        }

        switch type {
        case .began:
            pauseForLifecycleTransition()
        case .ended:
            break
        @unknown default:
            break
        }
    }

    private func pauseForLifecycleTransition() {
        Task { @MainActor [controlUseCase] in
            try? await controlUseCase.execute(command: .pause)
        }
    }
}
