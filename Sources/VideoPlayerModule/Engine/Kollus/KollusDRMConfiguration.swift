//
//  KollusDRMConfiguration.swift
//  VideoPlayerModule
//
//  Created by 모바일개발팀_정준영 on 2026/05/15.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

import Foundation

public struct KollusDRMConfiguration: Sendable, Equatable {
    public let fpsCertificateURL: URL?
    public let fpsDRMURL: URL?
    public let extraParameters: [String: String]

    public init(
        fpsCertificateURL: URL? = nil,
        fpsDRMURL: URL? = nil,
        extraParameters: [String: String] = [:]
    ) {
        self.fpsCertificateURL = fpsCertificateURL
        self.fpsDRMURL = fpsDRMURL
        self.extraParameters = extraParameters
    }
}
