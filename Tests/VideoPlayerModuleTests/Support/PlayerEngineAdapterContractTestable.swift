#if canImport(UIKit)

//
//  PlayerEngineAdapterContractTestable.swift
//  SmartPlayer
//
//  Created by 모바일개발팀_정준영 on 2026/04/20.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import Foundation
@testable import VideoPlayerCore
@testable import VideoPlayerShellSupport

protocol PlayerEngineAdapterContractTestable {
    static func makeTestAdapter() -> PlayerEngineAdapter
    static func cleanupTestAdapter(_ adapter: PlayerEngineAdapter) async
    static var maxPreparationSeconds: TimeInterval { get }
    static var isSupportedInCurrentEnvironment: Bool { get }
    static var expectedCapabilities: EngineCapabilities { get }
}

#endif
