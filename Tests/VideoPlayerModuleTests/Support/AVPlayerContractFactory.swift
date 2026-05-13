#if canImport(UIKit)

//
//  AVPlayerContractFactory.swift
//  SmartPlayer
//
//  Created by 모바일개발팀_정준영 on 2026/04/20.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import AVFoundation
import Foundation
import XCTest
@testable import VideoPlayerModule

enum AVPlayerContractFactory: PlayerEngineAdapterContractTestable {
    static func makeTestAdapter() -> PlayerEngineAdapter {
        AVPlayerAdapter(player: AVPlayer())
    }

    static func cleanupTestAdapter(_ adapter: PlayerEngineAdapter) async {
        await adapter.stop()
    }

    static var maxPreparationSeconds: TimeInterval { 3 }
    static var isSupportedInCurrentEnvironment: Bool { true }
    static var expectedCapabilities: EngineCapabilities {
        [.continuesWithoutSurface, .seamlessSurfaceSwap]
    }
}

/// XCTest는 상속된 test 메서드를 concrete subclass에서 자동으로 수집한다.
/// 이 class 파일 하나만 추가하면 PlayerEngineContractTestShared의 모든 assertion이 AVPlayerAdapter에 대해 실행된다.
final class AVPlayerEngineContractTests: PlayerEngineContractTestShared<AVPlayerContractFactory> {
    // 추가 AVPlayer 전용 assertion이 필요하면 이 subclass에서만 선언한다.
}

#endif
