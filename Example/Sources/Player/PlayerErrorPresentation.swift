//
//  PlayerErrorPresentation.swift
//  VideoPlayerExample
//
//  Created by JunyoungJung on 2026/06/10.
//
//  PlayerError 케이스 → 사용자 안내 문구 변환.
//  모듈이 세분화한 에러(licenseExpired/storageFull/...)를 복구 행동이 보이는 문구로 매핑한다.
//

import Foundation
import VideoPlayerCore

enum PlayerErrorPresentation {
    struct Message {
        let title: String
        let body: String
        /// 사용자가 취할 수 있는 복구 행동. nil이면 단순 안내.
        let recoverySuggestion: String?
    }

    static func message(for error: Error) -> Message {
        guard let playerError = error as? PlayerError else {
            return Message(title: "재생 오류", body: error.localizedDescription, recoverySuggestion: nil)
        }

        switch playerError {
        case .networkError(let detail):
            return Message(
                title: "네트워크 오류",
                body: detail,
                recoverySuggestion: "네트워크 연결을 확인한 뒤 다시 시도해 주세요."
            )
        case .authenticationFailed(let detail):
            return Message(
                title: "인증 오류",
                body: detail,
                recoverySuggestion: "앱을 최신 버전으로 업데이트해 주세요."
            )
        case .licenseExpired(let detail):
            return Message(
                title: "시청 기간 만료",
                body: detail,
                recoverySuggestion: "남은 재생 횟수/시간이 소진되었습니다. 콘텐츠를 다시 받아 주세요."
            )
        case .licenseRenewalRequired(let detail):
            return Message(
                title: "라이선스 갱신 필요",
                body: detail,
                recoverySuggestion: "네트워크 연결 후 다운로드 화면에서 라이선스를 갱신해 주세요."
            )
        case .storageFull(let detail):
            return Message(
                title: "저장 공간 부족",
                body: detail,
                recoverySuggestion: "시청 완료한 다운로드를 삭제하거나 저장 공간을 확보해 주세요."
            )
        case .downloadConflict(let detail):
            return Message(
                title: "다운로드 충돌",
                body: detail,
                recoverySuggestion: "이미 다운로드 중이거나 완료된 콘텐츠입니다."
            )
        case .contentNotFound(let detail):
            return Message(
                title: "콘텐츠 없음",
                body: detail,
                recoverySuggestion: "목록을 새로고침한 뒤 다시 시도해 주세요."
            )
        case .deviceNotSupported(let detail):
            return Message(
                title: "미지원 기기",
                body: detail,
                recoverySuggestion: "이 기기에서는 해당 콘텐츠를 재생할 수 없습니다."
            )
        case .decodingError(let detail):
            return Message(title: "재생 오류", body: detail, recoverySuggestion: "잠시 후 다시 시도해 주세요.")
        case .engineError(let detail), .unknown(let detail):
            return Message(title: "재생 오류", body: detail, recoverySuggestion: nil)
        }
    }

    /// 토스트용 한 줄 요약.
    static func toastText(for error: Error) -> String {
        let message = message(for: error)
        return message.recoverySuggestion ?? "\(message.title) — \(message.body)"
    }
}
