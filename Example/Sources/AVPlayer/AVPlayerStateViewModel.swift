//
//  AVPlayerStateViewModel.swift
//  VideoPlayerExample
//
//  Created by 모바일팀_정준영 on 2026/05/17.
//

import Foundation
import VideoPlayerCore

@MainActor
final class AVPlayerStateViewModel {
    private(set) var state: AVPlayerControlState = .idle

    private var latestPlaybackState: PlaybackState = .idle
    private var selectedRate: Double = 1.0
    private var displayScaled: Bool = false
    private var errorMessage: String?

    private let allowedRates: [Double] = [0.75, 1.0, 1.25, 1.5, 2.0]

    func apply(playbackState: PlaybackState) -> AVPlayerControlState {
        latestPlaybackState = playbackState
        if case .failed(let error) = playbackState.status {
            errorMessage = error.localizedDescription
        }
        state = buildState()
        return state
    }

    func apply(event: PlayerEvent) -> AVPlayerControlState {
        if case .didFail(let error) = event {
            errorMessage = error.localizedDescription
        }
        state = buildState()
        return state
    }

    func setPlaybackRate(_ rate: Double) -> AVPlayerControlState {
        selectedRate = rate
        state = buildState()
        return state
    }

    func setDisplayScaled(_ scaled: Bool) -> AVPlayerControlState {
        displayScaled = scaled
        state = buildState()
        return state
    }

    private func buildState() -> AVPlayerControlState {
        let status = latestPlaybackState.status
        let isPlayable: Bool
        let playPauseTitle: String
        let isStopEnabled: Bool

        switch status {
        case .idle, .preparing:
            isPlayable = false
            playPauseTitle = "Play"
            isStopEnabled = false
        case .readyToPlay, .paused, .finished:
            isPlayable = true
            playPauseTitle = "Play"
            isStopEnabled = true
        case .playing, .buffering:
            isPlayable = true
            playPauseTitle = "Pause"
            isStopEnabled = true
        case .failed:
            isPlayable = false
            playPauseTitle = "Play"
            isStopEnabled = false
        }

        let progress: Double
        if latestPlaybackState.duration > 0 {
            progress = min(1.0, max(0.0, latestPlaybackState.currentTime / latestPlaybackState.duration))
        } else {
            progress = 0
        }

        return AVPlayerControlState(
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
            isStopEnabled: isStopEnabled,
            isSeekEnabled: latestPlaybackState.duration > 0,
            isRateSelectionEnabled: isPlayable,
            isDisplayScaled: displayScaled,
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
