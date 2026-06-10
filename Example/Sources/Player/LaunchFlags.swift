//
//  LaunchFlags.swift
//  VideoPlayerExample
//
//  Created by JunyoungJung on 2026/06/10.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import Foundation

/// Xcode 스킴 "Arguments Passed On Launch"로 켜는 QA/디버그 플래그.
/// 기본(플래그 미지정)은 모든 보호가 활성이다 — 스킴에 비활성 상태로 등록돼 있어
/// 체크박스만 켜면 동작한다.
enum LaunchFlags {
    /// 스크린샷 보호(secure 캔버스) 끄기 — 캡처 결과물에 영상이 그대로 보인다.
    static var disablesScreenshotProtection: Bool {
        ProcessInfo.processInfo.arguments.contains("-disableScreenshotProtection")
    }
}
