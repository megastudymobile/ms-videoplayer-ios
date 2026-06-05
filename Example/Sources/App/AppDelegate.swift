//
//  AppDelegate.swift
//  VideoPlayerExample
//
//  Created by JunyoungJung on 2026/06/05.
//

import AVFoundation
import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        configureAudioSession()
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        UISceneConfiguration(
            name: "Default Configuration",
            sessionRole: connectingSceneSession.role
        )
    }

    /// 백그라운드 오디오 유지를 위한 카테고리 설정 (샘플 앱 부트스트랩 parity).
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
        } catch {
            print("[AppDelegate] AVAudioSession 설정 실패: \(error)")
        }
    }
}
