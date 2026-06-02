//
//  PlayerSkinState.swift
//  SmartPlayer
//
//  Created by 모바일팀_정준영 on 2026/05/19.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import Foundation

import VideoPlayerCore

/// spec-063 P1 — `PlayerSkinControlView` chrome 분기용 layout mode.
/// dev `MGPlayerSkinView` 의 가로/세로/split 분기와 1:1 매핑.
/// - verticalSplit: iPhone portrait — title/leftMenu/rightMenu hidden, center 컨트롤 좌측 정렬.
/// - horizontalSplit: iPad landscape split — title visible, leftMenu visible, rightMenu hidden.
/// - fullScreen: phone landscape / iPad fullscreen toggle — 모든 chrome 노출, center 컨트롤 중앙 정렬.
public enum PlayerSkinLayoutMode: Equatable {
    case verticalSplit
    case horizontalSplit
    case fullScreen
}

public struct PlayerSkinState: Equatable {
    public enum SectionRepeatState: Equatable {
        case idle
        case started(TimeInterval)
        case looping(start: TimeInterval, end: TimeInterval)
    }

    public var isPlaying: Bool
    public var isLoading: Bool
    public var isSeekEnabled: Bool
    public var controlsVisible: Bool
    public var currentTime: TimeInterval
    public var duration: TimeInterval
    public var progress: Float
    public var playbackRate: Double
    public var previousPlaybackRate: Double
    public var isRatePanelPresented: Bool
    public var isFullScreenMode: Bool
    public var isDisplayScaled: Bool
    /// spec-064 Phase 1 — host 주입 추가 버튼(ExtraControl) 중 현재 숨길 id 집합.
    /// 다음 강의 버튼 등 동적 가시성을 generic 하게 표현 (구 `nextEpisodeButtonVisible` 대체).
    public var hiddenExtraControlIDs: Set<String>
    public var isLocked: Bool
    public var sectionRepeat: SectionRepeatState
    /// spec-063 P1 — Shell `viewWillTransition` 에서 size+traits 기반 resolve 후 emit.
    public var layoutMode: PlayerSkinLayoutMode

    public static let initial = PlayerSkinState(
        isPlaying: false,
        isLoading: true,
        isSeekEnabled: false,
        controlsVisible: true,
        currentTime: 0,
        duration: 0,
        progress: 0,
        playbackRate: 1.0,
        isRatePanelPresented: false,
        isFullScreenMode: false,
        isDisplayScaled: false,
        hiddenExtraControlIDs: [],
        layoutMode: .verticalSplit
    )

    public init(
        isPlaying: Bool,
        isLoading: Bool,
        isSeekEnabled: Bool,
        controlsVisible: Bool,
        currentTime: TimeInterval,
        duration: TimeInterval,
        progress: Float,
        playbackRate: Double,
        previousPlaybackRate: Double? = nil,
        isRatePanelPresented: Bool = false,
        isFullScreenMode: Bool,
        isDisplayScaled: Bool,
        hiddenExtraControlIDs: Set<String> = [],
        isLocked: Bool = false,
        sectionRepeat: SectionRepeatState = .idle,
        layoutMode: PlayerSkinLayoutMode = .verticalSplit
    ) {
        self.isPlaying = isPlaying
        self.isLoading = isLoading
        self.isSeekEnabled = isSeekEnabled
        self.controlsVisible = controlsVisible
        self.currentTime = currentTime
        self.duration = duration
        self.progress = progress
        self.playbackRate = playbackRate
        self.previousPlaybackRate = previousPlaybackRate ?? 1.0
        self.isRatePanelPresented = isRatePanelPresented
        self.isFullScreenMode = isFullScreenMode
        self.isDisplayScaled = isDisplayScaled
        self.hiddenExtraControlIDs = hiddenExtraControlIDs
        self.isLocked = isLocked
        self.sectionRepeat = sectionRepeat
        self.layoutMode = layoutMode
    }

    public init(
        playbackState: PlaybackState,
        playbackRate: Double,
        isRatePanelPresented: Bool = false,
        controlsVisible: Bool,
        isFullScreenMode: Bool,
        isDisplayScaled: Bool,
        hiddenExtraControlIDs: Set<String> = [],
        layoutMode: PlayerSkinLayoutMode = .verticalSplit
    ) {
        let sanitizedDuration = max(0, playbackState.duration)
        let sanitizedCurrentTime = min(max(0, playbackState.currentTime), sanitizedDuration > 0 ? sanitizedDuration : playbackState.currentTime)
        let progress = sanitizedDuration > 0 ? Float(sanitizedCurrentTime / sanitizedDuration) : 0

        self.init(
            isPlaying: playbackState.status == .playing,
            isLoading: playbackState.status.isLoading || playbackState.isBuffering,
            isSeekEnabled: sanitizedDuration > 0 && playbackState.isLive == false,
            controlsVisible: controlsVisible,
            currentTime: sanitizedCurrentTime,
            duration: sanitizedDuration,
            progress: min(max(progress, 0), 1),
            playbackRate: playbackRate,
            isRatePanelPresented: isRatePanelPresented,
            isFullScreenMode: isFullScreenMode,
            isDisplayScaled: isDisplayScaled,
            hiddenExtraControlIDs: hiddenExtraControlIDs,
            layoutMode: layoutMode
        )
    }

    public func updating(
        isPlaying: Bool? = nil,
        isLoading: Bool? = nil,
        isSeekEnabled: Bool? = nil,
        controlsVisible: Bool? = nil,
        currentTime: TimeInterval? = nil,
        duration: TimeInterval? = nil,
        progress: Float? = nil,
        playbackRate: Double? = nil,
        previousPlaybackRate: Double? = nil,
        isRatePanelPresented: Bool? = nil,
        isFullScreenMode: Bool? = nil,
        isDisplayScaled: Bool? = nil,
        hiddenExtraControlIDs: Set<String>? = nil,
        isLocked: Bool? = nil,
        sectionRepeat: SectionRepeatState? = nil,
        layoutMode: PlayerSkinLayoutMode? = nil
    ) -> PlayerSkinState {
        PlayerSkinState(
            isPlaying: isPlaying ?? self.isPlaying,
            isLoading: isLoading ?? self.isLoading,
            isSeekEnabled: isSeekEnabled ?? self.isSeekEnabled,
            controlsVisible: controlsVisible ?? self.controlsVisible,
            currentTime: currentTime ?? self.currentTime,
            duration: duration ?? self.duration,
            progress: progress ?? self.progress,
            playbackRate: playbackRate ?? self.playbackRate,
            previousPlaybackRate: previousPlaybackRate ?? self.previousPlaybackRate,
            isRatePanelPresented: isRatePanelPresented ?? self.isRatePanelPresented,
            isFullScreenMode: isFullScreenMode ?? self.isFullScreenMode,
            isDisplayScaled: isDisplayScaled ?? self.isDisplayScaled,
            hiddenExtraControlIDs: hiddenExtraControlIDs ?? self.hiddenExtraControlIDs,
            isLocked: isLocked ?? self.isLocked,
            sectionRepeat: sectionRepeat ?? self.sectionRepeat,
            layoutMode: layoutMode ?? self.layoutMode
        )
    }

    public var currentTimeText: String {
        PlayerSkinState.formatTime(currentTime)
    }

    public var durationText: String {
        PlayerSkinState.formatTime(duration)
    }

    public static func previewTime(for progress: Float, duration: TimeInterval) -> TimeInterval {
        guard duration > 0 else { return 0 }
        return duration * TimeInterval(min(max(progress, 0), 1))
    }

    public static func formatTime(_ time: TimeInterval) -> String {
        guard time.isFinite, time > 0 else { return "00:00" }

        let totalSeconds = Int(time.rounded())
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }

        return String(format: "%02d:%02d", minutes, seconds)
    }
}

private extension PlaybackState.Status {
    var isLoading: Bool {
        switch self {
        case .preparing, .buffering:
            return true
        case .idle, .readyToPlay, .playing, .paused, .finished, .failed:
            return false
        }
    }
}
