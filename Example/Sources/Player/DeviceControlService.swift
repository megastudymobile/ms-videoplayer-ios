//
//  DeviceControlService.swift
//  VideoPlayerExample
//
//  Created by JunyoungJung on 2026/06/05.
//
//  밝기/음량 — 엔진 무관 디바이스 제어 축 (SRP 분리).
//  화면 회전은 시스템 autorotation + viewWillTransition으로 처리한다.
//

import MediaPlayer
import UIKit

@MainActor
final class DeviceControlService {
    /// 시스템 볼륨 제어용 비표시 MPVolumeView (앱 레벨 표준 방식).
    private let volumeView = MPVolumeView(frame: .zero)

    init() {
        volumeView.isHidden = true
    }

    /// 제스처 HUD 등과 함께 쓰도록 뷰 계층에 부착해야 볼륨 슬라이더가 동작한다.
    func attach(to view: UIView) {
        guard volumeView.superview == nil else { return }
        view.addSubview(volumeView)
    }

    // MARK: - 밝기

    @discardableResult
    func adjustBrightness(by delta: CGFloat) -> CGFloat {
        let next = min(max(UIScreen.main.brightness + delta, 0), 1)
        UIScreen.main.brightness = next
        return next
    }

    var brightness: CGFloat {
        UIScreen.main.brightness
    }

    // MARK: - 음량

    @discardableResult
    func adjustVolume(by delta: Float) -> Float {
        guard let slider = volumeSlider else { return 0 }
        let next = min(max(slider.value + delta, 0), 1)
        slider.value = next
        return next
    }

    var volume: Float {
        volumeSlider?.value ?? AVAudioSession.sharedInstance().outputVolume
    }

    private var volumeSlider: UISlider? {
        volumeView.subviews.compactMap { $0 as? UISlider }.first
    }
}
