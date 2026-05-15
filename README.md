# VideoPlayerModule

`videoplayer-ios-ms`는 SmartLearning iOS 앱이 공유하는 **재생 엔진 추상화 코어 패키지**다.
하나의 도메인/유즈케이스/상태 모델 위에서 `AVPlayer`와 `Kollus`(그 외 vendor SDK)를 자유롭게 교체하면서도,
앱 측 Shell UI는 동일한 인터페이스 하나만 알면 되도록 설계되어 있다.

---

## 목차

- [설계 원리](#설계-원리)
- [아키텍처](#아키텍처)
- [폴더 구조](#폴더-구조)
- [사용 방법](#사용-방법)
- [Kollus SDK 운영 규칙](#kollus-sdk-운영-규칙)
- [테스트](#테스트)

---

## 설계 원리

이 패키지는 다섯 가지 원칙 위에서 만들어졌다.

1. **엔진 교체 가능성 (Engine Replaceability)**
   재생 엔진은 `PlayerPlaybackEngine` actor 프로토콜 뒤에 숨는다.
   Shell, UseCase, `PlayerCore` 어느 쪽도 `AVPlayer`나 `KollusVideoView`를 직접 알지 못한다.
2. **단방향 상태 흐름 (Unidirectional State Flow)**
   명령은 `PlaybackCommand` 하나로 들어오고, 상태는 `PlaybackState` AsyncStream으로만 나간다.
   "엔진이 자기 마음대로 UI를 그리는" 경로는 의도적으로 차단했다.
3. **Capability 기반 기능 게이팅 (Capability Gating)**
   `EngineCapabilities`(OptionSet)와 보조 프로토콜(`PlayerPlaybackRateEngine`, `PlayerSubtitleEngine`, …)을 조합한다.
   Shell이 요청한 기능을 엔진이 지원하지 못하면 `PlayerFeaturePolicy`가 안전한 값으로 자동 downgrade되고, `PolicyDowngradeReason` 이벤트가 발행된다.
4. **Vendor 격리 (Vendor Isolation)**
   Kollus / PallyCon 같은 외부 SDK는 별도 SPM product(`VideoPlayerEngineKollus`)로 분리되어, Kollus가 필요 없는 화면은 해당 바이너리를 링크하지도 않는다.
5. **Swift Concurrency First**
   모든 엔진은 `actor`로 격리되고, 상태/이벤트는 `AsyncStream`으로 흐른다. main thread reentrancy를 차단하고 데이터 레이스를 컴파일 타임에 막는다.

> 한 줄 요약: **"공용 코어가 명령을 받고 상태를 발행한다. 엔진은 그저 plug-in이다."**

---

## 아키텍처

### 1) 레이어 구조

```mermaid
graph TB
    subgraph App["SmartLearning App (consumer)"]
        Shell["Player Shell UI<br/>(UIKit / SwiftUI ViewModel)"]
    end

    subgraph SS["VideoPlayerShellSupport"]
        Wiring["PlayerModuleWiring<br/>· makeModule(...)"]
        Surface["PlayerRenderSurface"]
        Binder["PlayerStateBinder"]
        Lifecycle["PlayerLifecycleCoordinator"]
        Audio["PlayerAudioSessionManager"]
    end

    subgraph Core["VideoPlayerCore (도메인 + 유즈케이스 + 코어)"]
        UC["UseCases<br/>· StartPlaybackUseCase<br/>· ControlPlaybackUseCase<br/>· ObservePlaybackStateUseCase"]
        PC["PlayerCore (actor)<br/>· 상태머신<br/>· 정책 다운그레이드"]
        Domain["Domain<br/>PlaybackCommand · PlaybackState<br/>PlaybackSource · PlayerEvent<br/>PlayerFeaturePolicy · EngineCapabilities"]
        EA["PlayerEngineAdapter<br/>(typealias of PlayerPlaybackEngine)"]
    end

    subgraph Engines["엔진 어댑터 (선택적 SPM product)"]
        Native["VideoPlayerEngineNative<br/>AVPlayerAdapter"]
        Kollus["VideoPlayerEngineKollus<br/>KollusPlayerAdapter<br/>+ KollusPlayerModuleFactory"]
    end

    subgraph Vendor["외부 SDK (binaryTarget)"]
        KSDK["KollusSDK.xcframework"]
        Pally["PallyConFPSSDK.xcframework"]
    end

    Shell -->|"PlaybackCommand"| Wiring
    Wiring --> UC
    UC --> PC
    PC -->|"protocol calls"| EA
    EA -.implements.- Native
    EA -.implements.- Kollus
    Kollus --> KSDK
    Kollus --> Pally
    PC -->|"PlaybackState / PlayerEvent (AsyncStream)"| Binder
    Binder --> Shell
    Surface --> Native
    Surface --> Kollus

    classDef app fill:#e3f2fd,stroke:#1565c0;
    classDef ss fill:#fff3e0,stroke:#ef6c00;
    classDef core fill:#e8f5e9,stroke:#2e7d32;
    classDef eng fill:#fce4ec,stroke:#ad1457;
    classDef vendor fill:#eceff1,stroke:#455a64;
    class Shell app;
    class Wiring,Surface,Binder,Lifecycle,Audio ss;
    class UC,PC,Domain,EA core;
    class Native,Kollus eng;
    class KSDK,Pally vendor;
```

### 2) SPM Product 의존 그래프

```mermaid
graph LR
    A[VideoPlayerCore] --> B[VideoPlayerShellSupport]
    B --> C[VideoPlayerEngineNative]
    B --> D[VideoPlayerEngineKollus]
    D --> K[VideoPlayerKollusBinary]
    D --> P[VideoPlayerPallyConBinary]
    C --> U[VideoPlayerModule<br/>umbrella]
    D --> U
    A --> U
    B --> U

    classDef core fill:#e8f5e9,stroke:#2e7d32;
    classDef bin fill:#eceff1,stroke:#455a64;
    classDef umb fill:#ede7f6,stroke:#5e35b1;
    class A,B core;
    class C,D core;
    class K,P bin;
    class U umb;
```

소비자는 필요한 만큼만 가져간다.

| 필요한 것 | 연결할 product |
| --- | --- |
| AVPlayer만 | `VideoPlayerCore` + `VideoPlayerShellSupport` + `VideoPlayerEngineNative` |
| Kollus 추가 | 위 + `VideoPlayerEngineKollus` |
| 다 묶어서 한 번에 | `VideoPlayerModule` (umbrella) |

### 3) 명령/상태 시퀀스

```mermaid
sequenceDiagram
    autonumber
    participant Shell as Player Shell
    participant UC as ControlPlaybackUseCase
    participant Core as PlayerCore (actor)
    participant Engine as Engine Adapter (actor)

    Shell->>UC: execute(.load(source))
    UC->>Core: start(source, policy)
    Core->>Core: applyEffectivePolicy()<br/>(unsupported → downgrade)
    Core-->>Shell: PlaybackState(.preparing) via AsyncStream
    Core->>Engine: prepare(source)
    Engine-->>Core: stateDidChange / timeDidChange (AsyncStream)
    Core-->>Shell: PlaybackState(.readyToPlay)
    Shell->>UC: execute(.play)
    UC->>Core: execute(.play)
    Core->>Engine: play()
    Engine-->>Core: stateDidChange(.playing)
    Core-->>Shell: PlaybackState(.playing)
```

### 4) 상태 머신

```mermaid
stateDiagram-v2
    [*] --> idle
    idle --> preparing: .load(source)
    preparing --> readyToPlay: engine prepared
    preparing --> failed: prepare error
    readyToPlay --> playing: .play
    playing --> paused: .pause
    paused --> playing: .play
    playing --> buffering: engine buffering
    buffering --> playing: buffer ready
    playing --> finished: didFinish
    playing --> failed: didFail
    failed --> idle: .stop
    finished --> idle: .stop
    paused --> idle: .stop
    readyToPlay --> idle: .stop
```

### 5) Capability 매트릭스

엔진은 `EngineCapabilities` + 보조 프로토콜 채택 여부로 자기가 무엇을 할 수 있는지 표현한다.
`PlayerCore`는 명령을 받을 때마다 이 능력을 검사하고, 없으면 `PlayerError.engineError`를 던지거나 `PlayerFeaturePolicy`를 downgrade한다.

```mermaid
graph LR
    EA[PlayerPlaybackEngine<br/>play / pause / seek / prepare] --> Rate[PlayerPlaybackRateEngine<br/>setPlaybackRate]
    EA --> Sub[PlayerSubtitleEngine<br/>setSubtitleVisible<br/>selectSubtitleTrack<br/>setCaptionFontSize]
    EA --> BM[PlayerBookmarkEngine<br/>addBookmark]
    EA --> Disp[PlayerDisplayEngine<br/>= Lock + Scaling]

    classDef base fill:#e3f2fd,stroke:#1565c0;
    classDef opt fill:#fff8e1,stroke:#f9a825;
    class EA base;
    class Rate,Sub,BM,Disp opt;
```

| Capability flag | 의미 |
| --- | --- |
| `.continuesWithoutSurface` | render surface가 detach돼도 백그라운드 재생 가능 |
| `.seamlessSurfaceSwap` | 재생 중 surface 교체 시 끊김 없음 |
| `.nativePiP` | OS 네이티브 Picture-in-Picture 지원 |

`allowsBackgroundPlayback` 정책이 켜져 있는데 엔진이 `.continuesWithoutSurface`가 없으면
→ 자동으로 정책을 끄고 `.policyDowngraded(.missingContinuesWithoutSurface)` 이벤트를 발행한다.

---

## 폴더 구조

```text
videoplayer-ios-ms/
├── Package.swift                       # SPM 매니페스트 (5개 product 정의)
├── README.md
├── CHANGELOG.md
│
├── Sources/
│   ├── VideoPlayerModuleExports/
│   │   └── VideoPlayerModule.swift     # umbrella product
│   │
│   └── VideoPlayerModule/              # 본체 (SPM target들이 path를 공유)
│       ├── Core/                       # ── VideoPlayerCore ──
│       │   ├── Domain/                 #    값타입 도메인 모델 (Sendable)
│       │   │   ├── PlaybackCommand.swift
│       │   │   ├── PlaybackSource.swift
│       │   │   ├── PlaybackState.swift
│       │   │   ├── PlayerCapabilities.swift
│       │   │   ├── PlayerError.swift
│       │   │   ├── PlayerEvent.swift
│       │   │   ├── PlayerFeaturePolicy.swift
│       │   │   ├── PlayerFeatureSet.swift
│       │   │   ├── PlayerIdentity.swift
│       │   │   └── PlayerStateSnapshot.swift
│       │   ├── Internal/
│       │   │   └── PlayerCore.swift    # actor 상태머신
│       │   └── UseCase/                # @MainActor 유즈케이스 (Shell 경계)
│       │       ├── StartPlaybackUseCase.swift
│       │       ├── ControlPlaybackUseCase.swift
│       │       └── ObservePlaybackStateUseCase.swift
│       │
│       ├── Engine/
│       │   ├── PlayerEngineAdapter.swift   # 엔진 추상 프로토콜
│       │   ├── Native/
│       │   │   └── AVPlayerAdapter.swift   # VideoPlayerEngineNative
│       │   └── Kollus/
│       │       ├── KollusPlayerAdapter.swift        # VideoPlayerEngineKollus
│       │       └── KollusPlayerModuleFactory.swift  # 1-line wiring helper
│       │
│       └── ShellSupport/               # ── VideoPlayerShellSupport ──
│           ├── PlayerAudioSessionManager.swift
│           ├── PlayerError+NSError.swift
│           ├── PlayerLifecycleCoordinator.swift
│           ├── PlayerModuleConfiguration.swift
│           ├── PlayerModuleWiring.swift   # 모든 조립의 진입점
│           ├── PlayerRenderBindingEngine.swift
│           ├── PlayerRenderSurface.swift
│           └── PlayerStateBinder.swift
│
├── Tests/
│   └── VideoPlayerModuleTests/
│       └── Support/                    # 가짜 엔진, 가짜 surface 등
│
├── Binaries/                           # SPM binaryTarget 입력 (파생 산출물)
│   ├── KollusSDK.xcframework
│   └── PallyConFPSSDK.xcframework
│
├── Vendor/                             # source-of-truth (직접 수정 금지)
│   ├── KollusSDK/                      # 원본 SDK drop
│   └── PallyConFPSSDK.framework
│
├── Packaging/
│   └── Kollus/Stub/                    # simulator slice 생성용 stub SPM 패키지
│
├── scripts/                            # vendor sync + xcframework rebuild
│   ├── sync_kollus_vendor.sh
│   ├── sync_pallycon_vendor.sh
│   ├── rebuild_kollus_xcframework.sh
│   ├── rebuild_pallycon_xcframework.sh
│   ├── package_kollus_xcframework.sh
│   ├── verify_kollus_packaging.sh
│   └── generate_kollus_k2_stub.py
│
└── docs/
    └── kollus-sdk-packaging.md
```

---

## 사용 방법

### 1) SwiftPM 의존성 추가

`Package.swift` 또는 Xcode의 *Add Package Dependencies…*로 이 레포를 추가한다.

```swift
.package(url: "git@gitlab.com:megastudy-mobile/videoplayer-ios-ms.git", branch: "main"),

// target 의존성
.product(name: "VideoPlayerCore",          package: "videoplayer-ios-ms"),
.product(name: "VideoPlayerShellSupport",  package: "videoplayer-ios-ms"),
.product(name: "VideoPlayerEngineNative",  package: "videoplayer-ios-ms"),
.product(name: "VideoPlayerEngineKollus",  package: "videoplayer-ios-ms"), // 필요 시
```

### 2) 가장 짧은 사용 예 (Native, AVPlayer)

```swift
import VideoPlayerCore
import VideoPlayerShellSupport
import VideoPlayerEngineNative

@MainActor
final class LectureViewModel {
    private var module: PlayerModule?

    func bootstrap() async {
        let engine = AVPlayerAdapter()
        module = await PlayerModuleWiring.makeModule(
            engine: engine,
            engineCapabilities: AVPlayerAdapter.capabilities
        )

        // 상태 구독
        Task { [weak self] in
            guard let stream = await self?.module?.core.stateStream else { return }
            for await state in stream {
                self?.render(state)
            }
        }
    }

    func play(_ url: URL) async throws {
        try await module?.startPlaybackUseCase
            .execute(source: .url(url), policy: .default)
    }

    func pause() async throws {
        try await module?.controlPlaybackUseCase
            .execute(command: .pause)
    }
}
```

### 3) Kollus 엔진 사용

```swift
import VideoPlayerEngineKollus

let module = await KollusPlayerModuleFactory().makeModule()
try await module.startPlaybackUseCase.execute(
    source: .kollus(mediaContentKey: "MCK-..."),
    policy: .default
)
```

`KollusPlayerModuleFactory`는 `PlayerModuleWiring`을 감싼 1-line helper다.
custom 엔진/캡퍼빌리티 주입이 필요하면 `engineFactory:`, `engineCapabilities:`로 갈아끼울 수 있다.

### 4) Render Surface 부착

```swift
final class PlayerSurfaceView: UIView, PlayerRenderSurface {
    var containerView: UIView { self }
    func engineDidAttach()  { /* AVPlayerLayer 등 부착 */ }
    func engineDidDetach()  { /* cleanup */ }
}
```

엔진 어댑터가 `PlayerRenderBindingEngine`을 채택하면 `PlayerStateBinder`가 surface 부착·교체·해제를 lifecycle에 맞춰 관리한다.

### 5) 명령/이벤트 한눈에 보기

| 영역 | 타입 |
| --- | --- |
| 입력 (Shell → Core) | `PlaybackCommand`: `.load`, `.play`, `.pause`, `.seek`, `.seekWithOrigin`, `.setPlaybackRate`, `.setSkipInterval`, `.setSubtitleVisible`, `.selectSubtitleTrack`, `.setCaptionFontSize`, `.addBookmark`, `.setDisplayLocked`, `.setDisplayScaled`, `.toggleDisplayScaling`, `.stop` |
| 출력 (Core → Shell) | `PlaybackState` (AsyncStream) · `PlayerEvent`(`.stateDidChange` / `.timeDidChange` / `.bufferingDidChange` / `.didFinish` / `.didFail` / `.policyDowngraded`) |
| 정책 | `PlayerFeaturePolicy(allowsBackgroundPlayback, maxPlaybackRate, allowsAutoplay, skipInterval)` |

---

## Kollus SDK 운영 규칙

- 이 레포에서 관리하는 **source-of-truth**는 `Vendor/KollusSDK`, `Vendor/PallyConFPSSDK.framework`다.
- `Binaries/*.xcframework`는 **파생 산출물**이다. 직접 수정하지 않는다.
- `Packaging/Kollus/Stub/`은 simulator slice 생성용 로컬 stub 패키지이고,
  `Packaging/Kollus/Stub/Sources/KollusSDK/include/KollusSDK`는 `Vendor/KollusSDK/include/KollusSDK`를 가리키는 shared symlink다.
- 소비자(SmartLearning)는 `KollusSDKBinary` / `PallyConFPSSDK`를 직접 import하지 않고
  `KollusPlayerModuleFactory` 같은 public API만 사용한다.

```mermaid
flowchart LR
    Drop[새 vendor drop] -->|sync_*_vendor.sh| Vendor[Vendor/]
    Vendor -->|rebuild_*_xcframework.sh| Bin[Binaries/*.xcframework]
    Bin -->|SPM binaryTarget| Eng[VideoPlayerEngineKollus]
    Vendor -. symlink .- Stub[Packaging/Kollus/Stub]
    Stub --> Bin
    Bin -. verify .-> V[verify_kollus_packaging.sh]
```

**재생성 (표준 절차):**

```bash
./scripts/rebuild_kollus_xcframework.sh
./scripts/rebuild_pallycon_xcframework.sh
./scripts/verify_kollus_packaging.sh
```

**새 vendor drop 반영:**

```bash
./scripts/sync_kollus_vendor.sh   /path/to/KollusSDK
./scripts/sync_pallycon_vendor.sh /path/to/PallyConFPSSDK.framework
```

---

## 테스트

```bash
swift test
```

`Tests/VideoPlayerModuleTests`는 가짜 엔진(`Support/`)을 주입해 `PlayerCore`의 상태 전이, 정책 downgrade, capability 미지원 시 에러 매핑을 검증한다. 새 명령/이벤트를 추가하면 동일한 패턴으로 fake engine만 확장하면 된다.

---

## 의도적으로 제외한 범위

- SmartLearning 고등 전용 Player Shell UI
- 앱 composition / bridge 계층 (Coordinator, FactoryDependencyContainer)
- 분석/로깅/리모트컨피그 정책 결정 → Shell이 정책 객체로 주입
