//
//  KollusDiagnosticsSink.swift
//  VideoPlayerModule
//
//  Created by 모바일개발팀_정준영 on 2026/05/15.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

import Foundation

public protocol KollusDiagnosticsSink: AnyObject, Sendable {
    func kollus(_ signal: KollusEngineSignal)
}
