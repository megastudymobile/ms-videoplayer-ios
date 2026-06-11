# Flutter 연동 기술 검토 — 플레이어 모듈 크로스플랫폼 전략

- 작성자: JunyoungJung
- 작성일: 2026-06-11
- 상태: 기술 검토 (구현 전)
- 전제: 안드로이드 플레이어 모듈을 iOS(`videoplayer-ios-ms`)와 동일한 아키텍처(공통 상태 머신 + 교체 가능한 재생 엔진)로 신규 구축한다.

---

## 1. 결론 요약

**연동 가능. 현재 아키텍처를 수정하지 않고 "Flutter Shell"을 추가하는 방식으로 성립한다.**

근거:

1. 모듈 경계가 이미 Flutter platform channel 경계와 일치한다.
   - `PlaybackCommand` — 직렬화 가능한 payload만 가진 값 타입 enum → MethodChannel 메시지로 1:1 매핑
   - `PlaybackState` / `PlayerEvent` — `Equatable & Sendable` 값 타입 → EventChannel(또는 Pigeon FlutterApi) 스트림으로 전달
2. 상태 소유권이 네이티브 코어(`PlayerCore` + `PlaybackStateReducer`)에 있다. Flutter는 상태를 **구독·렌더링만** 하면 되므로 상태 머신을 Dart로 중복 구현할 필요가 없다.
3. 양 플랫폼이 동일 계약을 구현하면 Dart 측 API는 플랫폼 무관 단일 계약으로 수렴한다.

핵심 리스크는 4개이며(§9), 그중 선결 PoC가 필요한 것은 **안드로이드 DRM × 렌더링 방식 조합** 1건이다.

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
| 영상 렌더링 | 네이티브 (PlatformView) | DRM secure surface 제약 (§9.1) |
| 조작 UI(skin) | Flutter 위젯 | 양 플랫폼 UI 1벌 유지 (§8) |
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
│   │   ├── video_player_module_ios.podspec   # 또는 Package.swift (SPM 지원 시)
│   │   └── Classes/
│   │       ├── FlutterPlayerPlugin.swift     # Pigeon HostApi 구현
│   │       ├── FlutterPlayerInstance.swift   # viewId 1개 ↔ PlayerModule 1개
│   │       ├── FlutterPlayerViewFactory.swift
│   │       ├── FlutterPlayerRenderSurface.swift  # PlayerRenderSurface 구현
│   │       └── Messages/                     # 도메인 ↔ Pigeon 메시지 매퍼
│   │           ├── PlaybackCommandMapper.swift
│   │           ├── PlaybackStateMapper.swift
│   │           └── PlayerEventMapper.swift
│   └── pubspec.yaml
│       # iOS 네이티브 의존: videoplayer-ios-ms (SPM)
│       #   VideoPlayerCore / ShellSupport / EngineNative / EngineKollus
│
├── video_player_module_android/
│   ├── android/
│   │   └── src/main/kotlin/.../
│   │       ├── FlutterPlayerPlugin.kt
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

`PlaybackCommand`(21 케이스), `PlaybackState`, `PlayerEvent`를 Pigeon으로 표현한다. associated value가 있는 enum은 Pigeon sealed class로 매핑한다.

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
  late String code;       // PlayerError 분류 체계 매핑
  late String message;
  late bool isRecoverable;
}

class PlaybackSourceMessage {
  late String kind;       // 'url' | 'kollus' — 네이티브에서 PlaybackSource로 복원
  String? url;
  String? mediaContentKey;
  Map<String?, String?>? drmParameters;
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
  @async
  void create(int viewId);

  @async
  void start(int viewId, PlaybackSourceMessage source);

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
  void onEvent(int viewId, PlayerEventMessage event);
}
```

설계 결정:

- **명령은 `execute(viewId, command)` 단일 메서드.** 네이티브 `PlayerCore.execute(command:)`와 동형이라 명령이 추가돼도 API 표면이 늘지 않는다.
- **실패 전파:** 네이티브 엔진 명령이 전부 `async throws`이므로, Pigeon `@async` + `PlatformException`이 의미상 정확히 대응한다. `PlayerError` 분류 코드를 exception `code`에 싣는다.
- `PlayerEvent` 15개 케이스 중 Flutter UI에 필요한 것만 1차 매핑하고(자막, 북마크, 다음 강의, 외부 출력 등), 나머지는 필요 시 추가한다. 단 매핑하지 않은 케이스는 **명시적으로 drop 로그**를 남긴다.

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

### 5.2 인스턴스 관리 — viewId 1개 ↔ PlayerModule 1개

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

### 5.3 플러그인 — Pigeon HostApi 구현

```swift
final class FlutterPlayerPlugin: NSObject, FlutterPlugin, PlayerHostApi {
    private var instances: [Int64: FlutterPlayerInstance] = [:]
    private var eventsApi: PlayerEventsApi!

    func create(viewId: Int64, completion: @escaping (Result<Void, Error>) -> Void) {
        Task {
            let surface = /* viewFactory가 만들어 둔 surface 조회 */
            let environment = KollusEnvironment(/* host 설정 주입 */)
            let engine = KollusPlayerModuleFactory.makeEngine(environment: environment, surface: surface)
            let module = await PlayerModuleWiring.makeModule(
                engine: engine,
                engineRuntimeTraits: engine.runtimeTraits
            )
            instances[viewId] = FlutterPlayerInstance(
                module: module, surface: surface, events: eventsApi, viewId: viewId
            )
            completion(.success(()))
        }
    }

    func execute(viewId: Int64, command: PlaybackCommandMessage,
                 completion: @escaping (Result<Void, Error>) -> Void) {
        guard let instance = instances[viewId] else {
            completion(.failure(PigeonError(code: "instance_not_found", message: nil, details: nil)))
            return
        }
        Task {
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
    // start / dispose / availableFeatures 동일 패턴
}
```

스레딩 요점:

- `PlayerCore`는 actor — 플러그인의 `Task { try await core.execute(...) }` hop은 기존 UIKit shell과 동일한 사용 방식이다. 새 동시성 문제 없음.
- FlutterApi 콜백(네이티브→Dart)은 **메인 스레드에서만** 호출한다. `AsyncStream` 소비 루프에서 `MainActor.run`으로 감싼다.

---

## 6. Android 구현 (동일 아키텍처 가정)

iOS 계약을 Kotlin으로 대칭 구현한다. 핵심 차이는 동시성 프리미티브와 렌더링 방식뿐이다.

| 개념 | iOS | Android 대응 |
|---|---|---|
| `PlayerCore` (actor) | Swift actor | 단일 `CoroutineScope` + `Mutex`, 또는 `Channel` 직렬 소비 actor 패턴 |
| `AsyncStream<PlaybackState>` | — | `StateFlow<PlaybackState>` |
| `AsyncStream<PlayerEvent>` | — | `SharedFlow<PlayerEvent>` |
| `async throws` 명령 | — | `suspend fun` + 예외 |
| `PlayerRenderSurface` | UIView | `SurfaceView` 보유 클래스 (DRM 제약상 TextureView 불가, §9.1) |
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
        return FlutterPlayerRenderSurface(context) // 내부에 SurfaceView
    }
}
```

---

## 7. Dart 측 — Controller + View

```dart
// lib/src/controller.dart
class VideoPlayerController {
  VideoPlayerController._(this._viewId, this._host);

  final int _viewId;
  final PlayerHostApi _host;

  final _state = ValueNotifier<PlaybackState>(PlaybackState.idle);
  ValueListenable<PlaybackState> get state => _state;

  final _events = StreamController<PlayerEvent>.broadcast();
  Stream<PlayerEvent> get events => _events.stream;

  static Future<VideoPlayerController> create(int viewId) async {
    final host = PlayerHostApi();
    await host.create(viewId);
    final controller = VideoPlayerController._(viewId, host);
    _PlayerEventsRouter.register(viewId, controller); // FlutterApi 콜백 라우팅
    return controller;
  }

  Future<void> start(PlaybackSource source) => _host.start(_viewId, source.toMessage());
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
PlayerView(
  onCreated: (controller) async {
    await controller.start(PlaybackSource.kollus(mediaContentKey: key));
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

---

## 9. 리스크와 제약

### 9.1 DRM × 렌더링 방식 (안드로이드, 최대 리스크 — 선결 PoC 필수)

- Flutter `Texture` 방식은 영상 프레임을 외부 텍스처로 복사한다. **Widevine L1 secure decoder는 secure surface로의 직접 출력을 강제**하므로 Texture로 프레임을 뽑을 수 없다 (L3 강등 또는 검은 화면).
- 따라서 **Hybrid Composition PlatformView + SurfaceView** 조합이 유일한 경로다.
- 선결 확인: **Kollus Android SDK가 외부 제공 SurfaceView 렌더를 지원하는가.** SDK가 자체 뷰만 노출한다면 그 뷰를 PlatformView 컨테이너에 attach하는 방식으로 우회 가능한지까지 PoC로 검증.
- iOS는 `UiKitView`가 네이티브 뷰 계층을 그대로 올리므로 FairPlay 제약 없음.

### 9.2 PlatformView 성능

- 영상 1개 + 오버레이 UI 시나리오에서는 Hybrid Composition 비용 수용 가능 (video_player 계열 플러그인들의 검증된 경로).
- 스크롤 리스트 안에 플레이어 다수 배치는 비권장 — 정책으로 제한.

### 9.3 전체화면 / 회전 / PiP

- PlatformView 내부에서 네이티브 전체화면 전환(뷰 계층 재부모화)은 Flutter 합성과 충돌 위험.
- **전체화면은 Flutter 라우트 전환으로 처리**하고 동일 viewId의 PlatformView를 새 라우트에 재부착한다. 네이티브 모듈 입장에서는 surface 크기만 바뀐다.
- PiP·백그라운드 오디오·NowPlaying·잠금화면 제어는 네이티브 잔류(`PlayerNowPlayingCoordinator`, `PlayerAudioSessionManager` 재사용). Dart에는 enable/disable 토글과 상태 이벤트만 노출.

### 9.4 다운로드 / DRM 세션

- `KollusDownloadCenter`, `KollusSessionBootstrapper`는 UI 무관 — 별도 `DownloadHostApi` + 진행률 FlutterApi로 노출.
- 주의: iOS 백그라운드 URLSession과 안드로이드 WorkManager/Foreground Service의 생명주기 차이를 **Dart API가 흡수**해야 한다. "다운로드 요청 → 진행률 스트림 → 완료/실패 이벤트" 수준으로 추상화하고 플랫폼별 재시작·복구 시맨틱은 네이티브에 묻는다.
- 앱 재시작 후 다운로드 상태 복원 질의 API(`restoreDownloads()`) 필요.

### 9.5 메시지 계약 드리프트

- 네이티브 도메인 타입(예: `PlaybackCommand` 케이스 추가)과 Pigeon 정의가 어긋나는 것이 장기 유지보수의 주적.
- 완화책: ① Pigeon 정의를 platform_interface 패키지에 단일 보관, ② 네이티브 매퍼에 **exhaustive switch** 강제(Swift `switch`에 `default` 금지)로 케이스 추가 시 컴파일 에러 유도, ③ 매퍼 단위 테스트를 양 플랫폼에 추가.

---

## 10. 단계별 로드맵

| 단계 | 내용 | 산출물 |
|---|---|---|
| 0. PoC | Kollus Android SDK × SurfaceView × Hybrid Composition 검증. iOS UiKitView + 기존 모듈 재생 검증 | go / no-go 판정 |
| 1. 계약 | Pigeon 정의 작성 (`PlaybackCommand`/`State`/`Event`/`Source`/`Error`), 매퍼 + 매퍼 테스트 | platform_interface 패키지 |
| 2. iOS 플러그인 | §5 구현. example 앱에서 URL/HLS(AVPlayerAdapter) 재생 → Kollus 재생 순 | video_player_module_ios |
| 3. AOS 모듈 + 플러그인 | 안드로이드 플레이어 모듈 구축(별도 프로젝트) 후 §6 구현 | video_player_module_android |
| 4. Skin | `PlayerSkinState/Action` Dart 포팅, Flutter skin 위젯 | app-facing 패키지 |
| 5. 부가 기능 | 다운로드 채널, 전체화면, PiP, NowPlaying | — |

공수 중심은 (1) 계약·매퍼, (4) skin 재구현, (3) 안드로이드 모듈 신규 구축이다. iOS 쪽 모듈 자체는 수정 없이 래핑만으로 충분하다.

---

## 11. 참고

- 기존 모듈 계약: `Sources/VideoPlayerCore/Contract/ (PlayerPlaybackEngine.swift · EngineRuntimeTraits.swift · EngineAbilities.swift)`, `Sources/VideoPlayerCore/Domain/`
- Shell 조립 흐름: `Sources/VideoPlayerShellSupport/PlayerModuleWiring.swift`
- 렌더 표면 추상화: `Sources/VideoPlayerShellSupport/PlayerRenderSurface.swift`
- 인수인계 시리즈: `docs/HANDOVER/01-overview.md` ~ `10-example-tests-recipes.md`
