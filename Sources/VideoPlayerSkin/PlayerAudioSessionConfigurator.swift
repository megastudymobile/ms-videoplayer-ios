//
//  PlayerAudioSessionConfigurator.swift
//  SmartPlayer
//
//  Created by 모바일팀_정준영 on 2026/05/26.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import AVFoundation
import Foundation

/// 신규 Swift Player Shell 의 백그라운드 오디오 재생을 위한 AudioSession 카테고리 설정 utility.
///
/// dev `MegaStudyMoviePlayerController.m:3480` 의 `setCategory: AVAudioSessionCategoryPlayback` 1:1 대응.
/// `Info.plist` 의 `UIBackgroundModes = audio` 와 결합되어 home 진입 후에도 오디오 재생 유지.
public enum PlayerAudioSessionConfigurator {
    public static func configureForPlayback() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .moviePlayback, options: [])
            try session.setActive(true)
        } catch {
            // 카테고리 설정 실패는 백그라운드 재생만 영향. 전경 재생은 영향 없음.
            // production 에서는 무음 fallback. debug 에서는 assertion 으로 빠른 감지.
            assertionFailure("PlayerAudioSessionConfigurator failed: \(error.localizedDescription)")
        }
    }
}
