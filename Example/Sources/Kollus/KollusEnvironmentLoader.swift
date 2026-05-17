//
//  KollusEnvironmentLoader.swift
//  VideoPlayerExample
//
//  Created by 모바일팀_정준영 on 2026/05/17.
//

import Foundation
import VideoPlayerEngineKollus

enum KollusEnvironmentLoader {
    struct DemoConfiguration {
        let environment: KollusEnvironment
        let mediaContentKey: String
    }

    enum LoadError: LocalizedError {
        case fileMissing
        case malformed(String)

        var errorDescription: String? {
            switch self {
            case .fileMissing:
                return "Example/Resources/kollus.local.plist 가 번들에 포함되어 있지 않습니다. .example을 복제해 자격증명을 입력하고 tuist generate를 다시 실행하세요."
            case .malformed(let reason):
                return "kollus.local.plist 형식 오류: \(reason)"
            }
        }
    }

    static func loadFromBundle() throws -> DemoConfiguration {
        guard let url = Bundle.main.url(forResource: "kollus.local", withExtension: "plist") else {
            throw LoadError.fileMissing
        }

        let data = try Data(contentsOf: url)
        let raw = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)

        guard let dictionary = raw as? [String: Any] else {
            throw LoadError.malformed("plist root는 dictionary여야 합니다.")
        }

        guard let applicationKey = dictionary["applicationKey"] as? String, !applicationKey.isEmpty else {
            throw LoadError.malformed("applicationKey 누락")
        }
        guard let applicationBundleID = dictionary["applicationBundleID"] as? String, !applicationBundleID.isEmpty else {
            throw LoadError.malformed("applicationBundleID 누락")
        }
        guard let applicationExpireDate = dictionary["applicationExpireDate"] as? Date else {
            throw LoadError.malformed("applicationExpireDate 누락")
        }
        let mediaContentKey = (dictionary["mediaContentKey"] as? String) ?? ""

        let environment = KollusEnvironment(
            applicationKey: applicationKey,
            applicationBundleID: applicationBundleID,
            applicationExpireDate: applicationExpireDate
        )

        return DemoConfiguration(environment: environment, mediaContentKey: mediaContentKey)
    }
}
