//
//  KollusBackgroundAudioKeeper.swift
//  VideoPlayerEngineKollus
//
//  Created by 모바일팀_정준영 on 2026/06/11.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import AVFoundation
import KollusSDKBinary
import UIKit

/// `PlayerTypeNative`(AVPlayer 백엔드) 모드에서 백그라운드 오디오 재생을 유지하는 keeper.
///
/// AVPlayer 는 자신이 부착된 `AVPlayerLayer` 가 백그라운드된 뷰 계층에 있으면 iOS 가 강제로 일시정지한다
/// (오디오 세션 권한과 무관한 iOS 기본 동작). 그래서 `willResignActive` 에서 KollusPlayerView 내부
/// `AVPlayerLayer` 를 찾아 `player` 를 분리(`layer.player = nil`)하고 AVPlayer 를 강하게 보관해 오디오를
/// 끊김 없이 유지한 뒤, `didBecomeActive` 에서 다시 부착한다.
///
/// `UIBackgroundModes=audio` + `AVAudioSession.playback` active(별도 configurator 담당)와 결합되어야
/// 백그라운드 오디오가 유지된다 — 본 keeper 는 그 중 "AVPlayer 를 layer 에서 분리" 부분만 담당한다.
///
/// `audioBackgroundPlay` SDK 플래그는 `PlayerTypeKollus`(Kollus 자체 디코더) 경로에만 적용되며,
/// `PlayerTypeNative` 경로에는 효과가 없어 본 keeper 가 필요하다.
@MainActor
final class KollusBackgroundAudioKeeper {
    private weak var playerView: KollusPlayerView?
    private let notificationCenter: NotificationCenter
    private var observers: [NSObjectProtocol] = []
    /// 백그라운드 진입 시 layer 에서 분리해 보관하는 AVPlayer. foreground 복귀 시 재부착에 사용.
    private var detachedPlayer: AVPlayer?

    /// - Parameters:
    ///   - playerView: 대상 KollusPlayerView (weak — 소유는 adapter).
    ///   - isEnabled: 사용자 백그라운드 재생 설정. false 면 observer 를 등록하지 않아 no-op.
    init(
        playerView: KollusPlayerView,
        isEnabled: Bool,
        notificationCenter: NotificationCenter = .default
    ) {
        self.playerView = playerView
        self.notificationCenter = notificationCenter

        guard isEnabled else { return }

        observers.append(
            notificationCenter.addObserver(
                forName: UIApplication.willResignActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.enterBackground()
                }
            }
        )
        observers.append(
            notificationCenter.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.enterForeground()
                }
            }
        )
    }

    deinit {
        let center = notificationCenter
        let tokens = observers
        // removeObserver 는 thread-safe — deinit 이 어느 스레드에서 호출되어도 안전.
        tokens.forEach(center.removeObserver(_:))
    }

    /// KollusPlayerView 의 첫 subview 의 첫 sublayer 가 AVPlayerLayer 라는 SDK 뷰 구조에 의존한다.
    private func currentAVPlayerLayer() -> AVPlayerLayer? {
        guard
            let firstSubview = playerView?.subviews.first,
            let firstSublayer = firstSubview.layer.sublayers?.first as? AVPlayerLayer
        else {
            return nil
        }
        return firstSublayer
    }

    private func enterBackground() {
        guard
            detachedPlayer == nil,
            playerView?.isPreparedToPlay == true,
            let layer = currentAVPlayerLayer(),
            let player = layer.player
        else {
            return
        }

        // 백그라운드에서 오디오가 유지되려면 분리 시점에 세션이 .playback active 여야 한다.
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, options: [])
        try? session.setActive(true)

        detachedPlayer = player
        layer.player = nil
    }

    private func enterForeground() {
        guard let player = detachedPlayer else { return }
        defer { detachedPlayer = nil }
        guard let layer = currentAVPlayerLayer(), layer.player == nil else { return }
        layer.player = player
    }
}
