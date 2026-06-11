//
//  PlayerStateViewModelTests.swift
//  VideoPlayerExampleTests
//
//  Created by JunyoungJung on 2026/06/05.
//

import Testing
import VideoPlayerCore
import VideoPlayerSkin
@testable import VideoPlayerExample

@MainActor
@Suite("PlayerStateViewModel 순수 변환")
struct PlayerStateViewModelTests {
    @Test("playing 상태 → isPlaying/progress 매핑")
    func appliesPlayingState() {
        let viewModel = PlayerStateViewModel()
        let state = viewModel.apply(playbackState: PlaybackState(
            status: .playing, currentTime: 30, duration: 120, isBuffering: false
        ))

        #expect(state.isPlaying)
        #expect(state.isLoading == false)
        #expect(state.currentTime == 30)
        #expect(state.duration == 120)
        #expect(abs(state.progress - 0.25) < 0.001)
        #expect(state.isSeekEnabled)
    }

    @Test("buffering → isLoading")
    func buffersAsLoading() {
        let viewModel = PlayerStateViewModel()
        let state = viewModel.apply(playbackState: PlaybackState(
            status: .buffering, currentTime: 0, duration: 60, isBuffering: true
        ))

        #expect(state.isLoading)
        #expect(state.isPlaying == false)
    }

    @Test("timeDidChange 이벤트 → currentTime 갱신")
    func appliesTimeEvent() {
        let viewModel = PlayerStateViewModel()
        _ = viewModel.apply(playbackState: PlaybackState(
            status: .playing, currentTime: 10, duration: 100, isBuffering: false
        ))

        let next = viewModel.apply(event: .timeDidChange(currentTime: 55, duration: 100))

        #expect(next?.currentTime == 55)
    }

    @Test("captionDidUpdate는 skin 상태 무관 — nil 반환")
    func ignoresCaptionEvent() {
        let viewModel = PlayerStateViewModel()
        let next = viewModel.apply(event: .captionDidUpdate(text: "자막", isSecondary: false))

        #expect(next == nil)
    }

    @Test("layoutMode resolve — fullScreen ↔ verticalSplit")
    func resolvesLayoutMode() {
        let viewModel = PlayerStateViewModel()

        let landscape = viewModel.resolveLayoutMode(.fullScreen)
        #expect(landscape.layoutMode == .fullScreen)
        #expect(landscape.isFullScreenMode)

        let portrait = viewModel.resolveLayoutMode(.verticalSplit)
        #expect(portrait.layoutMode == .verticalSplit)
        #expect(portrait.isFullScreenMode == false)
    }

    @Test("잠금 토글 후 상태 스트림에도 유지")
    func preservesLockAcrossStateUpdates() {
        let viewModel = PlayerStateViewModel()
        let locked = viewModel.toggleLock()
        #expect(locked.isLocked)

        let afterStream = viewModel.apply(playbackState: PlaybackState(
            status: .playing, currentTime: 5, duration: 60, isBuffering: false
        ))
        #expect(afterStream.isLocked)
    }

    @Test("구간 반복 설정이 상태 스트림에도 유지")
    func preservesSectionRepeatAcrossStateUpdates() {
        let viewModel = PlayerStateViewModel()
        _ = viewModel.setSectionRepeat(.looping(start: 10, end: 20))

        let next = viewModel.apply(playbackState: PlaybackState(
            status: .playing, currentTime: 15, duration: 60, isBuffering: false
        ))

        #expect(next.sectionRepeat == .looping(start: 10, end: 20))
    }

    @Test("배속 변경 유지")
    func keepsPlaybackRate() {
        let viewModel = PlayerStateViewModel()
        _ = viewModel.setPlaybackRate(1.5)

        let next = viewModel.apply(playbackState: PlaybackState(
            status: .playing, currentTime: 0, duration: 60, isBuffering: false
        ))

        #expect(next.playbackRate == 1.5)
    }

    @Test("재생 토글 intent는 권위 상태 도착 전까지 버튼 상태를 유지")
    func keepsPlaybackIntentUntilAuthoritativeStateArrives() {
        let viewModel = PlayerStateViewModel()
        _ = viewModel.apply(playbackState: PlaybackState(
            status: .playing, currentTime: 10, duration: 100, isBuffering: false
        ))

        let pendingPause = viewModel.setPlaybackIntent(isPlaying: false)
        #expect(pendingPause.isPlaying == false)

        let timeTick = viewModel.apply(event: .timeDidChange(currentTime: 11, duration: 100))
        #expect(timeTick?.isPlaying == false)

        let paused = viewModel.apply(playbackState: PlaybackState(
            status: .paused, currentTime: 11, duration: 100, isBuffering: false
        ))
        #expect(paused.isPlaying == false)

        let resumed = viewModel.apply(playbackState: PlaybackState(
            status: .playing, currentTime: 12, duration: 100, isBuffering: false
        ))
        #expect(resumed.isPlaying)
    }

    @Test("재생 중이고 컨트롤이 표시된 상태만 자동 숨김 대상")
    func autoHideEligibility() {
        let viewModel = PlayerStateViewModel()
        let playing = viewModel.apply(playbackState: PlaybackState(
            status: .playing, currentTime: 0, duration: 60, isBuffering: false
        ))

        #expect(PlayerStateViewModel.shouldAutoHideControls(in: playing))
        #expect(PlayerStateViewModel.shouldAutoHideControls(in: playing.updating(controlsVisible: false)) == false)
        #expect(PlayerStateViewModel.shouldAutoHideControls(in: playing.updating(isLoading: true)) == false)
        #expect(PlayerStateViewModel.shouldAutoHideControls(in: playing.updating(isLocked: true)) == false)
        #expect(PlayerStateViewModel.shouldAutoHideControls(in: playing.updating(isRatePanelPresented: true)) == false)
        #expect(PlayerStateViewModel.shouldAutoHideControls(in: playing.updating(isPlaying: false)) == false)
    }
}
