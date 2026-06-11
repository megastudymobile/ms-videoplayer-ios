# videoplayer-ios-ms 발표 스토리보드 v3

작성자: JunyoungJung  
작성일: 2026-06-11  
대상 파일: `docs/presentation/player-module-review-ios.html`

## 발표 목표

이 발표를 들은 팀원이 아래 다섯 질문에 바로 답할 수 있어야 한다.

1. **왜 모듈화하는가?**  
   여러 서비스가 플레이어를 다시 구현하고 있어 기능, 버그, UX, SDK 대응 비용이 반복되기 때문이다.

2. **이 모듈의 핵심은 무엇인가?**  
   Host 앱은 재생 의도와 상태만 다루고, Core가 상태를 소유하며, Engine adapter가 SDK 차이를 흡수하고, Skin은 조립 가능한 UI를 제공하는 것이다.

3. **이 모듈은 어떻게 동작하는가?**  
   `PlaybackCommand -> PlayerCore actor -> EngineAdapter -> PlayerEngineOutput -> Reducer -> PlaybackState` 단방향 흐름으로 동작한다.

4. **개발자는 이 모듈로 어떻게 개발하는가?**  
   Host는 engine module을 선택하고, policy와 skin blueprint를 주입하고, state stream을 구독해 화면을 렌더한다.

5. **미래에는 어떻게 확장할 수 있는가?**  
   새 SDK는 adapter로 추가하고, 서비스별 UI는 skin block/theme으로 확장하며, 기능 차이는 capability와 optional protocol로 흡수한다.

## 청중에게 남길 4개 그림

발표 후 머릿속에 아래 네 장면이 남아야 한다.

| 그림 | 의미 | 슬라이드 위치 |
| --- | --- | --- |
| 서비스별 중복 지도 | 왜 지금 공통 모듈이 필요한가 | 01-03 |
| Core / Engine / Skin 레이어 | 이 모듈의 핵심 구조는 무엇인가 | 04-07 |
| Command-State loop | 런타임이 어떻게 동작하는가 | 08-11 |
| Host integration recipe | 앞으로 어떻게 개발하고 확장하는가 | 12-20 |

## 5막 구성

### 1막. 왜 모듈화인가

핵심 문장:

> 지금 문제는 "플레이어가 없다"가 아니라, 여러 서비스가 같은 플레이어 문제를 반복해서 풀고 있다는 것입니다.

필수 시각 자료:

- 서비스별 플레이어 중복 구조
- 서비스별 중복 비용 맵
- 공통 모듈 재사용 구조

슬라이드:

1. 왜 지금 플레이어 모듈화인가
2. 현재 구조의 비용
3. 목표는 공통 재사용 모듈

### 2막. 이 모듈의 핵심은 무엇인가

핵심 문장:

> 이 모듈은 SDK wrapper가 아니라, Host와 SDK 사이에 놓이는 공통 재생 플랫폼입니다.

필수 시각 자료:

- wrapper vs module
- Core / Engine / Skin / Host 레이어
- POP 주입 구조

슬라이드:

4. 단순 SDK wrapper로는 부족하다
5. 모듈의 핵심 구조
6. SDK는 사서 쓰되, 의존은 줄인다
7. POP와 Host 주입

### 3막. 어떻게 동작하는가

핵심 문장:

> 화면은 command를 보내고 state를 구독합니다. 상태 전이는 SDK 콜백이 아니라 Core reducer가 결정합니다.

필수 시각 자료:

- runtime command/state flow
- product dependency graph
- reducer transition diagram
- capability gate

슬라이드:

8. Host가 알면 되는 것은 두 가지다
9. 런타임 흐름
10. product 경계가 SDK 경계다
11. 상태 소유권은 Core에 있다
12. 기능 차이는 capability로 처리한다

### 4막. 이 모듈로 어떻게 개발하는가

핵심 문장:

> 개발자는 engine을 고르고, policy를 주입하고, skin을 조립한 뒤, state를 렌더하면 됩니다.

필수 시각 자료:

- Native quickstart code
- Kollus quickstart code
- Skin slot layout
- Host integration checklist

슬라이드:

13. Native engine으로 개발하기
14. Kollus engine으로 개발하기
15. 서비스별 Skin 커스텀하기
16. Example app과 데모

### 5막. 어떻게 확장할 것인가

핵심 문장:

> 새 SDK, 새 서비스, 새 UI 요구가 와도 Host 화면 전체가 아니라 adapter, capability, skin block을 확장합니다.

필수 시각 자료:

- Future SDK adapter diagram
- Service-specific extension map
- Verification pyramid
- Rollout plan

슬라이드:

17. 미래 확장 시나리오
18. 검증 전략과 남은 한계
19. 오늘 결정할 것
20. 파일럿 계획과 마무리

## 최종 슬라이드 원고

### 01. 왜 지금 플레이어 모듈화인가

화면 문구:

- Title: 왜 지금 플레이어 모듈화인가
- Lead: 여러 서비스가 각자 다시 붙이던 플레이어를, 공통 재생 모듈로 재사용 가능하게 만들기 위해서입니다.
- Visual: 고등 / 유초등 / 해외사업부 / 신규 서비스가 같은 플레이어 요구를 반복 구현하는 그림

발표자 메모:

지금 문제는 단순히 "새 플레이어가 필요하다"가 아니다. 고등 서비스에는 오래된 플레이어 코드가 있고, 유초등과 해외사업부 등 여러 서비스는 각자 네이티브 플레이어를 다시 붙이고 있다. 재생, 제스처, 자막, 배속, DRM, 다운로드 같은 같은 문제를 서비스마다 다시 풀고 있다.

청중이 가져갈 문장:

> 플레이어는 서비스별로 다시 만들 영역이 아니라, 팀 공통 자산이 되어야 합니다.

### 02. 현재 구조의 비용

화면 문구:

Title: 반복 구현은 기능보다 유지보수 비용을 키웁니다.

| 반복되는 일 | 발생하는 비용 |
| --- | --- |
| 제스처, 자막, 배속 정책 | 서비스별로 다시 구현하고 다시 맞춤 |
| DRM, 다운로드, 오프라인 | 실기기 이슈를 서비스마다 따로 추적 |
| SDK 버전 대응 | 각 앱의 빌드, 링크, 런타임 영향 범위가 커짐 |
| UX 정렬 | 서비스마다 다른 플레이어 경험이 누적 |

발표자 메모:

서비스별로 빠르게 붙이는 방식은 초반에는 빠르다. 하지만 플레이어는 정책과 검증 비용이 큰 영역이다. 기능 하나를 고쳐도 여러 서비스가 같은 결정을 반복한다.

청중이 가져갈 문장:

> 중복 구현은 속도가 아니라 장기 비용으로 돌아옵니다.

### 03. 목표는 공통 재사용 모듈

화면 문구:

Title: 한 번 만들고, 여러 서비스가 재사용하는 구조로 바꿉니다.

Bullets:

- 공통 Core: 재생 명령, 상태, 정책 협상 소유
- 교체 가능한 Engine: AVPlayer, Kollus, 미래 SDK를 같은 계약 뒤에 배치
- 조립 가능한 Skin: 서비스별 UI를 block과 theme으로 구성
- Host 주입: 서비스 정책과 커스텀 UI를 밖에서 주입

발표자 메모:

공통 모듈은 모든 서비스가 똑같은 화면을 쓰자는 뜻이 아니다. 공통으로 가져가야 할 재생 상태와 엔진 계약은 모듈이 제공하고, 서비스별 차이는 주입 지점에서 해결한다.

청중이 가져갈 문장:

> 공통화할 것은 재생 구조이고, 달라질 것은 Host가 주입합니다.

### 04. 단순 SDK wrapper로는 부족하다

화면 문구:

Title: SDK 호출을 감싸는 wrapper만으로는 부족합니다.

| SDK wrapper | 공통 플레이어 모듈 |
| --- | --- |
| SDK API 모양을 따라감 | 우리 도메인의 command/state를 먼저 정의 |
| SDK 교체 시 Host까지 흔들림 | Engine adapter만 추가/교체 |
| 서비스별 차이가 옵션과 분기로 쌓임 | protocol, policy, blueprint로 주입 |
| 테스트가 SDK 동작에 묶임 | 상태 전이는 SDK 밖에서 테스트 |

발표자 메모:

wrapper는 SDK 호출 위치를 옮길 수는 있지만, SDK의 사고방식을 Host로 전달하기 쉽다. 우리가 필요한 것은 Kollus wrapper가 아니라 공통 재생 도메인이다.

청중이 가져갈 문장:

> wrapper는 SDK를 숨기고, module은 우리 팀의 재생 계약을 만듭니다.

### 05. 모듈의 핵심 구조

화면 문구:

Title: 이 모듈은 Core, Engine, Skin 세 축으로 동작합니다.

Diagram:

```text
Host App
  ├─ policy 주입
  ├─ skin block/theme 주입
  └─ command 전송 + state 렌더

VideoPlayerCore
  ├─ PlaybackCommand
  ├─ PlaybackState
  └─ PlaybackStateReducer

Engine Adapter
  ├─ AVPlayerAdapter
  ├─ KollusPlayerAdapter
  └─ FutureSDKAdapter

VideoPlayerSkin
  ├─ blueprint
  ├─ blocks
  └─ theme
```

발표자 메모:

Core는 상태와 명령을 소유한다. Engine은 실제 재생 방법을 번역한다. Skin은 UI를 조립한다. Host는 이 세 축을 조립하고, 서비스 정책을 주입한다.

청중이 가져갈 문장:

> Core는 상태, Engine은 방법, Skin은 화면 조립을 담당합니다.

### 06. SDK는 사서 쓰되, 의존은 줄인다

화면 문구:

Title: SDK는 사서 쓰는 게 맞습니다. 하지만 앱이 SDK에 묶이면 안 됩니다.

Bullets:

- VOD/DRM 인프라는 직접 구현보다 Kollus/PallyCon 같은 전문 SDK 사용이 효율적이다.
- 하지만 SDK 정책, 가격, 품질, 지원 범위는 언제든 바뀔 수 있다.
- 더 좋은 SDK가 생겼을 때 Host 화면을 다시 짜지 않으려면 SDK 의존을 adapter 안에 가둬야 한다.

발표자 메모:

블로그에서 정리한 결론은 SDK를 직접 만들자는 것이 아니다. 트랜스코딩, CDN, DRM, 라이선스 서버는 사는 게 맞다. 다만 사 온 SDK가 앱 구조 전체를 결정하게 두면 장기적으로 교체하기 어렵다.

청중이 가져갈 문장:

> SDK는 구매하되, 우리 앱의 구조는 우리가 소유해야 합니다.

### 07. POP와 Host 주입

화면 문구:

Title: 서비스별 차이는 protocol과 주입으로 해결합니다.

Bullets:

- 기능은 optional protocol로 나눈다.
- 엔진 지원 여부는 capability로 선언한다.
- 서비스 정책은 `PlayerFeaturePolicy`로 주입한다.
- UI 차이는 `PlayerSkinBlueprint`와 block/theme으로 주입한다.

발표자 메모:

상속 기반으로 거대한 플레이어를 만들면 서비스별 분기가 계속 늘어난다. 대신 protocol과 주입 가능한 구성요소로 나누면, 고등/유초등/해외사업부가 각자 필요한 차이를 모듈 경계를 깨지 않고 넣을 수 있다.

청중이 가져갈 문장:

> 공통 모듈이지만, 서비스별 커스텀은 주입으로 열어둡니다.

### 08. Host가 알면 되는 것은 두 가지다

화면 문구:

Title: Host는 command를 보내고, state를 구독합니다.

```swift
try await module.core.execute(command: .play)
try await module.core.execute(command: .seek(to: time))

for await state in module.core.stateStream {
    render(state)
}
```

Takeaway:

Host는 SDK delegate, DRM callback, AVPlayer 상태 전이를 직접 소유하지 않는다.

발표자 메모:

Host 입장에서 API는 단순해야 한다. 재생 의도를 command로 보내고, 계산된 state를 받아 화면을 그린다. 이것이 여러 서비스가 재사용할 수 있는 가장 중요한 표면이다.

청중이 가져갈 문장:

> Host는 "무엇을 할지"만 말하고, "어떻게 재생할지"는 모듈이 처리합니다.

### 09. 런타임 흐름

화면 문구:

Title: 명령과 상태는 한 방향으로 흐릅니다.

Flow:

```text
Host/Skin
  -> PlaybackCommand
  -> PlayerCore actor
  -> EngineAdapter
  -> SDK callback
  -> PlayerEngineOutput
  -> PlaybackStateReducer
  -> PlaybackState
  -> Host/Skin render
```

발표자 메모:

SDK 콜백이 화면 상태를 직접 바꾸지 않는다. 모든 신호는 Core로 돌아오고 reducer가 상태를 결정한다. 그래서 디버깅할 때도 마지막 command와 마지막 state부터 보면 된다.

청중이 가져갈 문장:

> 단방향 흐름이 있어야 여러 SDK와 여러 UI를 안정적으로 붙일 수 있습니다.

### 10. product 경계가 SDK 경계다

화면 문구:

Title: SDK는 필요한 product 안에만 들어옵니다.

| product | 역할 | SDK 의존 |
| --- | --- | --- |
| VideoPlayerCore | 도메인, 상태, 계약 | 없음 |
| VideoPlayerEngineNative | URL/HLS 재생 | 없음 |
| VideoPlayerEngineKollus | Kollus DRM/다운로드 | Kollus/PallyCon |
| VideoPlayerSkin | 재사용 UI | 없음 |

발표자 메모:

Kollus/PallyCon은 앱 전체 의존성이 아니라 Kollus engine product의 구현 디테일이다. Native만 필요한 서비스나 화면은 vendor binary를 피할 수 있다.

청중이 가져갈 문장:

> SDK 격리는 말이 아니라 SPM product 경계로 강제합니다.

### 11. 상태 소유권은 Core에 있다

화면 문구:

Title: SDK 콜백은 신호일 뿐, 상태 결정은 Core가 합니다.

```text
SDK callback
  -> PlayerEngineOutput
  -> PlaybackStateInput
  -> reducer(currentState, input)
  -> next PlaybackState
```

발표자 메모:

SDK 콜백 순서는 우리가 통제할 수 없다. 늦은 buffering 콜백이 도착해도 finished 상태가 playing으로 되살아나면 안 된다. 그래서 상태 전이는 SDK 밖의 reducer가 소유한다.

청중이 가져갈 문장:

> SDK는 신호를 주고, 상태는 Core가 결정합니다.

### 12. 기능 차이는 capability로 처리한다

화면 문구:

Title: 모든 엔진이 모든 기능을 지원하지 않아도 됩니다.

```text
availableFeature = hostPolicy ∩ engineCapability ∩ optionalProtocolSupport
```

Bullets:

- 배속, 자막, 북마크, PiP, 다운로드는 엔진별 지원 범위가 다를 수 있다.
- 지원 가능한 기능만 Host/Skin에 노출한다.
- 미지원 기능은 눌러보고 실패하는 UX가 아니라 시작 시점에 게이트한다.

발표자 메모:

공통 모듈은 모든 서비스를 같은 기능으로 강제하지 않는다. 기능 차이를 명시적으로 표현하고, UI와 명령 표면에서 안전하게 처리한다.

청중이 가져갈 문장:

> 기능 차이는 분기가 아니라 capability로 관리합니다.

### 13. Native engine으로 개발하기

화면 문구:

Title: 일반 URL/HLS는 Native engine으로 조립합니다.

```swift
let module = await PlayerModuleWiring.makeModule(
    engine: AVPlayerAdapter(),
    engineCapabilities: AVPlayerAdapter.capabilities
)

try await module.core.start(source: .url(videoURL), policy: .default)
try await module.core.execute(command: .play)
```

발표자 메모:

Native engine은 vendor SDK 없이 일반 URL/HLS를 재생하는 경로다. 미리보기, 광고, DRM 없는 영상처럼 가벼운 화면에 쓸 수 있다.

청중이 가져갈 문장:

> SDK가 필요 없는 화면은 Native engine만으로 가볍게 붙일 수 있습니다.

### 14. Kollus engine으로 개발하기

화면 문구:

Title: Kollus도 조립 지점만 다릅니다.

```swift
let environment = KollusEnvironment(
    applicationKey: key,
    applicationBundleID: bundleID,
    applicationExpireDate: expireDate,
    storagePath: storagePath,
    drm: drmConfiguration
)
try environment.validate()

let factory = KollusPlayerModuleFactory(environment: environment)
let module = await factory.makeModule()

try await module.core.start(
    source: .mediaKey(mediaContentKey),
    policy: .default
)
```

발표자 메모:

Kollus 환경과 DRM 설정은 조립 지점에서만 등장한다. 화면 코드는 KollusSDK나 PallyCon 타입을 알 필요가 없다.

청중이 가져갈 문장:

> Kollus는 engine 안에 있고, Host는 같은 command/state 표면을 씁니다.

### 15. 서비스별 Skin 커스텀하기

화면 문구:

Title: 공통 플레이어지만, 서비스별 UI는 바꿀 수 있어야 합니다.

```swift
let blueprint = PlayerSkinBlueprint(
    blocks: [
        .topCenter: [{ TitleBlock() }],
        .centerControls: [{ CenterPlaybackControlsBlock() }],
        .bottomBar: [{ ProgressBarBlock() }],
        .floatingBottomTrailing: [{ ExtraFloatingBlock() }]
    ],
    visibleSlots: [
        .fullScreen: [.topCenter, .centerControls, .bottomBar, .floatingBottomTrailing]
    ]
)

let skin = AssembledPlayerSkin(
    blueprint: blueprint,
    theme: serviceTheme
)
```

발표자 메모:

Skin은 단순 UI 패키지가 아니라 서비스별 차이를 흡수하는 조립 표면이다. 고등, 유초등, 해외사업부가 같은 Core를 쓰면서 다른 UI를 가질 수 있다.

청중이 가져갈 문장:

> 공통 Core 위에 서비스별 Skin을 조립합니다.

### 16. Example app과 데모

화면 문구:

Title: 데모는 기능이 아니라 구조를 보여줍니다.

| 데모 | 확인할 구조 |
| --- | --- |
| HLS 재생 | Native engine과 공통 state |
| Kollus DRM | SDK 격리와 engine 교체 |
| 다운로드/오프라인 | DRM 사전 검증과 download center |
| Skin 제스처 | 서비스별 UI 조립 가능성 |

발표자 메모:

데모의 목적은 기능 자랑이 아니다. 앞에서 말한 모듈 경계가 실제로 작동하는지 보여주는 것이다.

청중이 가져갈 문장:

> Example app은 이 모듈을 서비스에서 어떻게 조립할지 보여주는 레퍼런스입니다.

### 17. 미래 확장 시나리오

화면 문구:

Title: 앞으로의 확장은 Host 전체 수정이 아니라 경계 확장입니다.

| 미래 요구 | 확장 지점 |
| --- | --- |
| 더 좋은 VOD SDK 도입 | 새 `EngineAdapter` 추가 |
| 서비스별 UI 요구 | Skin block/theme 추가 |
| 기능 지원 차이 | capability와 optional protocol 추가 |
| 다운로드 정책 변경 | DownloadCenter contract 확장 |
| 해외 서비스 요구 | Host policy와 localization 주입 |

발표자 메모:

이 슬라이드는 상상하게 만드는 장이다. 새 SDK가 와도, 새 서비스가 와도, Host 화면 전체를 다시 짜는 대신 정해진 확장 지점에 추가한다.

청중이 가져갈 문장:

> 미래 변화는 adapter, capability, skin block으로 흡수합니다.

### 18. 검증 전략과 남은 한계

화면 문구:

Title: 공통 모듈로 쓰려면 검증 경계도 분리되어야 합니다.

| 검증 | 방법 |
| --- | --- |
| 상태 전이 | reducer pure test |
| SDK 이벤트 매핑 | signal mapper test |
| SDK 침투 방지 | boundary test |
| 통합 패턴 | Example app |
| DRM/다운로드 | 실기기 QA |

남은 한계:

- Kollus PiP는 현재 capability로 열지 않는다.
- DRM/다운로드/백그라운드 오디오는 실기기 QA가 필요하다.
- 고등 서비스 기준 UX와 새 Skin의 제스처/HUD 정렬이 더 필요하다.

발표자 메모:

여러 서비스가 재사용하려면 "내 화면에서 한 번 됐다"로는 부족하다. 자동화할 것과 실기기로 확인할 것을 분리해야 한다.

청중이 가져갈 문장:

> 공통 모듈은 코드 경계뿐 아니라 검증 경계도 가져야 합니다.

### 19. 오늘 결정할 것

화면 문구:

Title: 오늘 결정하고 싶은 것은 세 가지입니다.

| 결정 | 추천안 |
| --- | --- |
| 공통 모듈 방향 | Core/Engine/Skin 구조 승인 |
| 파일럿 범위 | host 1개 화면부터 feature flag로 적용 |
| 정책 차이 | 기존 UX 기준으로 정렬하되 Host override 허용 |

발표자 메모:

이 회의에서 모든 구현 디테일을 닫을 필요는 없다. 구조 방향, 파일럿 범위, 정책 차이 처리 방식만 결정하면 다음 단계로 갈 수 있다.

청중이 가져갈 문장:

> 오늘은 구조 승인과 파일럿 착수를 결정하는 자리입니다.

### 20. 파일럿 계획과 마무리

화면 문구:

Title: 전면 교체가 아니라, 되돌릴 수 있는 파일럿으로 시작합니다.

Flow:

1. Example app에서 통합 패턴 확인
2. host 1개 화면에 feature flag 적용
3. 실기기 QA와 기존 UX 정렬
4. 결과 리뷰 후 유초등/해외사업부 확장 가능성 검토

Closing:

여러 서비스가 다시 만들지 않도록, 공통 플레이어 모듈로 가겠습니다.

발표자 메모:

마지막은 처음 문제로 돌아와야 한다. 기술적으로 멋있기 위해서가 아니라, 여러 서비스가 같은 플레이어를 다시 만들지 않도록 하기 위한 구조다.

청중이 가져갈 문장:

> 이 모듈은 플레이어를 팀 공통 자산으로 만들기 위한 첫 단계입니다.
