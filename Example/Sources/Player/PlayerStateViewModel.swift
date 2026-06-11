//
//  PlayerStateViewModel.swift
//  VideoPlayerExample
//
//  Created by JunyoungJung on 2026/06/05.
//
//  PlaybackState/PlayerEvent → PlayerSkinState 순수 변환.
//  controlsVisible/배속/layoutMode 등 UI 로컬 상태를 보관하고
//  매 변환마다 일관된 PlayerSkinState를 만든다. UIKit 의존 없음 — 단독 테스트 가능.
//

import Foundation
import VideoPlayerCore
import VideoPlayerSkin

@MainActor
final class PlayerStateViewModel {
    private(set) var state: PlayerSkinState = .initial
    private var lastPlaybackState: PlaybackState = .idle
    private var pendingPlaybackIntent: Bool?

    // MARK: - PlaybackState 스트림

    func apply(playbackState: PlaybackState) -> PlayerSkinState {
        lastPlaybackState = playbackState
        let streamState = PlayerSkinState(
            playbackState: playbackState,
            playbackRate: state.playbackRate,
            isRatePanelPresented: state.isRatePanelPresented,
            controlsVisible: state.controlsVisible,
            isFullScreenMode: state.isFullScreenMode,
            isDisplayScaled: state.isDisplayScaled,
            displayScaleMode: state.displayScaleMode,
            hiddenExtraControlIDs: state.hiddenExtraControlIDs,
            layoutMode: state.layoutMode
        )
        state = stateByReconcilingPlaybackIntent(streamState, playbackStatus: playbackState.status).updating(
            isLocked: state.isLocked,
            sectionRepeat: state.sectionRepeat
        )
        return state
    }

    // MARK: - PlayerEvent 스트림 (skin 상태에 영향 주는 것만 반환)

    func apply(event: PlayerEvent) -> PlayerSkinState? {
        switch event {
        case .stateDidChange(let playbackState):
            return apply(playbackState: playbackState)
        case .timeDidChange(let currentTime, let duration):
            return apply(playbackState: lastPlaybackState.updating(currentTime: currentTime, duration: duration))
        case .bufferingDidChange(let isBuffering):
            return apply(playbackState: lastPlaybackState.updating(isBuffering: isBuffering))
        case .didFinish, .didFail:
            return apply(playbackState: lastPlaybackState)
        case .deviceLockPolicyChanged(let locked):
            state = state.updating(isLocked: locked)
            return state
        default:
            // captionDidUpdate/bookmarksDidLoad 등은 skin 상태 무관 — VC가 별도 처리.
            return nil
        }
    }

    // MARK: - UI 로컬 상태 변경

    func setPlaybackRate(_ rate: Double) -> PlayerSkinState {
        state = state.updating(playbackRate: rate)
        return state
    }

    func setPlaybackIntent(isPlaying: Bool) -> PlayerSkinState {
        pendingPlaybackIntent = isPlaying
        state = state.updating(isPlaying: isPlaying)
        return state
    }

    func setControlsVisible(_ visible: Bool) -> PlayerSkinState {
        state = state.updating(controlsVisible: visible)
        return state
    }

    func toggleControlsVisible() -> PlayerSkinState {
        setControlsVisible(state.controlsVisible == false)
    }

    func toggleLock() -> PlayerSkinState {
        state = state.updating(isLocked: state.isLocked == false)
        return state
    }

    func setRatePanelPresented(_ presented: Bool) -> PlayerSkinState {
        state = state.updating(isRatePanelPresented: presented)
        return state
    }

    func setDisplayScaleMode(_ mode: PlayerDisplayScaleMode) -> PlayerSkinState {
        state = state.updating(displayScaleMode: mode)
        return state
    }

    func setSectionRepeat(_ sectionRepeat: PlayerSkinState.SectionRepeatState) -> PlayerSkinState {
        state = state.updating(sectionRepeat: sectionRepeat)
        return state
    }

    /// 회전/사이즈 변화 → 레이아웃 모드 갱신 (문서 §2.2.1).
    func resolveLayoutMode(_ mode: PlayerSkinLayoutMode) -> PlayerSkinState {
        state = state.updating(
            isFullScreenMode: mode == .fullScreen,
            layoutMode: mode
        )
        return state
    }

    /// 가로/세로 판정 단일 진실원 — PlayerViewController(skin 모드)와
    /// PlayerTestConsoleContainerViewController(split 레이아웃)가 같은 규칙을 공유한다.
    static func isLandscape(_ size: CGSize) -> Bool {
        size.width > size.height
    }

    static func shouldAutoHideControls(in state: PlayerSkinState) -> Bool {
        state.isPlaying
            && state.isLoading == false
            && state.controlsVisible
            && state.isLocked == false
            && state.isRatePanelPresented == false
    }

    private func stateByReconcilingPlaybackIntent(
        _ streamState: PlayerSkinState,
        playbackStatus: PlaybackState.Status
    ) -> PlayerSkinState {
        guard let pendingPlaybackIntent else {
            return streamState
        }

        switch playbackStatus {
        case .playing where pendingPlaybackIntent,
             .paused where pendingPlaybackIntent == false,
             .idle,
             .finished,
             .failed:
            self.pendingPlaybackIntent = nil
            return streamState
        default:
            return streamState.updating(isPlaying: pendingPlaybackIntent)
        }
    }
}
