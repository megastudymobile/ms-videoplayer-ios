//
//  PlayerScreenCaptureMonitor.swift
//  VideoPlayerModule
//
//  Created by JunyoungJung on 2026/06/10.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

import UIKit

/// 화면 캡처(녹화/미러링) 상태 감시자.
/// `UIScreen.capturedDidChangeNotification`을 구독하고, 상태가 실제로 바뀐 경우에만 알린다.
/// 캡처 여부 판정은 주입 클로저로 분리 — UIScreen 의존 없이 단독 테스트한다.
@MainActor
final class PlayerScreenCaptureMonitor: NSObject {
    var onChange: ((Bool) -> Void)?
    private(set) var isCaptured = false

    private let isCapturedNow: @MainActor () -> Bool

    init(
        notificationCenter: NotificationCenter = .default,
        isCapturedNow: @escaping @MainActor () -> Bool
    ) {
        self.isCapturedNow = isCapturedNow
        super.init()
        // selector 방식은 deinit에서 명시 해제가 필요 없다(iOS 9+ 자동 정리) —
        // block 토큰 보관/해제의 actor 격리 문제를 피한다.
        notificationCenter.addObserver(
            self,
            selector: #selector(captureStateDidChange),
            name: UIScreen.capturedDidChangeNotification,
            object: nil
        )
    }

    /// 현재 캡처 상태를 다시 읽어 변경 시에만 onChange를 발행한다.
    /// 윈도우 attach 직후 등 notification 밖 시점에서도 호출된다.
    func refresh() {
        let captured = isCapturedNow()
        guard captured != isCaptured else { return }
        isCaptured = captured
        onChange?(captured)
    }

    @objc private func captureStateDidChange() {
        refresh()
    }
}
