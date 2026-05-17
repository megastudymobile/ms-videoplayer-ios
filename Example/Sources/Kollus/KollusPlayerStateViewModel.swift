//
//  KollusPlayerStateViewModel.swift
//  VideoPlayerExample
//
//  Created by 모바일팀_정준영 on 2026/05/17.
//

import Foundation
import VideoPlayerCore

@MainActor
final class KollusPlayerStateViewModel {
    private(set) var state: KollusPlayerControlState = .idle

    private var latestPlaybackState: PlaybackState = .idle
    private var subtitleVisible: Bool = true
    private var captionFontSize: Int = 16
    private var displayLocked: Bool = false
    private var selectedRate: Double = 1.0
    private var errorMessage: String?

    private let allowedRates: [Double] = [0.75, 1.0, 1.25, 1.5, 2.0]

    func apply(playbackState: PlaybackState) -> KollusPlayerControlState {
        latestPlaybackState = playbackState
        if case .failed(let error) = playbackState.status {
            errorMessage = error.localizedDescription
        }
        state = buildState()
        return state
    }

    func apply(event: PlayerEvent) -> KollusPlayerControlState? {
        switch event {
        case .didFail(let error):
            errorMessage = error.localizedDescription
        default:
            break
        }
        state = buildState()
        return state
    }

    func setSubtitleVisible(_ isVisible: Bool) -> KollusPlayerControlState {
        subtitleVisible = isVisible
        state = buildState()
        return state
    }

    func setCaptionFontSize(_ size: Int) -> KollusPlayerControlState {
        captionFontSize = size
        state = buildState()
        return state
    }

    func setDisplayLocked(_ isLocked: Bool) -> KollusPlayerControlState {
        displayLocked = isLocked
        state = buildState()
        return state
    }

    func setPlaybackRate(_ rate: Double) -> KollusPlayerControlState {
        selectedRate = rate
        state = buildState()
        return state
    }

    private func buildState() -> KollusPlayerControlState {
        let status = latestPlaybackState.status
        let isPlayable: Bool
        let playPauseTitle: String

        switch status {
        case .idle, .preparing:
            isPlayable = false
            playPauseTitle = "Play"
        case .readyToPlay, .paused, .finished:
            isPlayable = true
            playPauseTitle = "Play"
        case .playing, .buffering:
            isPlayable = true
            playPauseTitle = "Pause"
        case .failed:
            isPlayable = false
            playPauseTitle = "Play"
        }

        let progress: Double
        if latestPlaybackState.duration > 0 {
            progress = min(1.0, max(0.0, latestPlaybackState.currentTime / latestPlaybackState.duration))
        } else {
            progress = 0
        }

        return KollusPlayerControlState(
            status: status,
            statusText: Self.describe(status: status),
            timeText: Self.formatTime(
                current: latestPlaybackState.currentTime,
                duration: latestPlaybackState.duration
            ),
            progress: progress,
            selectedRate: selectedRate,
            allowedRates: allowedRates,
            playPauseTitle: playPauseTitle,
            isPlayPauseEnabled: isPlayable,
            isSeekEnabled: latestPlaybackState.duration > 0,
            isRateSelectionEnabled: isPlayable,
            isSubtitleVisible: subtitleVisible,
            captionFontSize: captionFontSize,
            isDisplayLocked: displayLocked,
            errorMessage: errorMessage
        )
    }

    private static func describe(status: PlaybackState.Status) -> String {
        switch status {
        case .idle: return "대기"
        case .preparing: return "준비 중"
        case .readyToPlay: return "재생 준비 완료"
        case .playing: return "재생 중"
        case .paused: return "일시정지"
        case .buffering: return "버퍼링"
        case .finished: return "재생 완료"
        case .failed: return "오류"
        }
    }

    private static func formatTime(current: TimeInterval, duration: TimeInterval) -> String {
        "\(format(seconds: current)) / \(format(seconds: duration))"
    }

    private static func format(seconds: TimeInterval) -> String {
        let safe = max(0, Int(seconds))
        return String(format: "%02d:%02d", safe / 60, safe % 60)
    }
}
