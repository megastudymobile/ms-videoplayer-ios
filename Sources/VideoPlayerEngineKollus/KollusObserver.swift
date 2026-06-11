//
//  KollusObserver.swift
//  VideoPlayerModule
//
//  Created by 모바일팀_정준영 on 2026/05/15.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import Foundation

public protocol KollusObserver: AnyObject, Sendable {
    func kollus(didResolveDRM request: [String: Any], response: [String: Any], error: Error?)
    func kollus(didPostLMS data: String, result: [String: Any])
    func kollusStorage(didCompleteStoredLMS success: Int, failure: Int)
}
