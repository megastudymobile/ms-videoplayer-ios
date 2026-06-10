#if canImport(UIKit)
//
//  PlayerScreenCaptureMonitorTests.swift
//  VideoPlayerModuleTests
//
//  Created by JunyoungJung on 2026/06/10.
//

import Testing
import UIKit
@testable import VideoPlayerSkin

@MainActor
struct PlayerScreenCaptureMonitorTests {

    @Test("캡처 상태가 실제로 바뀐 경우에만 onChange를 발행한다")
    func notifiesOnlyOnTransition() {
        let center = NotificationCenter()
        var captured = false
        var events: [Bool] = []
        let monitor = PlayerScreenCaptureMonitor(notificationCenter: center) { captured }
        monitor.onChange = { events.append($0) }

        // false → false: 변화 없음 — 발행 안 함.
        center.post(name: UIScreen.capturedDidChangeNotification, object: nil)
        #expect(events.isEmpty)

        captured = true
        center.post(name: UIScreen.capturedDidChangeNotification, object: nil)
        // 같은 상태로 중복 notification — 발행 안 함.
        center.post(name: UIScreen.capturedDidChangeNotification, object: nil)
        #expect(events == [true])
        #expect(monitor.isCaptured)

        captured = false
        monitor.refresh()
        #expect(events == [true, false])
        #expect(monitor.isCaptured == false)
    }

    @Test("notification 없이 refresh만으로도 상태를 갱신한다")
    func refreshUpdatesWithoutNotification() {
        var captured = true
        let monitor = PlayerScreenCaptureMonitor(notificationCenter: NotificationCenter()) { captured }

        monitor.refresh()
        #expect(monitor.isCaptured)

        captured = false
        monitor.refresh()
        #expect(monitor.isCaptured == false)
    }
}
#endif
