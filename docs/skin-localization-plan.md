# Skin 다국어(Localization) 설계

작성: JunyoungJung, 2026-06-11

패키지가 기본 다국어 문자열을 내장하고, host가 **개별 문구 오버라이드** 또는 **전체 공급자 교체**를
주입할 수 있게 하는 설계. `PlayerSkinTheme`(색/폰트/아이콘의 dictionary 부분 오버라이드 +
`.default` 폴백) 패턴을 문자열에 그대로 확장한다.

## 1. 현황

- 로컬라이제이션 인프라 없음 — `NSLocalizedString` / `String(localized:)` / `.xcstrings` 사용 0건
- 사용자 노출 문자열 약 35개가 한글 하드코딩:

| 위치 | 내용 |
|------|------|
| `VideoPlayerSkin/PlayerKeyCommandRegistry.swift` | 키 커맨드 타이틀 12개 ("재생/일시정지" 등) |
| `VideoPlayerSkin/Blocks/*` | 버튼 타이틀·accessibilityLabel ("일시정지", "더보기", "화면 잠금", "시작", "끝" 등) |
| `VideoPlayerSkin/PlayerRenderSurfaceView.swift` | "영상 준비 중" placeholder |
| `VideoPlayerSkin/PlayerScreenCaptureShieldView.swift` | 녹화 보호 안내 메시지 |
| `VideoPlayerSkin/PlayerGestureHUDView.swift` | "%.1f배속" 포맷 (포맷 인자 필요) |
| `VideoPlayerCore/Download/DownloadedContent.swift` | 라이선스 만료 메시지 4개 |

- 엔진의 `PlayerError.engineError("...")` 진단 문구(~25개)는 로그/디버깅용 — 로컬라이즈 대상 아님.
  영어 통일만 권장하며 UI 노출 문구는 host 책임.

## 2. 목표

1. **무설정 기본 동작**: host가 아무것도 주입하지 않으면 패키지 내장 `Localizable.xcstrings`가
   시스템 언어에 따라 ko/en 문구 제공
2. **부분 오버라이드**: 특정 문구만 host가 교체 (예: 녹화 보호 메시지를 서비스 문구로)
3. **전체 교체**: host의 번들/서버 문구 시스템으로 전체 위임
4. **경계 유지**: `Core`는 사용자 노출 문자열을 만들지 않는다 — enum 신호만 발행

## 3. 폴더 구조 (추가분)

```
Sources/VideoPlayerSkin/
  Theme/
    PlayerSkinColorRole.swift          (기존)
    PlayerSkinFontRole.swift           (기존)
    PlayerSkinIcon.swift               (기존)
    PlayerSkinTheme.swift              (기존)
    PlayerSkinTextRole.swift           ← 신규: 문자열 키 enum
    PlayerSkinStrings.swift            ← 신규: 리졸버 + 기본 provider
  Resources/
    PlayerSkin.xcassets                (기존)
    Localizable.xcstrings              ← 신규: ko/en 내장 String Catalog

Sources/VideoPlayerCore/
  Download/DownloadedContent.swift     ← 수정: 메시지 String 제거, reason enum화

Tests/VideoPlayerModuleTests/Skin/
  PlayerSkinStringsTests.swift         ← 신규
```

`Package.swift` 변경:

```swift
let package = Package(
    name: "videoplayer-ios-ms",
    defaultLocalization: "ko",          // ← 추가
    ...
)
// VideoPlayerSkin 타깃은 이미 Resources/ process 설정이 있어 xcstrings가 자동 포함됨
```

## 4. 아키텍처

```
                    resolve(.pauseButton)
                          │
        ┌─────────────────▼──────────────────┐
        │        PlayerSkinStrings           │   (Theme과 동일한 값 struct)
        │                                    │
        │  ① overrides[role]      ── 있으면 반환   (host 부분 오버라이드)
        │  ② provider?.string(role) ── 있으면 반환  (host 전체 교체)
        │  ③ Bundle.module xcstrings ── 기본 다국어 (ko/en 내장)
        │  ④ 영어 fallback 리터럴            (xcstrings 키 누락 안전망)
        └────────────────────────────────────┘
                          │
              Blocks / HUD / Shield / KeyCommand 가 소비
```

- 주입 경로: `AssembledPlayerSkin(blueprint:theme:strings:)` — `theme`과 대칭
- `PlayerSkinState` 렌더 흐름 변경 없음. skin이 생성 시점에 보관한 `strings`를 각 block 렌더에 전달
- **Core 경계**: `DownloadedContent`의 라이선스 메시지는 `String` 대신
  `LicenseFailureReason` enum case만 발행. 문구화는 Skin(기본 다국어) 또는 host가 담당

## 5. 핵심 타입

### 5.1 PlayerSkinTextRole — 문자열 키

```swift
/// 재생기 skin이 노출하는 모든 사용자 노출 문구의 키.
/// rawValue가 Localizable.xcstrings의 키와 1:1 대응한다.
public enum PlayerSkinTextRole: String, CaseIterable, Sendable {
    // 재생 컨트롤
    case play = "skin.play"
    case pause = "skin.pause"
    case moreButton = "skin.more"
    case sectionRepeat = "skin.sectionRepeat"
    case sectionRepeatStart = "skin.sectionRepeat.start"
    case sectionRepeatEnd = "skin.sectionRepeat.end"
    case lockScreen = "skin.lock"
    case unlockScreen = "skin.unlock"
    case rateUp = "skin.rate.up"
    case rateDown = "skin.rate.down"
    case screenModePortrait = "skin.screenMode.portrait"
    case screenModeLandscape = "skin.screenMode.landscape"

    // 화면 배율
    case displayScaleFit = "skin.displayScale.fit"
    case displayScaleAspectFill = "skin.displayScale.aspectFill"
    case displayScaleFill = "skin.displayScale.fill"
    case displayScaleChangeTo = "skin.displayScale.changeTo"   // 포맷: %@

    // 상태 안내
    case videoPreparing = "skin.surface.preparing"
    case captureProtected = "skin.capture.protected"

    // 라이선스 (Core reason enum → 문구)
    case licenseExpired = "skin.license.expired"
    case licensePeriodOver = "skin.license.periodOver"
    case licenseNoPlayCount = "skin.license.noPlayCount"
    case licenseNoPlayTime = "skin.license.noPlayTime"

    // 키 커맨드 (iPad 단축키 HUD 노출)
    case keyTogglePlayPause = "skin.key.togglePlayPause"
    case keySkipBackward = "skin.key.skipBackward"
    case keySkipForward = "skin.key.skipForward"
    case keyVolumeUp = "skin.key.volumeUp"
    case keyVolumeDown = "skin.key.volumeDown"
    case keyToggleDisplayScaling = "skin.key.toggleDisplayScaling"
    case keyRateDown = "skin.key.rateDown"
    case keyRateUp = "skin.key.rateUp"
    case keyToggleScreenMode = "skin.key.toggleScreenMode"
    case keyCaptionSmaller = "skin.key.captionSmaller"
    case keyCaptionLarger = "skin.key.captionLarger"
    case keyOpenSettings = "skin.key.openSettings"

    // 포맷 문자열 (인자 포함)
    case playbackRateFormat = "skin.rate.format"               // 포맷: %.1f → "%.1f배속" / "%.1fx"
    case playbackRateWholeFormat = "skin.rate.wholeFormat"     // 포맷: %d  → "%d배속" / "%dx"
}
```

### 5.2 PlayerSkinStringProviding — 전체 교체 계약

```swift
/// host가 문자열 공급원을 통째로 교체할 때 구현하는 계약.
/// nil 반환 시 패키지 기본 xcstrings로 폴백한다.
public protocol PlayerSkinStringProviding: Sendable {
    func string(for role: PlayerSkinTextRole) -> String?
}
```

### 5.3 PlayerSkinStrings — 리졸버 (Theme 패턴 대칭)

```swift
/// 재생기 skin의 사용자 노출 문구 토큰.
///
/// Theme과 동일하게 host가 원하는 role만 채워 주입하는 값 struct.
/// 비어 있는 role은 provider → 패키지 내장 xcstrings → 영어 fallback 순으로 해석된다.
public struct PlayerSkinStrings: Sendable {
    /// 개별 문구 오버라이드. provider보다 우선한다.
    public var overrides: [PlayerSkinTextRole: String]
    /// 문자열 공급원 전체 교체. 미지정 시 패키지 기본 다국어 사용.
    public var provider: (any PlayerSkinStringProviding)?

    public init(overrides: [PlayerSkinTextRole: String] = [:],
                provider: (any PlayerSkinStringProviding)? = nil) {
        self.overrides = overrides
        self.provider = provider
    }

    public static let `default` = PlayerSkinStrings()

    public func resolve(_ role: PlayerSkinTextRole) -> String {
        if let overridden = overrides[role] { return overridden }
        if let provided = provider?.string(for: role) { return provided }
        return Self.bundled(role)
    }

    /// 포맷 role 전용. resolve 결과를 format 문자열로 사용한다.
    public func resolve(_ role: PlayerSkinTextRole, _ arguments: CVarArg...) -> String {
        String(format: resolve(role), arguments: arguments)
    }

    /// 패키지 내장 xcstrings 조회. 키 누락 시 영어 fallback.
    private static func bundled(_ role: PlayerSkinTextRole) -> String {
        let localized = NSLocalizedString(role.rawValue, bundle: .module, comment: "")
        // NSLocalizedString은 키 누락 시 키 자체를 반환 — fallback 테이블로 보강
        return localized == role.rawValue ? englishFallback[role] ?? role.rawValue : localized
    }

    private static let englishFallback: [PlayerSkinTextRole: String] = [
        .play: "Play", .pause: "Pause", .videoPreparing: "Preparing video",
        .captureProtected: "Playback is protected during screen recording",
        .playbackRateFormat: "%.1fx",
        // ... 전 role 영어 기본값
    ]
}
```

### 5.4 호출부 교체 예

```swift
// PlayButtonBlock.swift — before
button.accessibilityLabel = state.isPlaying ? "일시정지" : "재생"

// after
button.accessibilityLabel = strings.resolve(state.isPlaying ? .pause : .play)
```

```swift
// PlayerGestureHUDView.swift — before
return String(format: "%.1f배속", self)

// after
return strings.resolve(.playbackRateFormat, self)
```

### 5.5 주입 지점 — AssembledPlayerSkin

```swift
public init(blueprint: PlayerSkinBlueprint = .default,
            theme: PlayerSkinTheme = .default,
            strings: PlayerSkinStrings = .default) {
    self.blueprint = blueprint
    self.theme = theme
    self.strings = strings
}
```

### 5.6 Core 경계 — 라이선스 메시지 enum화

```swift
// VideoPlayerCore/Download/DownloadedContent.swift — before
return .licenseRenewalRequired("오프라인 라이선스가 만료되었습니다.")

// after: Core는 신호만 발행
public enum LicenseFailureReason: Sendable, Equatable {
    case expired            // 오프라인 라이선스 만료
    case periodOver         // 유효 기간 경과
    case noRemainingCount   // 남은 재생 횟수 없음
    case noRemainingTime    // 남은 재생 시간 없음
}
return .licenseRenewalRequired(.expired)

// Skin/host가 문구화
extension PlayerSkinTextRole {
    static func role(for reason: LicenseFailureReason) -> PlayerSkinTextRole {
        switch reason {
        case .expired: .licenseExpired
        case .periodOver: .licensePeriodOver
        case .noRemainingCount: .licenseNoPlayCount
        case .noRemainingTime: .licenseNoPlayTime
        }
    }
}
```

## 6. Host 사용 예시

```swift
// 케이스 A — 무설정: 시스템 언어 따라 ko/en 자동
let skin = AssembledPlayerSkin()

// 케이스 B — 문구 하나만 교체
var strings = PlayerSkinStrings()
strings.overrides[.captureProtected] = "강의 콘텐츠 보호를 위해 녹화 중에는 화면이 가려집니다"
let skin = AssembledPlayerSkin(strings: strings)

// 케이스 C — host Localizable 테이블로 전체 위임
struct HostBundleStrings: PlayerSkinStringProviding {
    let bundle: Bundle
    let tableName: String

    func string(for role: PlayerSkinTextRole) -> String? {
        let value = bundle.localizedString(forKey: role.rawValue, value: missingMarker, table: tableName)
        return value == missingMarker ? nil : value   // 없는 키는 패키지 기본으로 폴백
    }
    private var missingMarker: String { "\u{0}" }
}
let skin = AssembledPlayerSkin(
    strings: PlayerSkinStrings(provider: HostBundleStrings(bundle: .main, tableName: "Player"))
)

// 케이스 D — 서버 내려준 문구 + 일부 고정 오버라이드 혼합
let skin = AssembledPlayerSkin(
    strings: PlayerSkinStrings(
        overrides: [.videoPreparing: remoteConfig.preparingMessage],
        provider: RemoteStringsProvider(catalog: serverCatalog)
    )
)
```

## 7. Localizable.xcstrings 구성

- 위치: `Sources/VideoPlayerSkin/Resources/Localizable.xcstrings`
- 초기 언어: `ko`(source), `en`
- 키 = `PlayerSkinTextRole.rawValue` (`skin.` prefix로 네임스페이스 충돌 방지)
- 언어 추가 시 xcstrings에 번역만 추가 — 코드 변경 없음

```jsonc
// 발췌 예시
{
  "sourceLanguage": "ko",
  "strings": {
    "skin.pause": {
      "localizations": {
        "ko": { "stringUnit": { "state": "translated", "value": "일시정지" } },
        "en": { "stringUnit": { "state": "translated", "value": "Pause" } }
      }
    },
    "skin.rate.format": {
      "localizations": {
        "ko": { "stringUnit": { "state": "translated", "value": "%.1f배속" } },
        "en": { "stringUnit": { "state": "translated", "value": "%.1fx" } }
      }
    }
  },
  "version": "1.0"
}
```

## 8. 테스트 계획

`Tests/VideoPlayerModuleTests/Skin/PlayerSkinStringsTests.swift` (`#if canImport(UIKit)` 가드):

```swift
@Test("override가 provider보다 우선한다")
func overrideBeatsProvider() {
    let strings = PlayerSkinStrings(
        overrides: [.pause: "멈춤"],
        provider: StubProvider(values: [.pause: "Pause-P"])
    )
    #expect(strings.resolve(.pause) == "멈춤")
}

@Test("provider가 nil을 반환하면 패키지 기본으로 폴백한다")
func providerNilFallsBackToBundle() {
    let strings = PlayerSkinStrings(provider: StubProvider(values: [:]))
    #expect(!strings.resolve(.play).isEmpty)
    #expect(strings.resolve(.play) != PlayerSkinTextRole.play.rawValue)
}

@Test("모든 role이 내장 xcstrings에 키를 가진다", arguments: PlayerSkinTextRole.allCases)
func allRolesHaveBundledKey(role: PlayerSkinTextRole) {
    let value = NSLocalizedString(role.rawValue, bundle: .module, comment: "")
    #expect(value != role.rawValue)   // 키 누락이면 키 자체가 반환됨
}

@Test("포맷 role은 인자를 받아 문자열을 만든다")
func formatRoleAcceptsArguments() {
    let strings = PlayerSkinStrings(overrides: [.playbackRateFormat: "%.1fx"])
    #expect(strings.resolve(.playbackRateFormat, 1.5) == "1.5x")
}
```

추가:

- 기존 `PlaybackStateReducerTests` 영향 없음 (Core는 enum만 발행하므로 메시지 비교 테스트가 있으면 enum 비교로 교체)
- `PlayerModuleBoundaryTests`에 서비스 용어 금지 규칙 그대로 적용 — xcstrings 내용물도 검사 대상에 포함할지 검토

## 9. 구현 순서

1. `Package.swift`에 `defaultLocalization: "ko"` 추가
2. `PlayerSkinTextRole` + `PlayerSkinStrings` + `Localizable.xcstrings`(ko/en) 추가, 테스트 작성
3. `AssembledPlayerSkin`에 `strings` 파라미터 추가, Blocks/HUD/Shield/KeyCommand 하드코딩 교체
4. Core `LicenseFailureReason` enum화 + 발행부/소비부 교체 (breaking change — host 마이그레이션 노트 필요)
5. Example 앱에 오버라이드/전체 교체 데모 추가 (`example-app-rebuild-plan.md` 상태 갱신)
6. 엔진 진단 문구 영어 통일 (별도 커밋, 로컬라이즈 아님)

## 10. 결정 사항 / 트레이드오프

- **dictionary overrides + provider 이중 구조**: Theme은 dictionary만 쓰지만 문자열은
  "서버 문구 시스템 전체 위임" 요구가 있어 provider 계약을 추가. 둘 다 같은 `resolve()`로 수렴
- **포맷 문자열도 role로 관리**: "%.1f배속" 같은 어순·단위 차이는 단어 치환으로 해결 불가 —
  포맷 자체를 로컬라이즈 대상으로 삼는다
- **Core 메시지 enum화는 breaking change**: `licenseRenewalRequired(String)` →
  `licenseRenewalRequired(LicenseFailureReason)`. 문자열을 유지하며 deprecated 병행하는
  방법도 있으나, host가 아직 단일이므로 한 번에 전환
- **engineError 진단 문구는 비대상**: 사용자 노출은 host가 `PlayerError` case 기준으로
  자체 문구를 만든다는 기존 계약 유지
