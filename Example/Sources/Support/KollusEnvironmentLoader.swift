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

    /// plist 자격증명 + 호출 측(세팅) 동작 플래그를 합성해 environment를 만든다.
    static func loadFromBundle(
        hardwareDecoderPreferred: Bool = true,
        audioBackgroundPlayPolicy: Bool = false
    ) throws -> DemoConfiguration {
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
        let drm = Self.makeDRMConfiguration(from: dictionary)
        let chat = Self.makeLiveChatProfile(from: dictionary)

        let environment = KollusEnvironment(
            applicationKey: applicationKey,
            applicationBundleID: applicationBundleID,
            applicationExpireDate: applicationExpireDate,
            storagePath: Self.makeStoragePath(),
            hardwareDecoderPreferred: hardwareDecoderPreferred,
            audioBackgroundPlayPolicy: audioBackgroundPlayPolicy,
            drm: drm,
            chat: chat
        )

        return DemoConfiguration(environment: environment, mediaContentKey: mediaContentKey)
    }

    /// Kollus SDK storage(SQLite `player.db`) 전용 쓰기 디렉터리.
    /// 미설정 시 SDK가 루트 `/player.db`를 열려다 실패해 BlockStorage DB 연결이 NULL이 된다.
    /// `KollusEnvironment.validate()`가 "존재하는 디렉터리"를 요구하므로 미리 생성한다.
    private static func makeStoragePath() -> URL? {
        let fileManager = FileManager.default
        guard let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let storageURL = documents.appendingPathComponent("KollusStorage", isDirectory: true)
        do {
            try fileManager.createDirectory(at: storageURL, withIntermediateDirectories: true)
        } catch {
            return nil
        }
        return storageURL
    }

    private static func makeDRMConfiguration(from dictionary: [String: Any]) -> KollusDRMConfiguration {
        let certURL = (dictionary["fpsCertificateURL"] as? String)
            .flatMap { $0.isEmpty ? nil : URL(string: $0) }
        let drmURL = (dictionary["fpsDRMURL"] as? String)
            .flatMap { $0.isEmpty ? nil : URL(string: $0) }
        return KollusDRMConfiguration(
            fpsCertificateURL: certURL,
            fpsDRMURL: drmURL
        )
    }

    private static func makeLiveChatProfile(from dictionary: [String: Any]) -> KollusLiveChatProfile? {
        guard
            let roomId = dictionary["liveChatRoomId"] as? String, !roomId.isEmpty,
            let serverString = dictionary["liveChatServer"] as? String, !serverString.isEmpty,
            let server = URL(string: serverString),
            let userId = dictionary["liveChatUserId"] as? String, !userId.isEmpty,
            let nickName = dictionary["liveChatNickName"] as? String, !nickName.isEmpty
        else {
            return nil
        }
        return KollusLiveChatProfile(
            roomId: roomId,
            chattingServer: server,
            userId: userId,
            nickName: nickName
        )
    }
}
