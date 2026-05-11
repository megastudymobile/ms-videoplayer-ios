//
//  PlayerModuleConfiguration.swift
//  SmartPlayer
//
//  Created by 모바일개발팀_정준영 on 2026/04/17.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import Foundation

public struct PlayerModuleConfiguration {
    public let initialPolicy: PlayerFeaturePolicy
    public let autoActivateCore: Bool

    public static let `default` = PlayerModuleConfiguration(
        initialPolicy: .default,
        autoActivateCore: true
    )

    public init(
        initialPolicy: PlayerFeaturePolicy = .default,
        autoActivateCore: Bool = true
    ) {
        self.initialPolicy = initialPolicy
        self.autoActivateCore = autoActivateCore
    }
}
