//
//  KollusDiagnosticsSink.swift
//  VideoPlayerModule
//
//  Created by 모바일팀_정준영 on 2026/05/15.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import Foundation

public protocol KollusDiagnosticsSink: AnyObject, Sendable {
    func kollus(_ signal: KollusEngineSignal)
}
