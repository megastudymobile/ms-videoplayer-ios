# Flutter 연동 기술 검토 — 플레이어 모듈 크로스플랫폼 전략

- 작성자: JunyoungJung
- 작성일: 2026-06-11 (1차 개정: 동일자 — 도메인 타입 정합성 수정, 생명주기·테스트·배포 전략 보강)
- 상태: 기술 검토 (구현 전)
- 전제: 안드로이드 플레이어 모듈을 iOS(`videoplayer-ios-ms`)와 동일한 아키텍처(공통 상태 머신 + 교체 가능한 재생 엔진)로 신규 구축한다.

---

## 1. 결론 요약

**연동 가능. 현재 아키텍처를 수정하지 않고 "Flutter Shell"을 추가하는 방식으로 성립한다.**

근거:

1. 모듈 경계가 이미 Flutter platform channel 경계와 일치한다.
   - `PlaybackCommand` — 직렬화 가능한 payload만 가진 값 타입 enum → MethodChannel 메시지로 1:1 매핑
   - `PlaybackState` / `PlayerEvent` — `Equatable & Sendable` 값 타입 → Pigeon FlutterApi 스트림으로 전달
2. 상태 소유권이 네이티브 코어(`PlayerCore` + `PlaybackStateReducer`)에 있다. Flutter는 상태를 **구독·렌더링만** 하면 되므로 상태 머신을 Dart로 중복 구현할 필요가 없다.
3. 양 플랫폼이 동일 계약을 구현하면 Dart 측 API는 플랫폼 무관 단일 계약으로 수렴한다.

핵심 리스크는 5개이며(§13), 그중 선결 PoC가 필요한 것은 **안드로이드 DRM × 렌더링 방식 조합** 1건이다.

---

## 2. 연동 모델 — "Flutter는 또 하나의 Shell"

기존 명령 흐름:

```
Shell → PlayerCore(actor) → PlayerPlaybackEngine → PlayerEngineOutput
      → PlaybackStateReducer → PlaybackState 스트림 → 화면
```

Flutter 연동 시 Shell 자리에 Flutter가 들어간다. 네이티브 코어·엔진·reducer는 그대로다.

```
┌────────────────────── Flutter (Dart) ──────────────────────┐
│  PlayerSkin 위젯 (조작 UI)        PlayerView (영상 영역)     │
│        │                              │                     │
│  VideoPlayerController            PlatformView              │
│        │ PlaybackCommand              │ viewId              │
└────────┼──────────────────────────────┼─────────────────────┘
         │ Pigeon HostApi (명령, async) │
         │ Pigeon FlutterApi (상태/이벤트 스트림)
┌────────▼──────────────────────────────▼─────────────────────┐
│                    네이티브 플러그인 레이어                    │
│  iOS:  FlutterPlayerPlugin ── PlayerModule(Core+Engine)     │
│        FlutterPlatformView ── PlayerRenderSurface 구현       │
│  AOS:  FlutterPlayerPlugin ── PlayerModule(Core+Engine)     │
│        PlatformView(Hybrid Composition) ── SurfaceView      │
└─────────────────────────────────────────────────────────────┘
```

설계 원칙:

| 책임 | 위치 | 이유 |
|---|---|---|
| 상태 머신(reducer), capability 협상, 정책 | 네이티브 코어 | 이미 구현·테스트 완료. 중복 구현은 상태 불일치 원인 |
| 영상 렌더링 | 네이티브 (PlatformView) | DRM secure surface 제약 (§13.1) |
| 조작 UI(skin), 자막 텍스트 렌더 | Flutter 위젯 | 양 플랫폼 UI 1벌 유지 (§8) |
| 다운로드/DRM 세션 | 네이티브 | SDK 종속. Dart는 진행률 구독·명령만 |
| 백그라운드 오디오, NowPlaying, PiP | 네이티브 | OS 통합 기능. Dart는 토글만 노출 |

---

## 3. 패키지 구성 — Federated Plugin

Flutter 표준 federated plugin 구조를 따른다. 기존 네이티브 모듈은 **무수정 의존**한다.

```
video_player_module/                      # 모노레포 루트 (또는 melos workspace)
├── video_player_module/                  # app-facing 패키지 (host 앱이 의존)
│   ├── lib/
│   │   ├── video_player_module.dart      # 공개 API re-export
│   │   └── src/
│   │       ├── domain/                   # Dart 도메인 타입 (Pigeon 메시지와 분리, §4)
│   │       ├── controller.dart           # VideoPlayerController
│   │       ├── player_view.dart          # PlatformView 위젯 래퍼
│   │       └── skin/                     # Flutter skin (PlayerSkinState/Action 포팅)
│   └── pubspec.yaml                      # platform_interface + iOS/AOS 구현 의존
│
├── video_player_module_platform_interface/
│   ├── lib/
│   │   └── src/
│   │       ├── platform_interface.dart   # 추상 계약
│   │       └── messages.g.dart           # Pigeon 생성 코드
│   ├── pigeons/
│   │   └── player_api.dart               # Pigeon 정의 (단일 진실 공급원)
│   └── pubspec.yaml
│
├── video_player_module_ios/
│   ├── ios/
│   │   ├── video_player_module_ios.podspec   # §11 배포 전략 참고
│   │   └── Classes/
│   │       ├── FlutterPlayerPlugin.swift     # Pigeon HostApi 구현
│   │       ├── FlutterPlayerInstanceRegistry.swift  # viewId ↔ surface/모듈 연결 (§5.2)
│   │       ├── FlutterPlayerInstance.swift   # viewId 1개 ↔ PlayerModule 1개
│   │       ├── FlutterPlayerViewFactory.swift
│   │       ├── FlutterPlayerRenderSurface.swift  # PlayerRenderSurface 구현
│   │       └── Messages/                     # 도메인 ↔ Pigeon 메시지 매퍼
│   │           ├── PlaybackCommandMapper.swift
│   │           ├── PlaybackStateMapper.swift
│   │           ├── PlayerEventMapper.swift
│   │           └── PlayerErrorMapper.swift
│   └── pubspec.yaml
│       # iOS 네이티브 의존: videoplayer-ios-ms
│       #   VideoPlayerCore / ShellSupport / EngineNative / EngineKollus
│
├── video_player_module_android/
│   ├── android/
│   │   └── src/main/kotlin/.../
│   │       ├── FlutterPlayerPlugin.kt
│   │       ├── FlutterPlayerInstanceRegistry.kt
│   │       ├── FlutterPlayerInstance.kt
│   │       ├── FlutterPlayerViewFactory.kt   # Hybrid Composition
│   │       ├── FlutterPlayerRenderSurface.kt # SurfaceView 보유
│   │       └── messages/                     # 매퍼 (iOS와 대칭)
│   └── pubspec.yaml
│       # AOS 네이티브 의존: 안드로이드 플레이어 모듈 (Gradle/Maven)
│
└── example/                              # 통합 검증용 Flutter 앱
```

요점:

- **Pigeon 정의 파일(`pigeons/player_api.dart`)이 크로스플랫폼 계약의 단일 진실 공급원.** Dart/Swift/Kotlin 코드가 여기서 생성된다.
- 네이티브 모듈(`videoplayer-ios-ms`, 안드로이드 대응 모듈)은 플러그인의 **의존성**일 뿐, 플러그인 코드가 모듈 내부로 들어가지 않는다. 기존 경계 규칙(Core는 SDK를 모른다, host는 SDK를 직접 import하지 않는다)이 그대로 유지된다.
- 플러그인 레이어의 책임은 셋뿐: ① 메시지 ↔ 도메인 타입 매핑, ② viewId ↔ `PlayerModule` 인스턴스 생명주기, ③ `AsyncStream` → FlutterApi 브리지.

---

## 4. 메시지 계약 — Pigeon 정의

`PlaybackCommand`(21 케이스), `PlaybackState`, `PlayerEvent`, `PlayerFeaturePolicy`를 Pigeon으로 표현한다. associated value가 있는 enum은 Pigeon sealed class로 매핑한다.

메시지 타입은 **실제 도메인 타입과 1:1 정합**을 유지한다. 아래 `PlaybackSourceMessage`는 `PlaybackSource`(`Kind.url | Kind.mediaKey` + `options`)와 동형이다 — 벤더명("kollus" 등)을 메시지 계약에 넣지 않는다. Core가 벤더를 모르는 기존 설계를 채널 계약에서도 유지하기 위함이다.

```dart
// pigeons/player_api.dart
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/src/messages.g.dart',
  swiftOut: '../video_player_module_ios/ios/Classes/Messages.g.swift',
  kotlinOut: '../video_player_module_android/android/src/main/kotlin/Messages.g.kt',
))

// ── 도메인 메시지 ──────────────────────────────────────────

enum PlaybackStatusMessage {
  idle, preparing, readyToPlay, playing, paused, buffering, finished, failed,
}

class PlaybackStateMessage {
  late PlaybackStatusMessage status;
  late double currentTime;
  late double duration;
  late bool isBuffering;
  late bool isLive;
  double? liveDuration;
  PlayerErrorMessage? error; // status == failed 일 때만
}

class PlayerErrorMessage {
  late String code;       // §4.1 에러 코드 표
  late String message;
}

/// PlaybackSource와 동형: kind(url|mediaKey) + options
class PlaybackSourceMessage {
  late String kind;       // 'url' | 'mediaKey'
  late String value;      // URL 문자열 또는 콘텐츠 키
  late Map<String?, String?> options; // 엔진별 부가 힌트 — 엔진은 모르는 키 무시
}

/// PlayerFeaturePolicy와 동형 — start 시 필수
class PlayerFeaturePolicyMessage {
  late bool allowsBackgroundPlayback;
  late double allowedPlaybackRates;
  late bool allowsAutoplay;
  late double skipInterval;
  late double nextEpisodeButtonLeadTime;
  late bool allowsSeekPreview;
}

// PlaybackCommand — associated value 케이스는 sealed class로
sealed class PlaybackCommandMessage {}

class PlayCommand extends PlaybackCommandMessage {}
class PauseCommand extends PlaybackCommandMessage {}
class StopCommand extends PlaybackCommandMessage {}

class SeekCommand extends PlaybackCommandMessage {
  late double position;
  String? origin; // PlayerSeekOrigin
}

class SetPlaybackRateCommand extends PlaybackCommandMessage {
  late double rate;
}

class SetSubtitleVisibleCommand extends PlaybackCommandMessage {
  late bool visible;
}

class AddBookmarkCommand extends PlaybackCommandMessage {
  late double position;
  String? title;
}
// ... 나머지 케이스 동일 패턴 (전체 21개 1:1 매핑)

// ── API ───────────────────────────────────────────────────

@HostApi() // Dart → 네이티브
abstract class PlayerHostApi {
  /// 앱 시작 시 1회. SDK bootstrap 설정 주입 (iOS: KollusEnvironment.validate() 결과를
  /// PlatformException으로 전파). PlatformView 생성 전에 호출되어야 한다.
  @async
  void initialize(Map<String?, String?> environment);

  @async
  void create(int viewId);

  /// PlayerCore.start(source:policy:)와 동형 — policy 필수.
  @async
  void start(int viewId, PlaybackSourceMessage source, PlayerFeaturePolicyMessage policy);

  /// 모든 명령의 단일 통로 — 네이티브 PlayerCore.execute(command:)와 동형.
  /// 실패는 PlatformException으로 전파 (네이티브 async throws와 의미 일치).
  @async
  void execute(int viewId, PlaybackCommandMessage command);

  @async
  void dispose(int viewId);

  PlayerFeatureAvailabilityMessage availableFeatures(int viewId);
}

@FlutterApi() // 네이티브 → Dart
abstract class PlayerEventsApi {
  void onStateChanged(int viewId, PlaybackStateMessage state);
  void onTimeChanged(int viewId, double currentTime, double duration); // 고빈도 — 분리 (§9.3)
  void onEvent(int viewId, PlayerEventMessage event);
}
```

설계 결정:

- **명령은 `execute(viewId, command)` 단일 메서드.** 네이티브 `PlayerCore.execute(command:)`와 동형이라 명령이 추가돼도 API 표면이 늘지 않는다.
- **`start`는 policy를 필수로 받는다.** 네이티브 시그니처가 `start(source:policy:)`이고 정책 협상(`applyEffectivePolicy` → `policyDowngraded` 이벤트)이 start 시점에 일어나기 때문. Dart 쪽에 기본값 제공은 controller 편의 API에서 한다.
- **`initialize`를 별도 메서드로 분리.** Kollus SDK bootstrap(`KollusEnvironment`)은 플레이어 인스턴스 생성보다 먼저 1회 수행돼야 하고, 설정 오류(`validate()` 실패)를 앱 시작 시점에 fail-fast로 드러내야 한다.
- **고빈도 시간 업데이트는 `onTimeChanged`로 분리.** `onEvent` 범용 경로에 섞으면 역직렬화 비용·로깅 노이즈 증가 (§9.3).
- `PlayerEvent` 15개 케이스 중 Flutter UI에 필요한 것만 1차 매핑하고(자막, 북마크, 다음 강의, 외부 출력 등), 나머지는 필요 시 추가한다. 단 매핑하지 않은 케이스는 **명시적으로 drop 로그**를 남긴다.

### 4.1 에러 코드 매핑

`PlayerError` 분류 체계를 채널 에러 코드로 고정한다. 양 플랫폼 매퍼가 같은 표를 구현한다.

| PlayerError 케이스 | 채널 code | Dart 측 처리 가이드 |
|---|---|---|
| `networkError` | `network` | 재시도 UI |
| `authenticationFailed` | `auth` | 재인증 유도 |
| `decodingError` | `decoding` | 비복구 — 오류 화면 |
| `engineError` | `engine` | 비복구 — 오류 화면 + 리포팅 |
| `licenseExpired` | `license_expired` | 라이선스 갱신 플로우 |
| `licenseRenewalRequired` | `license_renewal` | 백그라운드 갱신 후 재시도 |
| `storageFull` | `storage_full` | 저장 공간 안내 |
| `downloadConflict` | `download_conflict` | 재시도 (지연 후) |
| `contentNotFound` | `content_not_found` | 콘텐츠 오류 안내 |
| `deviceNotSupported` | `device_not_supported` | 기기 미지원 안내 |
| `unknown` | `unknown` | 일반 오류 |

---

## 5. iOS 구현

### 5.1 렌더 표면 — `FlutterPlatformView`가 곧 `PlayerRenderSurface`

기존 `PlayerRenderSurface` 추상화가 이미 "엔진은 UIView 하나만 받는다"로 설계돼 있어, Flutter PlatformView가 그 구현체가 되면 끝이다. 모듈 수정 불필요.

```swift
import Flutter
import UIKit
import VideoPlayerShellSupport

final class FlutterPlayerRenderSurface: NSObject, FlutterPlatformView, PlayerRenderSurface {
    let containerView = UIView()

    func view() -> UIView { containerView }

    func showUnsupportedEnvironment(message: String) {
        // 시뮬레이터 등 — 안내 라벨 부착 (UnsupportedEnvironmentEngine가 호출)
    }
}
```

### 5.2 viewId ↔ surface ↔ 모듈 연결 — Registry

PlatformView 생성(렌더 트리)과 `create(viewId)` 호출(로직)은 **서로 다른 경로로 도착**한다. viewFactory가 surface를 만들고, HostApi가 같은 viewId로 모듈을 조립한다. 둘을 잇는 registry가 필요하며, 도착 순서는 보장되지 않으므로 양방향 대기를 처리한다.

```swift
/// viewId 기준으로 surface(뷰 팩토리 산출)와 instance(HostApi 산출)를 결합.
/// Flutter 프레임워크가 PlatformView 생성 콜백과 채널 호출 순서를 보장하지 않으므로
/// 어느 쪽이 먼저 와도 동작해야 한다.
@MainActor
final class FlutterPlayerInstanceRegistry {
    static let shared = FlutterPlayerInstanceRegistry()

    private var surfaces: [Int64: FlutterPlayerRenderSurface] = [:]
    private var surfaceWaiters: [Int64: [CheckedContinuation<FlutterPlayerRenderSurface, Never>]] = [:]
    private var instances: [Int64: FlutterPlayerInstance] = [:]

    func registerSurface(_ surface: FlutterPlayerRenderSurface, viewId: Int64) {
        surfaces[viewId] = surface
        surfaceWaiters.removeValue(forKey: viewId)?.forEach { $0.resume(returning: surface) }
    }

    func awaitSurface(viewId: Int64) async -> FlutterPlayerRenderSurface {
        if let surface = surfaces[viewId] { return surface }
        return await withCheckedContinuation { continuation in
            surfaceWaiters[viewId, default: []].append(continuation)
        }
    }

    func register(_ instance: FlutterPlayerInstance, viewId: Int64) { instances[viewId] = instance }
    func instance(viewId: Int64) -> FlutterPlayerInstance? { instances[viewId] }

    func remove(viewId: Int64) -> FlutterPlayerInstance? {
        surfaces.removeValue(forKey: viewId)
        return instances.removeValue(forKey: viewId)
    }

    /// hot restart / 엔진 detach 시 전체 정리 (§9.2)
    func removeAll() -> [FlutterPlayerInstance] {
        surfaces.removeAll()
        defer { instances.removeAll() }
        return Array(instances.values)
    }
}
```

### 5.3 인스턴스 관리 — viewId 1개 ↔ PlayerModule 1개

```swift
import VideoPlayerCore
import VideoPlayerShellSupport
import VideoPlayerEngineKollus

final class FlutterPlayerInstance {
    let module: PlayerModule
    let surface: FlutterPlayerRenderSurface
    private var streamTasks: [Task<Void, Never>] = []

    init(module: PlayerModule, surface: FlutterPlayerRenderSurface, events: PlayerEventsApi, viewId: Int64) {
        self.module = module
        self.surface = surface

        // AsyncStream → FlutterApi 브리지. 채널 호출은 메인 스레드 필수.
        streamTasks.append(Task {
            for await state in module.core.stateStream {
                let message = PlaybackStateMapper.toMessage(state)
                await MainActor.run {
                    events.onStateChanged(viewId: viewId, state: message) { _ in }
                }
            }
        })
        streamTasks.append(Task {
            for await event in module.core.eventStream {
                // 고빈도 timeDidChange는 onTimeChanged로 분기 (§9.3)
                if case let .timeDidChange(currentTime, duration) = event {
                    await MainActor.run {
                        events.onTimeChanged(viewId: viewId, currentTime: currentTime, duration: duration) { _ in }
                    }
                    continue
                }
                guard let message = PlayerEventMapper.toMessage(event) else { continue }
                await MainActor.run {
                    events.onEvent(viewId: viewId, event: message) { _ in }
                }
            }
        })
    }

    func teardown() async {
        streamTasks.forEach { $0.cancel() }
        await module.core.dispose()
    }
}
```

### 5.4 플러그인 — Pigeon HostApi 구현

```swift
final class FlutterPlayerPlugin: NSObject, FlutterPlugin, PlayerHostApi {
    private var eventsApi: PlayerEventsApi!
    private var environment: KollusEnvironment?

    func initialize(environment config: [String: String],
                    completion: @escaping (Result<Void, Error>) -> Void) {
        do {
            let environment = try KollusEnvironment(configuration: config)
            try environment.validate()
            self.environment = environment
            completion(.success(()))
        } catch {
            completion(.failure(PigeonError(code: "environment_invalid",
                                            message: String(describing: error), details: nil)))
        }
    }

    func create(viewId: Int64, completion: @escaping (Result<Void, Error>) -> Void) {
        Task { @MainActor in
            guard let environment else {
                completion(.failure(PigeonError(code: "not_initialized", message: nil, details: nil)))
                return
            }
            let surface = await FlutterPlayerInstanceRegistry.shared.awaitSurface(viewId: viewId)
            // 엔진 팩토리 시그니처는 실제 KollusPlayerModuleFactory에 맞춰 조정
            let engine = KollusPlayerModuleFactory.makeEngine(environment: environment, surface: surface)
            let module = await PlayerModuleWiring.makeModule(
                engine: engine,
                engineRuntimeTraits: engine.runtimeTraits
            )
            let instance = FlutterPlayerInstance(
                module: module, surface: surface, events: eventsApi, viewId: viewId
            )
            FlutterPlayerInstanceRegistry.shared.register(instance, viewId: viewId)
            completion(.success(()))
        }
    }

    func start(viewId: Int64, source: PlaybackSourceMessage, policy: PlayerFeaturePolicyMessage,
               completion: @escaping (Result<Void, Error>) -> Void) {
        Task { @MainActor in
            guard let instance = FlutterPlayerInstanceRegistry.shared.instance(viewId: viewId) else {
                completion(.failure(PigeonError(code: "instance_not_found", message: nil, details: nil)))
                return
            }
            do {
                try await instance.module.core.start(
                    source: PlaybackSourceMapper.toDomain(source),
                    policy: PlayerFeaturePolicyMapper.toDomain(policy)
                )
                completion(.success(()))
            } catch let error as PlayerError {
                completion(.failure(PlayerErrorMapper.toPigeonError(error)))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func execute(viewId: Int64, command: PlaybackCommandMessage,
                 completion: @escaping (Result<Void, Error>) -> Void) {
        Task { @MainActor in
            guard let instance = FlutterPlayerInstanceRegistry.shared.instance(viewId: viewId) else {
                completion(.failure(PigeonError(code: "instance_not_found", message: nil, details: nil)))
                return
            }
            do {
                let domainCommand = try PlaybackCommandMapper.toDomain(command)
                try await instance.module.core.execute(command: domainCommand)
                completion(.success(()))
            } catch let error as PlayerError {
                completion(.failure(PlayerErrorMapper.toPigeonError(error)))
            } catch {
                completion(.failure(error))
            }
        }
    }
    // dispose / availableFeatures 동일 패턴
}
```

스레딩 요점:

- `PlayerCore`는 actor — 플러그인의 `Task { try await core.execute(...) }` hop은 기존 UIKit shell과 동일한 사용 방식이다. 새 동시성 문제 없음.
- FlutterApi 콜백(네이티브→Dart)은 **메인 스레드에서만** 호출한다. `AsyncStream` 소비 루프에서 `MainActor.run`으로 감싼다.
- registry는 `@MainActor` 격리 — 뷰 팩토리 콜백과 채널 핸들러 모두 메인 스레드 진입이므로 자연스럽다.

---

## 6. Android 구현 (동일 아키텍처 가정)

iOS 계약을 Kotlin으로 대칭 구현한다. 핵심 차이는 동시성 프리미티브와 렌더링 방식뿐이다.

| 개념 | iOS | Android 대응 |
|---|---|---|
| `PlayerCore` (actor) | Swift actor | 단일 `CoroutineScope` + `Mutex`, 또는 `Channel` 직렬 소비 actor 패턴 |
| `AsyncStream<PlaybackState>` | — | `StateFlow<PlaybackState>` |
| `AsyncStream<PlayerEvent>` | — | `SharedFlow<PlayerEvent>` |
| `async throws` 명령 | — | `suspend fun` + 예외 |
| `PlayerRenderSurface` | UIView | `SurfaceView` 보유 클래스 (DRM 제약상 TextureView 불가, §13.1) |
| `AVPlayerAdapter` | AVPlayer | `ExoPlayerAdapter` (Media3) |
| `KollusPlayerAdapter` | Kollus iOS SDK | Kollus Android SDK adapter |

```kotlin
class FlutterPlayerInstance(
    private val module: PlayerModule,
    private val eventsApi: PlayerEventsApi,
    private val viewId: Long,
    scope: CoroutineScope,
) {
    init {
        scope.launch {
            module.core.stateFlow.collect { state ->
                withContext(Dispatchers.Main) {
                    eventsApi.onStateChanged(viewId, state.toMessage()) {}
                }
            }
        }
    }
}
```

PlatformView는 **Hybrid Composition**(`initExpensiveAndroidView` / `PlatformViewLink`)을 사용한다. Virtual Display 방식은 SurfaceView와 조합 불가.

```kotlin
class FlutterPlayerViewFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val surface = FlutterPlayerRenderSurface(context) // 내부에 SurfaceView
        FlutterPlayerInstanceRegistry.registerSurface(surface, viewId.toLong())
        return surface
    }
}
```

---

## 7. Dart 측 — Controller + View

Dart 공개 API는 **Pigeon 메시지를 직접 노출하지 않는다.** `lib/src/domain/`의 Dart 도메인 타입(`PlaybackState`, `PlayerEvent`, `PlaybackSource`, `PlayerFeaturePolicy`)을 노출하고 controller 내부에서 메시지로 변환한다. Pigeon 재생성이 공개 API를 깨뜨리지 않게 하기 위함이다.

```dart
// lib/src/controller.dart
class VideoPlayerController {
  VideoPlayerController._(this._viewId, this._host);

  final int _viewId;
  final PlayerHostApi _host;

  final _state = ValueNotifier<PlaybackState>(PlaybackState.idle);
  ValueListenable<PlaybackState> get state => _state;

  /// 고빈도 시간 업데이트 — state와 분리해 progress bar만 리빌드 (§9.3)
  final _position = ValueNotifier<PlaybackPosition>(PlaybackPosition.zero);
  ValueListenable<PlaybackPosition> get position => _position;

  final _events = StreamController<PlayerEvent>.broadcast();
  Stream<PlayerEvent> get events => _events.stream;

  static Future<VideoPlayerController> create(int viewId) async {
    final host = PlayerHostApi();
    await host.create(viewId);
    final controller = VideoPlayerController._(viewId, host);
    _PlayerEventsRouter.register(viewId, controller); // FlutterApi 콜백 라우팅
    return controller;
  }

  Future<void> start(PlaybackSource source, {PlayerFeaturePolicy? policy}) =>
      _host.start(_viewId, source.toMessage(),
          (policy ?? PlayerFeaturePolicy.defaults).toMessage());

  Future<void> play() => _host.execute(_viewId, PlayCommand());
  Future<void> pause() => _host.execute(_viewId, PauseCommand());
  Future<void> seek(Duration position) =>
      _host.execute(_viewId, SeekCommand()..position = position.inMilliseconds / 1000.0);

  Future<void> dispose() async {
    await _host.dispose(_viewId);
    _events.close();
  }
}
```

```dart
// lib/src/player_view.dart
class PlayerView extends StatelessWidget {
  const PlayerView({super.key, required this.onCreated});
  final void Function(VideoPlayerController) onCreated;

  @override
  Widget build(BuildContext context) {
    const viewType = 'video_player_module/player_view';
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return UiKitView(
        viewType: viewType,
        onPlatformViewCreated: _handleCreated,
      );
    }
    // Android: Hybrid Composition
    return PlatformViewLink(
      viewType: viewType,
      surfaceFactory: (context, controller) => AndroidViewSurface(
        controller: controller as AndroidViewController,
        gestureRecognizers: const {},
        hitTestBehavior: PlatformViewHitTestBehavior.opaque,
      ),
      onCreatePlatformView: (params) =>
          PlatformViewsService.initExpensiveAndroidView(
            id: params.id,
            viewType: viewType,
            layoutDirection: TextDirection.ltr,
          )
            ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
            ..addOnPlatformViewCreatedListener((_) => _handleCreated(params.id))
            ..create(),
    );
  }

  Future<void> _handleCreated(int viewId) async {
    onCreated(await VideoPlayerController.create(viewId));
  }
}
```

사용 예 (host 앱):

```dart
// 앱 시작 시 1회
await VideoPlayerModule.initialize(environmentFromConfig());

// 화면
PlayerView(
  onCreated: (controller) async {
    await controller.start(PlaybackSource.mediaKey(contentKey));
    await controller.play();
  },
)
```

---

## 8. Skin 전략

`VideoPlayerSkin`은 UIKit 기반이라 Flutter에서 재사용 불가. 두 선택지:

| 전략 | 내용 | 장점 | 단점 |
|---|---|---|---|
| **(a) Flutter skin 재구현** (권장) | `PlayerSkinState` / `PlayerSkinAction` 계약을 Dart로 포팅, 위젯으로 구현 | UI 1벌로 양 플랫폼 커버. Flutter 디자인 시스템과 통합 | 초기 구현 공수. 네이티브 host 앱이 계속 쓴다면 네이티브 skin과 이중 유지 |
| (b) 네이티브 skin 통째 임베드 | skin 포함된 화면 전체를 PlatformView로 | 빠른 출시 | 플랫폼별 UI 2벌 유지. Flutter 제스처와 충돌. Flutter 위젯과 시각 이질감 |

(a) 채택 시 기존 설계 패턴이 그대로 이식된다:

- `PlayerSkinState` ← `PlaybackState` + `PlayerFeatureAvailability` 파생 (네이티브 `PlayerStateBinder` 역할을 Dart에서 수행)
- `PlayerSkinAction` → `PlaybackCommand` 변환 → `controller.execute(...)`
- `availableFeatures()`를 init 직후 1회 조회해 버튼 노출을 사전 결정 — 기존 `PlayerModule.availableFeatures` 흐름과 동형

자막 렌더링: `captionDidUpdate(text:isSecondary:)` 이벤트를 받아 **Flutter 오버레이로 렌더**한다. Hybrid Composition·UiKitView 모두 Flutter 위젯이 PlatformView 위에 합성되므로 가능하다. 네이티브 자막 렌더(영상 내 번인)와 달리 폰트 크기·스타일을 Flutter 디자인 시스템에서 제어할 수 있어 (a) 전략과 정합적이다.

---

## 9. 생명주기·성능

### 9.1 위젯 생명주기 ↔ 네이티브 인스턴스

| Flutter 이벤트 | 네이티브 처리 |
|---|---|
| `PlayerView` mount | viewFactory → surface 생성 → registry 등록 |
| `controller.create()` | surface 대기 결합 → `PlayerModule` 조립 |
| 위젯 dispose | `controller.dispose()` → `core.dispose()` → registry 제거 |
| 라우트 전환(전체화면) | 같은 viewId PlatformView 재부착 — 모듈은 surface 크기 변경만 인지 |

Dart 쪽에서 `dispose` 누락 시 네이티브 인스턴스가 누수된다. 보강 장치: PlatformView dispose 콜백(네이티브 `PlatformView.dispose()`)에서도 registry를 정리하는 **이중 안전망**을 둔다.

### 9.2 Hot restart / FlutterEngine detach

- **Hot restart(개발)**: Dart 상태는 초기화되지만 네이티브 인스턴스는 살아남는다 → 유령 재생(소리만 나는 플레이어) 발생. 플러그인의 `detachFromEngine`(AOS) / `detachFromEngineForRegistrar`(iOS)에서 `registry.removeAll()` → 전 인스턴스 `teardown()`을 호출한다.
- **앱 백그라운드 전환**: 기존 `PlayerLifecycleCoordinator`가 네이티브에서 처리하던 책임 그대로. Flutter `AppLifecycleState`에 의존하지 않고 **네이티브 생명주기 옵저버를 신뢰**한다(채널 왕복 지연·순서 비보장 회피). Dart는 결과로 발생하는 상태 변화를 stateStream으로 받기만 한다.

### 9.3 채널 트래픽 — 고빈도 이벤트

- `timeDidChange`는 엔진에 따라 초당 수 회~수십 회 발행된다. 대책:
  1. FlutterApi에서 `onTimeChanged` 전용 메서드로 분리 — 범용 `onEvent` 역직렬화·분기 비용 제거
  2. 네이티브 브리지에서 **200ms throttle** (progress bar 갱신에 충분, 채널 호출 5/s 상한)
  3. Dart에서 `position`을 `state`와 분리된 `ValueNotifier`로 노출 — 시간 갱신이 skin 전체 리빌드를 유발하지 않게
- `bufferingDidChange`, `videoFrameDidChange` 등 나머지는 저빈도라 범용 경로로 충분.

---

## 10. 크로스플랫폼 동작 일치 — 공유 테스트 벡터

"안드로이드를 동일 아키텍처로 구축"의 실제 위험은 구조가 아니라 **상태 전이 시맨틱의 미세한 불일치**다(예: buffering 중 seek, finished 후 play). 코드 공유 없이 동작 일치를 보장하는 장치:

1. **Reducer 테스트 벡터를 JSON으로 추출.** 기존 `PlaybackStateReducerTests`의 입력(`PlaybackStateInput` 시퀀스)·기대 출력(상태 시퀀스)을 JSON fixture로 정리한다.
2. 이 fixture를 platform_interface 패키지에 보관하고, **iOS·Android 양쪽 reducer 테스트가 같은 fixture를 로드해 검증**한다.
3. 새 상태 전이 추가 시 fixture에 케이스를 추가하면 양 플랫폼이 동시에 강제된다.

```json
{
  "name": "seek_while_buffering_keeps_buffering_status",
  "initial": { "status": "buffering", "currentTime": 10.0 },
  "inputs": [ { "type": "seekRequested", "position": 30.0 } ],
  "expected": [ { "status": "buffering", "currentTime": 30.0 } ]
}
```

매퍼 계층도 동일 전략: `PlaybackCommandMessage ↔ PlaybackCommand` 왕복(round-trip) fixture를 두고 양 플랫폼 매퍼 테스트가 공유한다.

추가 안전망:

- **exhaustive switch 강제** — Swift/Kotlin 매퍼에서 `default`/`else` 금지. 도메인에 케이스가 추가되면 매퍼가 컴파일 에러로 드러난다.
- Dart 단위 테스트: controller를 `PlayerHostApi` mock으로 검증 (Pigeon이 테스트용 인터페이스 생성).
- `example/` 앱에 `integration_test` — 채널 왕복 스모크 (URL 재생 → play → seek → 상태 수신 확인).

---

## 11. 배포·의존성 전략

### 11.1 iOS — binary XCFramework 전달 경로

Flutter iOS 플러그인의 네이티브 의존성 전달은 CocoaPods가 기본이고, Flutter 3.24+부터 SPM을 지원한다. 이 모듈은 Kollus/PallyCon **binary xcframework**(`Binaries/*.xcframework`)를 포함하므로 경로별 제약:

| 경로 | 방법 | 제약 |
|---|---|---|
| **SPM (권장)** | 플러그인 `Package.swift`가 `videoplayer-ios-ms`를 그대로 의존 | host 앱 Flutter 버전이 SPM 지원 빌드여야 함. 기존 패키지 무수정 |
| CocoaPods | podspec에서 `vendored_frameworks`로 xcframework 직접 지정 + 소스 파일 경로 매핑 | SPM 패키지 구조와 이중 기술. checksum 관리 이원화 — `verify_kollus_packaging.sh` 흐름과 충돌 위험 |

결정 사항: host 앱(Flutter)의 SPM 지원 여부를 먼저 확인하고, 가능하면 SPM 단일 경로로 간다. CocoaPods 병행이 불가피하면 podspec을 `Packaging/`+`scripts/` 재현 절차에 편입한다.

### 11.2 버전 호환성

- 플러그인(`video_player_module_ios`) ↔ 네이티브 모듈(`videoplayer-ios-ms`)을 **고정 버전 핀**으로 의존한다(`exact:`). 채널 계약은 컴파일 타임 검증이 없으므로 범위 의존은 금물.
- 계약 변경(Pigeon 정의 수정) 시 platform_interface 패키지 **major 버전 상승** — federated plugin 표준 규칙.
- 호환성 매트릭스를 platform_interface CHANGELOG에 기록: `platform_interface x.y ↔ ios plugin a.b ↔ videoplayer-ios-ms c.d`.

### 11.3 example 앱 = 통합 검증 게이트

기존 Tuist example 앱이 네이티브 검증을 담당하듯, Flutter `example/` 앱이 플러그인 검증 게이트가 된다. 실기기 QA 체크리스트(Kollus 재생/DRM/다운로드)를 `example-app-rebuild-plan.md`와 같은 형식으로 운영한다.

---

## 12. 점진 도입 전략 — 기존 네이티브 host 앱과의 공존

Flutter 전환은 전면 재작성이 아니라 점진 도입을 전제한다. 두 시나리오:

| 시나리오 | 구성 | 플레이어 모듈 영향 |
|---|---|---|
| **add-to-app** | 기존 네이티브 앱에 FlutterEngine 임베드, 일부 화면만 Flutter | 같은 앱 프로세스에서 네이티브 shell과 Flutter shell이 **모듈을 공유**. `KollusSessionBootstrapper`/`KollusDownloadCenter`가 이미 factory 공유 설계라 충돌 없음. 단 동시 재생 방지는 host 책임 |
| 신규 Flutter 앱 | 처음부터 Flutter | 플러그인만 의존. 가장 단순 |

add-to-app 시 주의: `initialize`(SDK bootstrap)가 네이티브 측에서 이미 수행됐다면 플러그인 `initialize`는 **멱등**이어야 한다. bootstrap 중복 호출을 플러그인에서 가드한다.

네이티브 skin(`VideoPlayerSkin`)과 Flutter skin이 공존하는 기간에는 `PlayerSkinState`/`PlayerSkinAction` 계약 변경 시 양쪽 동기화가 필요하다 — 계약 파일에 변경 시 체크리스트 주석을 남긴다.

---

## 13. 리스크와 제약

### 13.1 DRM × 렌더링 방식 (안드로이드, 최대 리스크 — 선결 PoC 필수)

- Flutter `Texture` 방식은 영상 프레임을 외부 텍스처로 복사한다. **Widevine L1 secure decoder는 secure surface로의 직접 출력을 강제**하므로 Texture로 프레임을 뽑을 수 없다 (L3 강등 또는 검은 화면).
- 따라서 **Hybrid Composition PlatformView + SurfaceView** 조합이 유일한 경로다.
- 선결 확인: **Kollus Android SDK가 외부 제공 SurfaceView 렌더를 지원하는가.** SDK가 자체 뷰만 노출한다면 그 뷰를 PlatformView 컨테이너에 attach하는 방식으로 우회 가능한지까지 PoC로 검증.
- iOS는 `UiKitView`가 네이티브 뷰 계층을 그대로 올리므로 FairPlay 제약 없음.

### 13.2 PlatformView 성능

- 영상 1개 + 오버레이 UI 시나리오에서는 Hybrid Composition 비용 수용 가능 (video_player 계열 플러그인들의 검증된 경로).
- 스크롤 리스트 안에 플레이어 다수 배치는 비권장 — 정책으로 제한.

### 13.3 전체화면 / 회전 / PiP

- PlatformView 내부에서 네이티브 전체화면 전환(뷰 계층 재부모화)은 Flutter 합성과 충돌 위험.
- **전체화면은 Flutter 라우트 전환으로 처리**하고 동일 viewId의 PlatformView를 새 라우트에 재부착한다. 네이티브 모듈 입장에서는 surface 크기만 바뀐다.
- PiP·백그라운드 오디오·NowPlaying·잠금화면 제어는 네이티브 잔류(`PlayerNowPlayingCoordinator`, `PlayerAudioSessionManager` 재사용). Dart에는 enable/disable 토글과 상태 이벤트만 노출.

### 13.4 다운로드 / DRM 세션

- `KollusDownloadCenter`, `KollusSessionBootstrapper`는 UI 무관 — 별도 `DownloadHostApi` + 진행률 FlutterApi로 노출.
- 주의: iOS 백그라운드 URLSession과 안드로이드 WorkManager/Foreground Service의 생명주기 차이를 **Dart API가 흡수**해야 한다. "다운로드 요청 → 진행률 스트림 → 완료/실패 이벤트" 수준으로 추상화하고 플랫폼별 재시작·복구 시맨틱은 네이티브에 묻는다.
- 앱 재시작 후 다운로드 상태 복원 질의 API(`restoreDownloads()`) 필요.

### 13.5 메시지 계약 드리프트

- 네이티브 도메인 타입(예: `PlaybackCommand` 케이스 추가)과 Pigeon 정의가 어긋나는 것이 장기 유지보수의 주적.
- 완화책은 §10·§11.2에 정리: 공유 테스트 벡터, exhaustive switch 강제, 고정 버전 핀, platform_interface major 버전 규칙.

---

## 14. 단계별 로드맵

| 단계 | 내용 | 산출물 / 게이트 |
|---|---|---|
| 0. PoC | ① Kollus Android SDK × SurfaceView × Hybrid Composition 검증 ② iOS UiKitView + 기존 모듈 재생 검증 ③ host 앱 Flutter SPM 지원 확인 (§11.1) | go / no-go 판정 |
| 1. 계약 | Pigeon 정의 (`Command`/`State`/`Event`/`Source`/`Policy`/`Error`), 매퍼 + 왕복 fixture 테스트, reducer 테스트 벡터 JSON 추출 (§10) | platform_interface 패키지 |
| 2. iOS 플러그인 | §5 구현 (registry, 생명주기 §9 포함). example 앱에서 URL/HLS(AVPlayerAdapter) 재생 → Kollus 재생 순 | video_player_module_ios + integration_test |
| 3. AOS 모듈 + 플러그인 | 안드로이드 플레이어 모듈 구축(별도 프로젝트, reducer는 공유 fixture로 검증) 후 §6 구현 | video_player_module_android |
| 4. Skin | `PlayerSkinState/Action` Dart 포팅, Flutter skin 위젯, 자막 오버레이 | app-facing 패키지 |
| 5. 부가 기능 | 다운로드 채널, 전체화면, PiP, NowPlaying | — |

공수 중심은 (1) 계약·매퍼·테스트 벡터, (4) skin 재구현, (3) 안드로이드 모듈 신규 구축이다. iOS 쪽 모듈 자체는 수정 없이 래핑만으로 충분하다.

---

## 15. 미결 사항 (구현 전 확정 필요)

| 항목 | 결정 필요 내용 | 관련 절 |
|---|---|---|
| Kollus Android SDK 렌더 방식 | SurfaceView 외부 주입 가능 여부 — PoC 결과로 확정 | §13.1 |
| host 앱 Flutter SPM 지원 | SPM 단일 경로 vs CocoaPods 병행 | §11.1 |
| `KollusEnvironment` 직렬화 범위 | `initialize` Map으로 전달할 키 목록과 민감 값 취급 (plist 직접 로드 vs 채널 전달) | §4 |
| 다운로드 API 범위 | 1차 출시에 다운로드 포함 여부 — 포함 시 `DownloadHostApi` 계약 별도 설계 | §13.4 |
| 동시 재생 정책 | viewId 다중 인스턴스 허용 범위 (단일 재생 강제 여부) | §12 |

---

## 16. 참고

- 기존 모듈 계약: `Sources/VideoPlayerCore/Contract/ (PlayerPlaybackEngine.swift · EngineRuntimeTraits.swift · EngineAbilities.swift)`, `Sources/VideoPlayerCore/Domain/`
- Shell 조립 흐름: `Sources/VideoPlayerShellSupport/PlayerModuleWiring.swift`
- 렌더 표면 추상화: `Sources/VideoPlayerShellSupport/PlayerRenderSurface.swift`
- 생명주기 처리: `Sources/VideoPlayerShellSupport/PlayerLifecycleCoordinator.swift`
- 인수인계 시리즈: `docs/HANDOVER/01-overview.md` ~ `10-example-tests-recipes.md`
