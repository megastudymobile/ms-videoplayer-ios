//
//  PlayerModuleConfiguration.swift
//  VideoPlayerModule
//
//  Created by 모바일팀_정준영 on 2026/04/17.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import Foundation
import VideoPlayerCore

public struct PlayerModuleConfiguration {
    public let initialPolicy: PlayerFeaturePolicy
    public let autoActivateCore: Bool
    /// host가 주입하는 로깅 시스템 어댑터. 기본은 무음(NoopPlayerLogger).
    public let logger: any PlayerLogger

    public static let `default` = PlayerModuleConfiguration(
        initialPolicy: .default,
        autoActivateCore: true
    )

    public init(
        initialPolicy: PlayerFeaturePolicy = .default,
        autoActivateCore: Bool = true,
        logger: any PlayerLogger = NoopPlayerLogger()
    ) {
        self.initialPolicy = initialPolicy
        self.autoActivateCore = autoActivateCore
        self.logger = logger
    }
}
