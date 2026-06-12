# 엔진 계약 단순화 검토 — ability 캐스팅 → 명령 통과형

작성: JunyoungJung, 2026-06-12 · 상태: **D안 구현 완료** (2026-06-12) · 채택안: D (명령 통과형)

## 배경 — 현 구조의 비대칭

명령은 이미 단방향 enum으로 흐른다.

```text
Shell ──PlaybackCommand(enum)──▶ PlayerCore ──[enum을 풀어 타입 메서드로 재변환]──▶ ability protocol 12개 ──▶ 엔진
엔진 ──outputStream(단일 경로)──▶ reducer ──▶ PlaybackState
```

`PlaybackCommand`에는 자막·북마크·배속·디스플레이 명령이 전부 들어 있는데, PlayerCore가 switch(PlayerCore.swift:173)에서 이를 풀어 `engine as? any EngineSubtitleAbility` 같은 캐스팅 + 타입 메서드 호출로 **한 번 더 번역**한다. ability protocol 12개, PlayerCore per-feature 메서드 11개, `PlayerFeature` 캐스팅 매핑 12곳이 전부 이 중간 번역층의 유지비다.

### 컴파일 강제 사각지대

| 시나리오 | 현재 | 결과 |
|---|---|---|
| 새 `PlayerFeature` case 추가 | exhaustive switch 컴파일 에러 | ✅ 강제됨 |
| 새 ability protocol 추가 후 `PlayerFeature` case 누락 | 아무 에러 없음 | ❌ 협상에서 영구 누락 |
| 새 SDK 어댑터가 ability 채택 누락 | 아무 에러 없음 | ❌ 버튼만 조용히 사라짐 |

새 엔진 작성자에게 "전체 기능 목록을 보고 하나씩 지원 여부를 결정하라"고 강제하는 장치가 없다.

## 후보 비교

| 안 | 구조 | 개념 수 | 새 기능 추가 시 컴파일 강제 | 평가 |
|---|---|---|---|---|
| A. 현행 | protocol 채택 + `is`/`as?` 캐스팅 | protocol 12 + enum 2 | 부분 — 새 SDK 경로 무방비 | 이중 번역층 유지비 큼 |
| B. EngineAbilitySet | 명시적 슬롯 struct 선언 | A + struct 1 | 전 경로 강제 | 부분 수술. 슬롯 보일러플레이트 |
| C. 광폭 protocol + default throw | 전 기능 메서드를 한 protocol에, 미지원은 기본 구현 throw | protocol 1 | **없음** — override 누락 무증상 | 겉만 단순. 탈락 |
| D. 명령 통과형 | 엔진 = `handle(command)` + `supports(feature)` | **protocol 1 + enum 2** | 전 경로 강제 (exhaustive switch ×2) | **권고** |

### B안 요약 (점진안)

엔진이 `EngineAbilitySet`(feature당 optional 슬롯, **init default 금지**) 구조체로 지원 기능을 자기 선언. 슬롯 타입이 ability protocol이라 미채택 `self`는 타입 에러 — 선언↔구현 drift 차단. 슬롯 추가 시 전 어댑터 init 호출부가 컴파일 에러로 결정 강제.

```swift
public struct EngineAbilitySet: Sendable {
    public let playbackRate: (any EnginePlaybackRateAbility)?
    public let subtitle: (any EngineSubtitleAbility)?
    // ... feature당 슬롯 1개, init에 default 값 금지
}

// 어댑터: 미지원 = 명시적 nil
public nonisolated var abilities: EngineAbilitySet {
    EngineAbilitySet(playbackRate: self, subtitle: self, displayLock: nil, ...)
}

// PlayerCore: as? 캐스팅 → 프로퍼티 접근
guard let rateEngine = engine.abilities.playbackRate else { throw ... }
```

장점: actor isolation 유지(슬롯이 `self`), 변경 범위 작음. 한계: ability protocol 12개와 이중 번역층은 그대로 — 근본 단순화가 아니다. **D로 갈 거면 B를 경유하지 말 것** (B의 struct는 D에서 전부 버려짐).

### B′안: B + KeyPath 접근 (검토 후 기각)

B의 `EngineAbilitySet`에 KeyPath 제네릭 접근을 얹어 Core guard 보일러플레이트를 줄이는 변형.

```swift
extension PlayerPlaybackEngine {
    /// 타입 안전 조회 — KeyPath가 슬롯과 반환 타입을 컴파일 타임에 묶는다.
    nonisolated func ability<A>(_ keyPath: KeyPath<EngineAbilitySet, A?>) -> A? {
        abilities[keyPath: keyPath]
    }
}

// PlayerCore — guard 11벌이 제네릭 한 곳으로
let rateEngine = try requireAbility(\.playbackRate, feature: .playbackRate)

// isSupported 일원화 — exhaustive switch로 feature→keypath 매핑
extension PlayerFeature {
    var abilityKeyPath: PartialKeyPath<EngineAbilitySet> {
        switch self {  // default 없음 — case 누락 컴파일 에러
        case .playbackRate: \.playbackRate
        // ...
        }
    }
}
```

선례는 풍부 — SwiftUI `EnvironmentValues`, Point-Free swift-dependencies가 같은 "optional 슬롯 struct + KeyPath subscript" 구조. 그러나 조사 결과 협상 용도로는 한계가 명확:

| 한계 | 근거 |
|---|---|
| **역방향 누락 못 잡음** — AbilitySet에 슬롯 추가 후 `PlayerFeature` case 누락 시 침묵 | struct 프로퍼티 ↔ enum case 동기화는 단방향(enum→switch)만 컴파일 강제 |
| `isSupported`의 nil 검사가 런타임 트릭 | `PartialKeyPath` 조회는 `Any` 반환 — `AnyOptional` protocol 캐스트 관용구 필요, 슬롯 타입 실수 시 조용히 오답 |
| 컴파일 타임 "미구현 강제" 메커니즘 부재 | swift-dependencies도 미등록 감지를 **런타임** `reportIssue`/test-failure로 해결 — Swift에 그런 KeyPath 장치가 없다는 방증 |
| 디버깅 불투명 | KeyPath description은 reflection 정보 있을 때만 유효 — release 빌드 로그에 못 쓴다(SE-0369). 로그엔 `PlayerFeature` case명을 찍어야 |
| Sendable 모서리 | 저장된 `PartialKeyPath`는 `& Sendable` 표기 필요 + Swift 6 잔여 버그(swiftlang/swift#84983) |

SwiftNIO `ChannelOption`(phantom-type 키)도 같은 교훈 — 타입 안전 키를 써도 "이 구현체가 이 키를 지원하는가"는 결국 런타임 질문이고, NIO는 미지원 옵션을 런타임 fail로 처리한다.

**결론: 기각.** KeyPath는 B의 guard 중복(11곳)을 줄이는 sugar일 뿐 강제력을 추가하지 않고, 런타임 트릭(AnyOptional)·디버깅 비용을 새로 들인다. D를 채택하면 슬롯 자체가 없어져 KeyPath가 설 자리가 없다.

## D안 상세 설계 (권고)

엔진 = **"명령 들어오고, 스트림 나간다"**. 새 개발자가 외울 계약: 메서드 2개 + 스트림 1개.

### 1. 엔진 계약

```swift
public protocol PlayerPlaybackEngine: Actor {
    nonisolated static var runtimeTraits: EngineRuntimeTraits { get }

    /// 엔진의 유일한 출력. 기존과 동일 — unbounded, 장수명, teardown에 finish().
    var outputStream: AsyncStream<PlayerEngineOutput> { get }

    /// 단일 명령 싱크. 구현체는 exhaustive switch로 전 case를 명시 처리한다 —
    /// 미지원 case는 `PlayerError.unsupportedCommand`를 throw.
    /// 새 명령 case 추가 시 모든 엔진이 컴파일 에러로 결정을 강제받는다.
    func handle(_ command: PlaybackCommand) async throws

    /// UI 버튼 노출용 가용 기능 선언. exhaustive switch 강제 — 엔진마다
    /// 전 feature에 대한 명시적 결정이 코드에 남는다.
    nonisolated func supports(_ feature: PlayerFeature) -> Bool
}
```

ability protocol 12개 삭제. `PlayerFeature.isSupported(by:)`의 캐스팅 12곳도 삭제 — `engine.supports(_:)` 직접 호출.

```swift
public extension PlayerFeature {
    static func available(for engine: any PlayerPlaybackEngine) -> Set<PlayerFeature> {
        Set(allCases.filter { engine.supports($0) })
    }
}
```

### 2. PlayerError 추가

```swift
public enum PlayerError: Error, Sendable {
    // ... 기존 case 유지
    /// 현재 엔진이 지원하지 않는 명령. supports(_:)가 false인 기능의 명령이 도달한 경우.
    case unsupportedCommand(String)
}
```

### 3. 엔진 구현 — KollusPlayerAdapter

기존 ability 메서드 구현은 **전부 private 메서드로 강등**해 그대로 보존. 바뀌는 건 진입점뿐.

```swift
public actor KollusPlayerAdapter: PlayerEngineAdapter {

    public func handle(_ command: PlaybackCommand) async throws {
        switch command {
        case .load(let source):
            try await prepareInternal(source: source)
        case .play:
            try await playInternal()
        case .pause:
            try await pauseInternal()
        case .seek(let time), .seekWithOrigin(let time, _):
            try await seekInternal(to: time)
        case .stop:
            try await stopInternal(reason: .userInitiated)
        case .setPlaybackRate(let rate):
            try await applyPlaybackRate(rate)
        case .setSubtitleVisible(let isVisible):
            try await applySubtitleVisible(isVisible)
        case .selectSubtitleTrack(let trackID):
            try await applySubtitleTrack(trackID)
        case .setCaptionFontSize(let size):
            try await applyCaptionFontSize(size)
        case .selectSubtitleFile(let url):
            try await applySubtitleFile(url)
        case .addBookmark(let time):
            try await addBookmarkInternal(at: time, title: nil)
        case .addBookmarkWithTitle(let time, let title):
            try await addBookmarkInternal(at: time, title: title)
        case .removeBookmark(let time):
            try await removeBookmarkInternal(at: time)
        case .setDisplayScaleMode(let mode):
            try await applyDisplayScaleMode(mode)
        case .setDisplayScaled(let isScaled):
            try await applyDisplayScaled(isScaled)
        case .toggleDisplayScaleMode:
            try await toggleDisplayScaleModeInternal()
        case .toggleDisplayScaling:
            try await toggleDisplayScalingInternal()
        case .scroll(let distance):
            try await scrollInternal(by: distance)
        case .stopScroll:
            try await stopScrollInternal()
        case .changeBandwidth(let bps):
            try await changeBandwidthInternal(bps)
        case .setDisplayLocked:
            throw PlayerError.unsupportedCommand("displayLock")
        case .setSkipInterval:
            // Core 정책 전용 — 엔진 도달 없음. Core가 자체 소비.
            assertionFailure("setSkipInterval은 Core에서 소비되어야 한다")
        }
    }

    public nonisolated func supports(_ feature: PlayerFeature) -> Bool {
        switch feature {
        case .playbackRate, .subtitles, .externalSubtitles,
             .bookmarks, .titledBookmarks, .scroll,
             .adaptiveStreaming, .displayScaling, .zoom, .seekPreview:
            return true
        case .displayLock, .pictureInPicture:
            return false
        }
    }
}
```

`handle`과 `supports`가 같은 파일에 인접 — 불일치가 리뷰에서 한눈에 보인다.

### 4. PlayerCore 축소

per-feature private 메서드 11개 + `as?` 캐스팅 전부 삭제. Core 책임은 셋으로 수렴: 정책 게이트, 상태 부기(command-origin/`stateAuthority`), 전달.

```swift
func send(_ command: PlaybackCommand) async throws {
    try validateAgainstPolicy(command)        // 정책 검증 switch 한 곳
    if consumeLocally(command) { return }     // setSkipInterval 등 Core 전용
    try await engine.handle(command)
    applyCommandOriginStateIfNeeded(command)  // runtimeTraits 기반 상태 확정 — 기존 로직 유지
}
```

```swift
// Before (per-feature 메서드 × 11)
private func setPlaybackRate(_ rate: Double) async throws {
    guard rate > 0 else { throw ... }
    guard currentPolicy.allowsPlaybackRate(rate) else { throw ... }
    guard let rateEngine = engine as? any EnginePlaybackRateAbility else { throw ... }
    try await rateEngine.setPlaybackRate(rate)
}

// After — 정책 검증만 switch 한 곳으로 모임
private func validateAgainstPolicy(_ command: PlaybackCommand) throws {
    switch command {
    case .setPlaybackRate(let rate):
        guard rate > 0 else { throw PlayerError.engineError("...") }
        guard currentPolicy.allowsPlaybackRate(rate) else { throw PlayerError.engineError("...") }
    // ... 정책이 있는 case만. default 없는 exhaustive switch
    }
}
```

### 5. 조회형 API — push 전환

ability에 섞여 있던 pull 조회는 outputStream으로 흡수한다. reducer 단방향 설계와 오히려 더 정합.

| 기존 pull API | 전환 |
|---|---|
| `currentBookmarks()` | 이미 bridge가 북마크 이벤트 발행 중 — outputStream 이벤트로 일원화 |
| `streamInfoList()` | prepare 완료 시점에 `PlayerEngineOutput`으로 1회 발행 |
| `currentContent()` | 동일 — 메타데이터 이벤트로 발행. `PlayerNowPlayingCoordinator`는 엔진 직조회 대신 스트림 구독 (이미 주입형 optional이라 전환 간단) |
| `isPiPActive` 등 토글 상태 | 상태 변화 이벤트로 발행 |

### 6. 잔존 예외 — 어느 안이든 불가피한 2개

```swift
/// 핀치 줌 동기 hot path. UIPinchGestureRecognizer가 non-Sendable이고
/// 매 이벤트 동기 적용이 필요해(actor hop 시 추적 끊김) enum 명령으로 표현 불가.
public protocol EngineSynchronousZoomAbility { ... }   // 유지

/// 시킹 스크럽 프리뷰. time → UIImage? 요청-응답이라 push로 못 바꾼다.
public protocol EngineSeekPreviewAbility: Actor { ... } // 유지
```

protocol 12개 → 2개. 이 둘은 "예외임"이 문서화된 채로 남는 게 정직한 구조다.

### 7. 강제력 시나리오

새 기능 추가 (예: `chapterNavigation`):

```text
1. PlaybackCommand에 .selectChapter(Int) case 추가
   → 모든 엔진 handle switch + Core validateAgainstPolicy switch 컴파일 에러
2. PlayerFeature에 .chapterNavigation case 추가
   → 모든 엔진 supports switch + PlayerFeaturePolicy.allows switch 컴파일 에러
→ 엔진·Core·정책 전 지점이 컴파일러 안내로 갱신. 누락 불가능.
```

새 SDK 도입:

```text
PlayerPlaybackEngine 채택 → handle/supports 구현 필수
→ 둘 다 default 없는 exhaustive switch → 전 명령·전 기능에 대한
  명시적 결정(구현 or throw/false)이 코드에 강제로 남는다.
```

### 8. 약점과 완화

| 약점 | 완화 |
|---|---|
| `supports() == true`인데 `handle`이 throw — drift가 런타임으로 | 같은 파일 인접 switch + 어댑터별 스냅샷 테스트(아래) |
| "이 엔진은 자막 지원" 타입 증명 상실 | 의도된 트레이드 — 타입 증명보다 단일 계약의 단순성 우선 |
| 마이그레이션 비용 최대 | 아래 단계별 플랜으로 분할 |

```swift
@Test("Kollus supports 선언과 handle 처리가 일치")
func kollusSupportsMatchesHandle() async {
    let engine = makeKollusAdapter()
    #expect(PlayerFeature.available(for: engine) == [
        .playbackRate, .subtitles, .externalSubtitles, .bookmarks,
        .titledBookmarks, .scroll, .adaptiveStreaming, .displayScaling,
        .zoom, .seekPreview,
    ])
    // supports == false인 feature의 명령은 unsupportedCommand throw 검증
    await #expect(throws: PlayerError.unsupportedCommand("displayLock")) {
        try await engine.handle(.setDisplayLocked(true))
    }
}
```

## 사례 연구 — 다른 플레이어들은 어떻게 풀었나

같은 문제(교체 가능 엔진 + 기능 협상)를 가진 OSS 조사 결과 (2026-06-12).

| 사례 | 발견/선언 | 미지원 호출 시 | 강제 장치 | 시사점 |
|---|---|---|---|---|
| **Media3 `Player.Commands`** | 단일 `Player` 인터페이스 + `isCommandAvailable(COMMAND_*)` / `getAvailableCommands()` + 변경 listener | 계약상 "호출 금지"(호출자 책임); 세션·`SimpleBasePlayer`는 무시 | `SimpleBasePlayer`: commands 선언 ↔ `handleXxx()` 구현이 짝 — 선언 없는 구현은 죽은 코드 | **D안의 원형** |
| ExoPlayer `RendererCapabilities` | `supportsFormat` → 다단계 비트필드 (`FORMAT_HANDLED`/`EXCEEDS_CAPABILITIES`/`UNSUPPORTED_DRM`...) | 트랙 선택 단계에서 배제 | 인터페이스 상속으로 컴파일 강제 | boolean 아닌 **graded** 응답. 단 이건 소스-포맷 협상 레이어 — 명령 가용성과 별개 메커니즘 |
| video.js Tech | `features*` boolean 플래그 + `canPlaySource` | UI 숨김 or **Core가 폴리필**(폴링으로 합성 이벤트) | 약함 — 기본값 있어 선언 누락 무증상 | "엔진이 신호 못 주면 Core가 메꾼다" — 우리 reducer/poller와 같은 철학 |
| Flutter video_player | 단일 추상 클래스, 사전 질의 API 거의 없음 | `UnimplementedError` 런타임 throw | 없음(의도적 — `extends` 강제로 호환 우선) | **반면교사**: supports 없는 throw-only는 사용자에게 그대로 터짐(flutter#122738) |
| react-native-video | 없음 — 문서 테이블뿐 | 조용한 무시 | 없음 | 선언 없는 구조의 반례 |

핵심 관찰 3가지:

1. **성숙한 플레이어는 "명령 가용성"과 "소스-포맷 협상"을 별개 레이어로 분리** (Media3 Commands ↔ RendererCapabilities). 우리도 `supports(feature)`와 `PlaybackSource` 엔진 라우팅(host factory 책임)을 한 메커니즘에 섞지 않는다 — 현 구조 유지.
2. 미지원 처리 전략 중 **사전 질의(supports) + 명시적 throw 병행이 최선** — Media3(질의+무시)와 Flutter(throw만)의 장점 결합. D안의 `supports` + `unsupportedCommand` throw가 정확히 이 조합이고 "엔진 명령은 모두 async throws" 원칙과 정합.
3. Media3 `SimpleBasePlayer`의 선언↔구현 짝 묶기가 강제 장치의 모범. D안은 Swift enum exhaustive switch로 이를 더 강하게 달성(새 case → 모든 엔진 컴파일 에러 — Media3엔 없는 강제). **단 Media3는 가용성이 동적**(`onAvailableCommandsChanged` — 광고/라이브/Cast 중 기능 변화)이라는 점이 한 수 위. 우리는 당장 정적 `supports`로 충분하나, 추후 필요 시 outputStream에 feature-set 변경 이벤트를 추가하는 확장 경로가 열려 있다.

Swift 진영 참고: protocol 분할 + `as?` 캐스팅 발견 자체는 정당한 Swift 관용구(커뮤니티 합의). 단 "기능 집합을 런타임에 질의해야 하는" 도메인에서는 명시적 capability 값이 낫다는 게 플랫폼 사례들의 일관된 방향 — 캐스팅의 본질 한계는 "호출자가 가능한 조합을 컴파일 타임에 모른다"는 점(Jesse Squires).

출처: [Media3 Player.java](https://github.com/androidx/media/blob/release/libraries/common/src/main/java/androidx/media3/common/Player.java) · [Player Interface 가이드](https://developer.android.com/media/media3/session/player) · [RendererCapabilities](https://exoplayer.dev/doc/reference/com/google/android/exoplayer2/RendererCapabilities.html) · [video.js tech.js](https://github.com/videojs/video.js/blob/main/src/js/tech/tech.js) · [video_player platform interface](https://github.com/flutter/packages/blob/main/packages/video_player/video_player_platform_interface/lib/video_player_platform_interface.dart) · [Emerge: protocol conformance 비용](https://www.emergetools.com/blog/posts/SwiftProtocolConformance)

## 마이그레이션 플랜

1. **조회 push 전환** — bookmarks/streamInfo/metadata를 outputStream 이벤트로. ability와 무관하게 단독 가치, 선행 가능
2. **`handle`/`supports` 추가** — 기존 ability 채택과 병존. 엔진 내부에서 handle → 기존 메서드 위임
3. **PlayerCore 전환** — per-feature 메서드를 `validateAgainstPolicy` + `engine.handle` 통과로 교체. 스냅샷 테스트 추가
4. **ability protocol 삭제** — sync zoom·seekPreview 2개만 잔존. `PlayerFeature.isSupported` 캐스팅 제거
5. **문서 갱신** — `docs/HANDOVER/05-engine-contract.md`, `01-overview.md`

각 단계가 독립 커밋/PR 가능 — 2~3단계 사이에서도 빌드·테스트 그린 유지.

## 변경 범위 (구현 시)

- 수정:
  - `Sources/VideoPlayerCore/Contract/PlayerPlaybackEngine.swift` — `handle`/`supports`로 재정의
  - `Sources/VideoPlayerCore/Contract/EngineAbilities.swift` — 12개 → 2개(sync zoom, seek preview)
  - `Sources/VideoPlayerCore/Domain/PlayerError.swift` — `.unsupportedCommand` 추가
  - `Sources/VideoPlayerCore/Domain/PlayerFeature.swift` — `isSupported` 삭제, `available`은 `supports` 위임
  - `Sources/VideoPlayerCore/Internal/PlayerCore.swift` — per-feature 메서드 11개 삭제, 정책 switch 일원화
  - `Sources/VideoPlayerEngineKollus/KollusPlayerAdapter.swift` / `Sources/VideoPlayerEngineNative/AVPlayerAdapter.swift` / `Sources/VideoPlayerShellSupport/UnsupportedEnvironmentEngine.swift` — `handle`/`supports` 구현, 기존 메서드 private 강등
  - `Sources/VideoPlayerShellSupport/PlayerNowPlayingCoordinator.swift` — 직조회 → 스트림 구독
- 테스트: 어댑터별 supports/handle 일치 스냅샷, Core 정책 게이트 테스트 재배선
- 문서: HANDOVER 01·05편
