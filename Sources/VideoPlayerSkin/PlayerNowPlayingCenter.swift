//
//  PlayerNowPlayingCenter.swift
//  SmartPlayer
//
//  Created by 모바일팀_정준영 on 2026/05/26.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import Foundation
import MediaPlayer

/// 잠금화면 / Control Center 의 NowPlaying 메타데이터 + remote command 설정 utility.
@MainActor
public enum PlayerNowPlayingCenter {
    public struct Handlers {
        public let onPlay: () -> Void
        public let onPause: () -> Void
        public let onTogglePlayPause: () -> Void
        public let onSkipForward: () -> Void
        public let onSkipBackward: () -> Void

        public init(
            onPlay: @escaping () -> Void,
            onPause: @escaping () -> Void,
            onTogglePlayPause: @escaping () -> Void,
            onSkipForward: @escaping () -> Void,
            onSkipBackward: @escaping () -> Void
        ) {
            self.onPlay = onPlay
            self.onPause = onPause
            self.onTogglePlayPause = onTogglePlayPause
            self.onSkipForward = onSkipForward
            self.onSkipBackward = onSkipBackward
        }
    }

    public static func configure(
        title: String,
        albumTitle: String?,
        skipInterval: TimeInterval,
        handlers: Handlers
    ) {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.removeTarget(nil)
        center.pauseCommand.removeTarget(nil)
        center.togglePlayPauseCommand.removeTarget(nil)
        center.skipForwardCommand.removeTarget(nil)
        center.skipBackwardCommand.removeTarget(nil)

        center.playCommand.isEnabled = true
        center.pauseCommand.isEnabled = true
        center.togglePlayPauseCommand.isEnabled = true
        center.skipForwardCommand.isEnabled = true
        center.skipBackwardCommand.isEnabled = true
        let preferredInterval = NSNumber(value: max(1, skipInterval))
        center.skipForwardCommand.preferredIntervals = [preferredInterval]
        center.skipBackwardCommand.preferredIntervals = [preferredInterval]

        center.playCommand.addTarget { _ in handlers.onPlay(); return .success }
        center.pauseCommand.addTarget { _ in handlers.onPause(); return .success }
        center.togglePlayPauseCommand.addTarget { _ in handlers.onTogglePlayPause(); return .success }
        center.skipForwardCommand.addTarget { _ in handlers.onSkipForward(); return .success }
        center.skipBackwardCommand.addTarget { _ in handlers.onSkipBackward(); return .success }

        var info: [String: Any] = [:]
        info[MPMediaItemPropertyTitle] = title
        info[MPMediaItemPropertyAlbumTitle] = albumTitle ?? "메가스터디 강의"
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    public static func update(currentTime: TimeInterval, duration: TimeInterval, isPlaying: Bool, rate: Double) {
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? rate : 0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    public static func clear() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.removeTarget(nil)
        center.pauseCommand.removeTarget(nil)
        center.togglePlayPauseCommand.removeTarget(nil)
        center.skipForwardCommand.removeTarget(nil)
        center.skipBackwardCommand.removeTarget(nil)
        center.playCommand.isEnabled = false
        center.pauseCommand.isEnabled = false
        center.togglePlayPauseCommand.isEnabled = false
        center.skipForwardCommand.isEnabled = false
        center.skipBackwardCommand.isEnabled = false

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
}
