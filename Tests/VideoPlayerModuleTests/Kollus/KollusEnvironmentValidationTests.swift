//
//  KollusEnvironmentValidationTests.swift
//  VideoPlayerModuleTests
//
//  Created by 모바일개발팀_정준영 on 2026/05/15.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

#if canImport(UIKit)

import Foundation
import Testing
@testable import VideoPlayerEngineKollus

@Suite("KollusEnvironment validate() 검증")
struct KollusEnvironmentValidationTests {

    private let future = Date().addingTimeInterval(60 * 60 * 24 * 30)
    private let past = Date().addingTimeInterval(-60 * 60 * 24)

    @Test("유효한 환경은 validate 성공")
    func validate_succeedsForValidEnvironment() throws {
        let env = KollusEnvironment(
            applicationKey: "valid-key",
            applicationBundleID: "com.example.app",
            applicationExpireDate: future
        )
        try env.validate()
    }

    @Test("applicationKey 누락 시 throw")
    func validate_throwsMissingApplicationKey() {
        let env = KollusEnvironment(
            applicationKey: "",
            applicationBundleID: "com.example.app",
            applicationExpireDate: future
        )

        #expect {
            try env.validate()
        } throws: { error in
            (error as? KollusEnvironmentError) == .missingApplicationKey
        }
    }

    @Test("bundleID 누락 시 throw")
    func validate_throwsMissingBundleID() {
        let env = KollusEnvironment(
            applicationKey: "valid-key",
            applicationBundleID: "",
            applicationExpireDate: future
        )

        #expect {
            try env.validate()
        } throws: { error in
            (error as? KollusEnvironmentError) == .missingBundleID
        }
    }

    @Test("만료된 applicationKey 시 throw")
    func validate_throwsExpiredApplicationKey() {
        let env = KollusEnvironment(
            applicationKey: "valid-key",
            applicationBundleID: "com.example.app",
            applicationExpireDate: past
        )

        #expect {
            try env.validate(now: Date())
        } throws: { error in
            guard case .expiredApplicationKey(let expire, _) = error as? KollusEnvironmentError else {
                return false
            }
            return expire == past
        }
    }

    @Test("잘못된 cacheSize 시 throw")
    func validate_throwsInvalidCacheSize() {
        let env = KollusEnvironment(
            applicationKey: "valid-key",
            applicationBundleID: "com.example.app",
            applicationExpireDate: future,
            cacheSizeMB: 0
        )

        #expect {
            try env.validate()
        } throws: { error in
            (error as? KollusEnvironmentError) == .invalidCacheSize(0)
        }
    }

    @Test("잘못된 proxyPort 시 throw")
    func validate_throwsInvalidProxyPort() {
        let env = KollusEnvironment(
            applicationKey: "valid-key",
            applicationBundleID: "com.example.app",
            applicationExpireDate: future,
            proxyPort: 0
        )

        #expect {
            try env.validate()
        } throws: { error in
            (error as? KollusEnvironmentError) == .invalidProxyPort(0)
        }
    }

    @Test("잘못된 storagePath 시 throw")
    func validate_throwsInvalidStoragePath() {
        let bogus = URL(fileURLWithPath: "/nonexistent/path/\(UUID().uuidString)")
        let env = KollusEnvironment(
            applicationKey: "valid-key",
            applicationBundleID: "com.example.app",
            applicationExpireDate: future,
            storagePath: bogus
        )

        #expect {
            try env.validate()
        } throws: { error in
            (error as? KollusEnvironmentError) == .invalidStoragePath(bogus)
        }
    }
}

#endif
