//
//  KollusEnvironmentValidationTests.swift
//  VideoPlayerModuleTests
//
//  Created by 모바일개발팀_정준영 on 2026/05/15.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

#if canImport(UIKit)

import XCTest
@testable import VideoPlayerEngineKollus

final class KollusEnvironmentValidationTests: XCTestCase {

    private let future = Date().addingTimeInterval(60 * 60 * 24 * 30)
    private let past = Date().addingTimeInterval(-60 * 60 * 24)

    func test_validate_succeedsForValidEnvironment() throws {
        let env = KollusEnvironment(
            applicationKey: "valid-key",
            applicationBundleID: "com.example.app",
            applicationExpireDate: future
        )
        XCTAssertNoThrow(try env.validate())
    }

    func test_validate_throwsMissingApplicationKey() {
        let env = KollusEnvironment(
            applicationKey: "",
            applicationBundleID: "com.example.app",
            applicationExpireDate: future
        )

        XCTAssertThrowsError(try env.validate()) { error in
            XCTAssertEqual(error as? KollusEnvironmentError, .missingApplicationKey)
        }
    }

    func test_validate_throwsMissingBundleID() {
        let env = KollusEnvironment(
            applicationKey: "valid-key",
            applicationBundleID: "",
            applicationExpireDate: future
        )

        XCTAssertThrowsError(try env.validate()) { error in
            XCTAssertEqual(error as? KollusEnvironmentError, .missingBundleID)
        }
    }

    func test_validate_throwsExpiredApplicationKey() {
        let env = KollusEnvironment(
            applicationKey: "valid-key",
            applicationBundleID: "com.example.app",
            applicationExpireDate: past
        )

        XCTAssertThrowsError(try env.validate(now: Date())) { error in
            guard case .expiredApplicationKey(let expire, _) = error as? KollusEnvironmentError else {
                XCTFail("Expected .expiredApplicationKey, got \(error)")
                return
            }
            XCTAssertEqual(expire, past)
        }
    }

    func test_validate_throwsInvalidCacheSize() {
        let env = KollusEnvironment(
            applicationKey: "valid-key",
            applicationBundleID: "com.example.app",
            applicationExpireDate: future,
            cacheSizeMB: 0
        )

        XCTAssertThrowsError(try env.validate()) { error in
            XCTAssertEqual(error as? KollusEnvironmentError, .invalidCacheSize(0))
        }
    }

    func test_validate_throwsInvalidStoragePath() {
        let bogus = URL(fileURLWithPath: "/nonexistent/path/\(UUID().uuidString)")
        let env = KollusEnvironment(
            applicationKey: "valid-key",
            applicationBundleID: "com.example.app",
            applicationExpireDate: future,
            storagePath: bogus
        )

        XCTAssertThrowsError(try env.validate()) { error in
            XCTAssertEqual(error as? KollusEnvironmentError, .invalidStoragePath(bogus))
        }
    }
}

#endif
