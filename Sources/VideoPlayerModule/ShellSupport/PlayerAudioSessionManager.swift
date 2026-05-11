//
//  PlayerAudioSessionManager.swift
//  SmartPlayer
//
//  Created by 모바일개발팀_정준영 on 2026/04/17.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import AVFoundation

public protocol PlayerAudioSessionControlling {
    func setCategory(
        _ category: AVAudioSession.Category,
        mode: AVAudioSession.Mode,
        options: AVAudioSession.CategoryOptions
    ) throws
    func setActive(_ active: Bool, options: AVAudioSession.SetActiveOptions) throws
}

extension AVAudioSession: PlayerAudioSessionControlling {}

@MainActor
public final class PlayerAudioSessionManager {
    public static let shared = PlayerAudioSessionManager()

    private let session: PlayerAudioSessionControlling
    private var retainCount = 0

    public init(session: PlayerAudioSessionControlling = AVAudioSession.sharedInstance()) {
        self.session = session
    }

    public func acquire(
        category: AVAudioSession.Category = .playback,
        mode: AVAudioSession.Mode = .moviePlayback,
        options: AVAudioSession.CategoryOptions = []
    ) throws {
        guard retainCount == 0 else {
            retainCount += 1
            return
        }

        try session.setCategory(category, mode: mode, options: options)
        try session.setActive(true, options: [])
        retainCount = 1
    }

    public func release(options: AVAudioSession.SetActiveOptions = [.notifyOthersOnDeactivation]) throws {
        guard retainCount > 0 else {
            return
        }

        retainCount -= 1

        guard retainCount == 0 else {
            return
        }

        try session.setActive(false, options: options)
    }
}
