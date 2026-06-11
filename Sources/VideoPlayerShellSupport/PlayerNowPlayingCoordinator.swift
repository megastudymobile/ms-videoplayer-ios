//
//  PlayerNowPlayingCoordinator.swift
//  VideoPlayerModule
//
//  Created by 모바일팀_정준영 on 2026/06/10.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import MediaPlayer
import UIKit
import VideoPlayerCore

/// 잠금화면/제어센터 NowPlaying 통합 — 메타데이터 등록, remote command → `PlaybackCommand`
/// 라우팅, 재생 상태 동기화를 모듈이 자체 수행한다.
///
/// `PlayerStateBinder.bind(core:nowPlaying:...)`로 연결하면 상태 동기화에 host 배선이
/// 필요 없다. 제목/썸네일은 엔진(`EngineContentMetadataAbility`)에서 직접 조회하고,
/// 엔진이 메타데이터를 제공하지 못하면 `fallbackTitle`만 표시한다.
///
/// - Important: 화면을 닫을 때 `stop()`을 호출해야 잠금화면 플레이어가 제거된다.
@MainActor
public final class PlayerNowPlayingCoordinator {
    private let core: PlayerCore
    private let metadataProvider: EngineContentMetadataAbility?
    private let skipInterval: TimeInterval
    private let fallbackTitle: String?

    private var lastState: PlaybackState = .idle
    private var playbackRate: Double = 1.0
    private var hasLoadedMetadata = false
    private var metadataTask: Task<Void, Never>?
    private var isStarted = false

    public init(
        core: PlayerCore,
        metadataProvider: EngineContentMetadataAbility?,
        skipInterval: TimeInterval,
        fallbackTitle: String? = nil
    ) {
        self.core = core
        self.metadataProvider = metadataProvider
        self.skipInterval = max(1, skipInterval)
        self.fallbackTitle = fallbackTitle
    }

    public func start() {
        guard isStarted == false else { return }
        isStarted = true
        registerCommands()

        var info: [String: Any] = [:]
        if let fallbackTitle {
            info[MPMediaItemPropertyTitle] = fallbackTitle
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    public func stop() {
        guard isStarted else { return }
        isStarted = false
        metadataTask?.cancel()
        metadataTask = nil
        hasLoadedMetadata = false
        unregisterCommands()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    /// `PlayerStateBinder`가 state 스트림 fan-out으로 호출한다.
    public func apply(state: PlaybackState) {
        guard isStarted else { return }
        lastState = state
        if state.status == .readyToPlay || state.status == .playing {
            loadMetadataIfNeeded()
        }

        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPMediaItemPropertyPlaybackDuration] = state.duration
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = state.currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = state.status == .playing ? playbackRate : 0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    /// 배속 변경 통지 — `PlayerEvent`에 배속 이벤트가 없어 명령 경로에서 알려줘야
    /// 시스템 진행 표시가 실제 속도와 맞는다.
    public func setPlaybackRate(_ rate: Double) {
        playbackRate = rate
        guard isStarted else { return }
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPNowPlayingInfoPropertyPlaybackRate] = lastState.status == .playing ? rate : 0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    // MARK: - Remote commands

    private func registerCommands() {
        let center = MPRemoteCommandCenter.shared()
        removeTargets(center)

        center.playCommand.isEnabled = true
        center.pauseCommand.isEnabled = true
        center.togglePlayPauseCommand.isEnabled = true
        center.skipForwardCommand.isEnabled = true
        center.skipBackwardCommand.isEnabled = true
        let preferredInterval = NSNumber(value: skipInterval)
        center.skipForwardCommand.preferredIntervals = [preferredInterval]
        center.skipBackwardCommand.preferredIntervals = [preferredInterval]

        center.playCommand.addTarget { [weak self] _ in
            self?.execute(.play)
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            self?.execute(.pause)
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            self.execute(self.lastState.status == .playing ? .pause : .play)
            return .success
        }
        center.skipForwardCommand.addTarget { [weak self] _ in
            self?.skip(by: self?.skipInterval ?? 0)
            return .success
        }
        center.skipBackwardCommand.addTarget { [weak self] _ in
            self?.skip(by: -(self?.skipInterval ?? 0))
            return .success
        }
    }

    private func unregisterCommands() {
        let center = MPRemoteCommandCenter.shared()
        removeTargets(center)
        center.playCommand.isEnabled = false
        center.pauseCommand.isEnabled = false
        center.togglePlayPauseCommand.isEnabled = false
        center.skipForwardCommand.isEnabled = false
        center.skipBackwardCommand.isEnabled = false
    }

    private func removeTargets(_ center: MPRemoteCommandCenter) {
        center.playCommand.removeTarget(nil)
        center.pauseCommand.removeTarget(nil)
        center.togglePlayPauseCommand.removeTarget(nil)
        center.skipForwardCommand.removeTarget(nil)
        center.skipBackwardCommand.removeTarget(nil)
    }

    private func skip(by delta: TimeInterval) {
        let target = min(max(0, lastState.currentTime + delta), max(0, lastState.duration))
        execute(.seek(to: target))
    }

    /// 잠금화면 탭 실패는 surfacing할 화면이 없다 — 실제 재생 실패는 Core가
    /// didFail 이벤트로 별도 전파하므로 여기서는 결과를 버린다.
    private func execute(_ command: PlaybackCommand) {
        Task { @MainActor [core] in
            try? await core.execute(command: command)
        }
    }

    // MARK: - Metadata

    private func loadMetadataIfNeeded() {
        guard hasLoadedMetadata == false, metadataTask == nil, let metadataProvider else { return }
        metadataTask = Task { @MainActor [weak self] in
            defer { self?.metadataTask = nil }
            guard let content = await metadataProvider.currentContent() else { return }
            guard let self, self.isStarted else { return }
            self.hasLoadedMetadata = true

            if content.title.isEmpty == false {
                var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                info[MPMediaItemPropertyTitle] = content.title
                MPNowPlayingInfoCenter.default().nowPlayingInfo = info
            }
            // thumbnailPath는 시크 프리뷰용 스프라이트 시트일 수 있어 artwork로 쓰지 않는다.
            if let path = content.snapshotPath, path.isEmpty == false {
                await self.loadArtwork(from: path)
            }
        }
    }

    private func loadArtwork(from path: String) async {
        let image: UIImage?
        if let url = URL(string: path), url.scheme?.hasPrefix("http") == true {
            image = await Self.fetchImage(from: url)
        } else {
            image = UIImage(contentsOfFile: path)
        }
        guard isStarted, let image else { return }

        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private static func fetchImage(from url: URL) async -> UIImage? {
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        return UIImage(data: data)
    }
}
