# 10편 — Example 앱, 테스트, 작업 레시피

> [← 9편: 전체 플로우](09-full-flow.md) · [시리즈 목차](README.md)

마지막 편입니다. 실제로 손을 움직일 때 필요한 것들 — 데모 앱 돌리기, 테스트 돌리기, 자주 하는 작업의 순서 — 를 정리합니다.

## Example 앱

### 부트스트랩

```bash
# 1) Kollus 자격증명 plist 준비 (gitignored — 커밋되지 않음)
cp Example/Resources/kollus.local.plist.example Example/Resources/kollus.local.plist
# applicationKey / applicationBundleID / applicationExpireDate / mediaContentKey 입력

# 2) Xcode 프로젝트 생성 (Tuist)
tuist generate
open VideoPlayerExample.xcworkspace   # VideoPlayerExample scheme 실행
```

### 화면 구성

| 화면 | 보여주는 것 |
| --- | --- |
| Root | URL 입력 + 샘플 HLS 2종 + Kollus 데모 진입 |
| Player | `PlayerViewController` — module + skin + 제스처 풀 와이어링 ([9편](09-full-flow.md)) |
| Download | `KollusDownloadCenter.contents` 구독, start/cancel/remove + 고급 액션 |
| Observer 로그 | `KollusObserver` + `KollusDiagnosticsSink`를 ring buffer(500개)로 시간순 표시 |
| Settings | 제스처/배속/자막/디코더 설정 → `PreferenceManager`(UserDefaults) |

구조에서 눈여겨볼 두 곳:

```swift
// Example/Sources/Player/PlayerModuleProvider.swift — 엔진 선택 분기
#if targetEnvironment(simulator)
// 시뮬레이터: Kollus 미지원 → 안내 문구만 띄우는 no-op 엔진
return await PlayerModuleWiring.makeModule(
    engine: UnsupportedEnvironmentEngine(message: "Kollus 재생은 실기기에서만 지원됩니다."),
    engineRuntimeTraits: []
)
#else
return await factory.makeModule()    // 실기기: Kollus factory (캐시 재사용)
#endif
```

```swift
// Example/Sources/Support/KollusEnvironmentLoader.swift — plist → KollusEnvironment
guard let url = Bundle.main.url(forResource: "kollus.local", withExtension: "plist") else {
    throw LoadError.fileMissing
}
// 필수 키 검증 → KollusEnvironment(...) 생성 → environment.validate()
```

Player/Download/Observer 로그 화면이 **같은 factory 인스턴스를 공유**한다는 점이 중요합니다. bootstrapper(인증 캐시)와 download center가 하나로 묶이는 지점입니다.

### Example의 한계

데모는 와이어링을 보여줄 뿐, 실제 Kollus 재생은 유효한 `applicationKey` + 만료되지 않은 `mediaContentKey`가 필요합니다. DRM은 PallyCon 인증서/라이선스 적용 콘텐츠가 있어야 의미가 있습니다. 환경이 없으면 화면은 뜨고 SDK 에러가 Observer 로그에 찍힙니다 — 그것 자체가 디버깅 학습 자료입니다.

## 테스트

### 실행

```bash
swift test                                    # 전체 (macOS에서 가능)
swift test --filter PlaybackStateReducerTests # 특정 suite
./scripts/verify_kollus_packaging.sh          # SDK packaging 변경 시

# Example 단위 테스트 (ViewModel/Resolver 순수 로직)
xcodebuild test -workspace VideoPlayerExample.xcworkspace -scheme VideoPlayerExample \
    -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 15'
```

### 규칙 3가지

1. **Swift Testing** 사용 (`import Testing`, `@Test`, `#expect`) — XCTest 아님
2. iOS 전용 모듈(Skin/ShellSupport/엔진) 테스트는 `#if canImport(UIKit)` 가드 필수 — 테스트 타깃이 macOS에서도 컴파일되기 때문
3. 순수 로직(Reducer, SignalMapper)은 `Tests/VideoPlayerModuleTests/Core/`, `Kollus/`, `Native/`에. **새 상태 전이나 신호 매핑을 추가하면 반드시 여기에 테스트 추가**

### 패턴 1: 엔진 계약 공유 테스트

모든 엔진이 같은 계약을 지키는지 한 벌의 테스트로 검증합니다. 새 엔진을 만들면 factory만 추가하면 됩니다.

```swift
// Tests/VideoPlayerModuleTests/Support/AVPlayerContractFactory.swift
enum AVPlayerContractFactory: PlayerEngineAdapterContractTestable {
    static func makeTestAdapter() -> PlayerEngineAdapter { AVPlayerAdapter(player: AVPlayer()) }
    static var expectedCapabilities: EngineRuntimeTraits { .avPlayer }
}

@Suite("AVPlayerAdapter 엔진 계약", .enabled(if: AVPlayerContractFactory.isSupportedInCurrentEnvironment))
struct AVPlayerEngineContractTests {
    private typealias Contract = PlayerEngineContract<AVPlayerContractFactory>

    @Test("초기 상태는 idle이다")
    func initialStateIsIdle() async throws { try await Contract.initialStateIsIdle() }

    @Test("idle에서 stop 반복 호출이 crash하지 않는다")
    func stopFromIdleDoesNotCrash() async throws { try await Contract.stopFromIdleDoesNotCrash() }
}
```

### 패턴 2: Skin smoke 테스트

```swift
// Tests/VideoPlayerModuleTests/PlayerSkinSmokeTests.swift
#if canImport(UIKit)
@MainActor
@Suite("PlayerSkin smoke 테스트")
struct PlayerSkinSmokeTests {
    @Test("lock 상태에서는 재생/진행 조작을 숨기거나 비활성화")
    func lockedStateDisablesInteractiveControls() {
        let skin: PlayerSkin = AssembledPlayerSkin()
        skin.render(.initial.updating(isLoading: false, controlsVisible: true,
                                      isFullScreenMode: true, isLocked: true, layoutMode: .fullScreen))
        skin.view.layoutIfNeeded()

        let playButton = skin.view.descendant(accessibilityIdentifier: "videoPlayer.skin.playPauseButton")
        let progressSlider = skin.view.descendant(accessibilityIdentifier: "videoPlayer.skin.progressSlider") as? UIControl

        #expect(playButton?.isEffectivelyHidden == true)
        #expect(progressSlider?.isEnabled == false)
    }
}
#endif
```

## 작업 레시피

### 레시피 A: 새 재생 명령 추가

예: "구간 미리듣기" 같은 새 명령.

1. `Core/Domain/PlaybackCommand.swift`에 case 추가 → 모든 엔진의 `handle` exhaustive switch와
   Core의 `validateAgainstPolicy`가 컴파일 에러로 갱신 지점을 안내한다
2. 각 엔진(`AVPlayerAdapter`, `KollusPlayerAdapter`, `UnsupportedEnvironmentEngine`)의 `handle` switch에
   구현 또는 `PlayerError.unsupportedCommand` throw를 명시적으로 결정
3. 정책 검증이 필요하면 `Internal/PlayerCore.swift`의 `validateAgainstPolicy` switch에 분기 추가
4. 상태가 바뀌는 명령이면 `PlaybackStateInput`에 입력 추가 + reducer 케이스 + **`Tests/Core/`에 reducer 테스트**
5. 버튼 게이팅이 필요하면 `PlayerFeature`에 case 추가 — 각 엔진 `supports(_:)`/`allows(_:)`의
   exhaustive switch가 컴파일 에러로 나머지 갱신 지점을 안내한다
6. `PlayerEngineFeatureCommandSnapshotTests`에 supports↔handle 일치 기대값 갱신
7. Skin에 버튼이 필요하면 레시피 B로

### 레시피 B: Skin에 새 버튼 추가

1. `Skin/Blocks/`에 Block 클래스 생성 — [8편](08-skin.md)의 체크리스트 준수
2. 액션이 새 종류면 `PlayerSkinAction`에 case 추가
3. 상태 표시가 필요하면 `PlayerSkinState`에 필드 추가
4. 엔진 지원 여부로 노출이 갈리면 블록에서 `requiredFeatures` override —
   skin이 `apply(availableFeatures:)` 시점에 자동 게이팅 (조건 블록의 `view.isHidden`은
   skin 소유 — 블록이 직접 만지지 말 것)
5. Blueprint에 배치 (기본 Blueprint를 바꿀지, host 커스텀으로 둘지 판단)
6. `PlayerSkinSmokeTests`에 렌더/잠금 동작 추가
7. host의 `onAction` 라우팅에 분기 추가

### 레시피 C: Kollus SDK 새 delegate 콜백 연결

1. `KollusEngineSignal.swift`에 case 추가
2. `KollusDelegateBridge.swift`에서 raw 콜백 → signal yield
3. `Signal/KollusSignalMapper.swift`에서 분류 결정: 상태 입력? 이벤트? 무시?
4. 이벤트라면 `PlayerEvent`에 case 추가 (벤더 중립 이름으로!)
5. **`Tests/Kollus/`에 mapper 테스트 추가**
6. 실기기 검증 후 결과를 PR에 기록

### 레시피 D: Kollus SDK 버전 교체

```bash
# 1. Vendor/에 새 산출물 반영 (직접 수정 금지, 스크립트로)
./scripts/sync_kollus_vendor.sh        # (PallyCon이면 sync_pallycon_vendor.sh)
# 2. XCFramework 재생성
./scripts/rebuild_kollus_xcframework.sh
# 3. 검증
./scripts/verify_kollus_packaging.sh
swift test
# 4. checksum 갱신 + docs/kollus-sdk-packaging.md에 절차 기록
# 5. 실기기에서 재생/DRM/다운로드 확인 → PR에 결과 남기기
```

### 레시피 E: "재생이 안 돼요" 디버깅 순서

1. **어느 엔진인가?** — URL이면 Native, mediaKey면 Kollus
2. **에러가 어느 경로로 왔나?** — execute의 throw(명령 경로)인지 stateStream의 `.failed`(신호 경로)인지 ([9편](09-full-flow.md))
3. Kollus라면 **Example 앱 Observer 로그**부터 — bootstrap 실패? DRM resolve 실패? 어떤 signal까지 왔나?
4. `KollusEnvironment.validate()` 통과 여부 — 만료일/키가 가장 흔한 원인
5. 시뮬레이터에서 테스트 중이라면 — Kollus는 실기기 전용. `UnsupportedEnvironmentEngine` 안내가 떠야 정상
6. 다운로드 콘텐츠면 `validateOfflinePlayability()` — 라이선스 만료 여부
7. 재현되면 `KollusDiagnosticsSink`를 주입해 23종 신호를 시간순으로 기록

## 마치며 — 새 담당자에게

이 패키지에서 길을 잃었을 때의 나침반:

1. **타입을 따라가세요.** `PlaybackCommand`가 어디서 만들어져 어디서 소비되는지 따라가면 전체 구조가 보입니다.
2. **상태가 이상하면 reducer 테스트부터.** 상태를 만드는 곳은 reducer 한 곳뿐입니다.
3. **SDK가 의심되면 mapper와 bridge 사이를 보세요.** raw 콜백 → signal → output 변환 지점에 로그가 있습니다.
4. **경계를 지키세요.** Core에 UIKit을, 패키지에 서비스 용어를 들이지 마세요. 테스트가 막아주지만, 설계 의도를 이해하고 지키는 것이 더 좋습니다.

> [← 9편: 전체 플로우](09-full-flow.md) · [시리즈 목차](README.md)
