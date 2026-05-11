//
//  KollusContractFactory.swift
//  SmartPlayer
//
//  Created by 모바일개발팀_정준영 on 2026/05/11.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import Foundation
import XCTest
@testable import VideoPlayerModule

enum KollusContractFactory: PlayerEngineAdapterContractTestable {
    static func makeTestAdapter() -> PlayerEngineAdapter {
        KollusPlayerAdapter()
    }

    static func cleanupTestAdapter(_ adapter: PlayerEngineAdapter) async {
        await adapter.stop()
    }

    static var maxPreparationSeconds: TimeInterval { 5 }

    static var isSupportedInCurrentEnvironment: Bool {
        #if targetEnvironment(simulator)
        false
        #else
        true
        #endif
    }

    static var expectedCapabilities: EngineCapabilities {
        []
    }
}

final class KollusPlayerEngineContractTests: PlayerEngineContractTestShared<KollusContractFactory> {
}
