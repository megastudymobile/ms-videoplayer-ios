//
//  PlayerLifecycleCoordinator.swift
//  VideoPlayerModule
//
//  Created by 모바일팀_정준영 on 2026/04/17.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import AVFoundation
import UIKit
import VideoPlayerCore

@MainActor
public final class PlayerLifecycleCoordinator {
    public typealias SendCommand = @MainActor (PlaybackCommand) async throws -> Void

    private let sendCommand: SendCommand
    private let policy: PlayerFeaturePolicy
    private let engineCapabilities: EngineCapabilities
    private let onEvent: ((PlayerEvent) -> Void)?
    private let notificationCenter: NotificationCenter
    private var observers: [NSObjectProtocol] = []

    public init(
        sendCommand: @escaping SendCommand,
        policy: PlayerFeaturePolicy,
        engineCapabilities: EngineCapabilities,
        notificationCenter: NotificationCenter = .default,
        onEvent: ((PlayerEvent) -> Void)? = nil
    ) {
        self.sendCommand = sendCommand
        self.policy = policy
        self.engineCapabilities = engineCapabilities
        self.notificationCenter = notificationCenter
        self.onEvent = onEvent
    }

    /// PlayerCore에 직접 명령을 위임하는 편의 생성자.
    public convenience init(
        core: PlayerCore,
        policy: PlayerFeaturePolicy,
        engineCapabilities: EngineCapabilities,
        notificationCenter: NotificationCenter = .default,
        onEvent: ((PlayerEvent) -> Void)? = nil
    ) {
        self.init(
            sendCommand: { try await core.execute(command: $0) },
            policy: policy,
            engineCapabilities: engineCapabilities,
            notificationCenter: notificationCenter,
            onEvent: onEvent
        )
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
        Task { @MainActor [sendCommand] in
            try? await sendCommand(.pause)
        }
    }
}
