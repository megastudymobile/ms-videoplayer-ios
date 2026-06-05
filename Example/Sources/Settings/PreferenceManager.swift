//
//  PreferenceManager.swift
//  VideoPlayerExample
//
//  Created by JunyoungJung on 2026/06/05.
//
//  샘플 앱 PreferenceManager 이식 — UserDefaults 기반 설정 저장.
//  저장 키는 샘플과 동일하게 유지한다(예: seekRange의 실제 키 "seekerRange").
//

import Foundation

@propertyWrapper
struct UserDefault<T> {
    let key: String
    let defaultValue: T

    init(_ key: String, defaultValue: T) {
        self.key = key
        self.defaultValue = defaultValue
    }

    var wrappedValue: T {
        get { UserDefaults.standard.object(forKey: key) as? T ?? defaultValue }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}

// MARK: - 설정 enum (샘플 ActionSheetEnums.swift 이식)

enum PlayerCodec: Int, CaseIterable {
    case hardware
    case software
    case nativePlayer

    var title: String {
        switch self {
        case .hardware: return "Hardware"
        case .software: return "Software"
        case .nativePlayer: return "Native Player"
        }
    }
}

enum SeekRange: Int, CaseIterable {
    case r5, r10, r20, r30, r60, r300

    var seconds: Int {
        switch self {
        case .r5: return 5
        case .r10: return 10
        case .r20: return 20
        case .r30: return 30
        case .r60: return 60
        case .r300: return 300
        }
    }

    var title: String { "\(seconds)초" }
}

enum SubtitleSize: Int, CaseIterable {
    case verySmall, small, normal, big, veryBig

    /// 패키지 setCaptionFontSize(Int)에 전달할 포인트 값.
    var fontSize: Int {
        switch self {
        case .verySmall: return 12
        case .small: return 16
        case .normal: return 20
        case .big: return 24
        case .veryBig: return 28
        }
    }

    var title: String {
        switch self {
        case .verySmall: return "아주 작게"
        case .small: return "작게"
        case .normal: return "보통"
        case .big: return "크게"
        case .veryBig: return "아주 크게"
        }
    }
}

enum SubtitleColor: Int, CaseIterable {
    case white, black, lightGray, darkGray, red, pink, orange, yellow, green, blue

    var title: String {
        switch self {
        case .white: return "흰색"
        case .black: return "검정"
        case .lightGray: return "밝은 회색"
        case .darkGray: return "어두운 회색"
        case .red: return "빨강"
        case .pink: return "분홍"
        case .orange: return "주황"
        case .yellow: return "노랑"
        case .green: return "초록"
        case .blue: return "파랑"
        }
    }
}

// MARK: - PreferenceManager

enum PreferenceManager {
    @UserDefault("isBackgroundAudioPlay", defaultValue: false)
    static var isBackgroundAudioPlay: Bool

    @UserDefault("isUseNetworkData", defaultValue: true)
    static var isUseNetworkData: Bool

    @UserDefault("playerCodec", defaultValue: PlayerCodec.nativePlayer.rawValue)
    static var playerCodec: Int

    @UserDefault("seekerRange", defaultValue: SeekRange.r10.rawValue)   // 샘플 저장 키 그대로
    static var seekRange: Int

    @UserDefault("subtitleSize", defaultValue: SubtitleSize.normal.rawValue)
    static var subtitleSize: Int

    @UserDefault("subtitleColor", defaultValue: SubtitleColor.white.rawValue)
    static var subtitleColor: Int

    @UserDefault("isUseSubtitleBackground", defaultValue: true)
    static var isUseSubtitleBackground: Bool

    @UserDefault("DRMCheckBox", defaultValue: true)
    static var DRMCheckBox: Bool

    @UserDefault("UsePlayerType", defaultValue: true)
    static var UsePlayerType: Bool

    @UserDefault("isFirstExecuted", defaultValue: true)
    static var isFirstExecuted: Bool

    // MARK: 파생 값 (패키지 적용 지점 — 문서 §6 세팅 매핑)

    /// 코덱 설정 → KollusEnvironment.hardwareDecoderPreferred
    static var hardwareDecoderPreferred: Bool {
        PlayerCodec(rawValue: playerCodec) != .software
    }

    /// 시크 간격 초 → PlayerFeaturePolicy.skipInterval
    static var seekRangeSeconds: Int {
        (SeekRange(rawValue: seekRange) ?? .r10).seconds
    }

    /// 자막 크기 → setCaptionFontSize(Int)
    static var captionFontSize: Int {
        (SubtitleSize(rawValue: subtitleSize) ?? .normal).fontSize
    }

    /// 샘플 resetPreferenceDatas() parity — 일부 키 제외 전체 초기화.
    static func reset() {
        let userDefaults = UserDefaults.standard
        let preservedKeys: Set<String> = ["isFirstExecuted"]
        for key in userDefaults.dictionaryRepresentation().keys where preservedKeys.contains(key) == false {
            userDefaults.removeObject(forKey: key)
        }
    }
}
