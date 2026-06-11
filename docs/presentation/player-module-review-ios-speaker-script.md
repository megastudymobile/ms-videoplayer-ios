# player-module-review-ios 발표 스크립트

작성자: JunyoungJung  
작성일: 2026-06-11  
대상 HTML: `docs/presentation/player-module-review-ios.html`  
목표 시간: 20-25분  

## 발표 흐름

이 발표는 기능 소개가 아니라 설득 흐름으로 진행한다.

1. 왜 지금 모듈화가 필요한지 납득시킨다.
2. 이 모듈이 단순 SDK wrapper가 아니라는 점을 설명한다.
3. Core, Engine, Skin 구조와 런타임 흐름을 머릿속에 그리게 한다.
4. 실제 개발자는 무엇을 조립하고 어떤 API를 쓰는지 보여준다.
5. 이 구조가 미래 SDK 교체와 서비스 확장에 어떻게 대응하는지 상상하게 만든다.

발표 톤은 "기술적으로 이렇게 만들었다"보다 "우리 팀이 반복해서 겪는 문제를 이렇게 줄이겠다"에 둔다.

---

## 01. 왜 지금 플레이어 모듈화인가

핵심 메시지: 플레이어는 서비스별로 다시 만들 영역이 아니라 팀 공통 자산이 되어야 한다.

발표 스크립트:

지금부터 이야기하려는 건 단순히 새 플레이어를 만들었다는 이야기가 아닙니다.  
지금 우리 팀에서 반복해서 생기고 있는 문제를 어떻게 줄일 것인가에 대한 이야기입니다.

현재 고등 서비스에는 오래전에 만들어진 플레이어 코드가 있고, 유초등이나 해외사업부 같은 다른 서비스에서는 각자 네이티브 플레이어를 다시 붙이고 있습니다.  
문제는 각 서비스가 완전히 다른 문제를 풀고 있는 게 아니라는 점입니다. 재생, 제스처, 자막, 배속, DRM, 다운로드처럼 같은 플레이어 문제를 서비스마다 다시 풀고 있습니다.

그래서 이번 모듈화의 출발점은 "플레이어를 하나 더 만들자"가 아닙니다.  
"여러 서비스가 같은 문제를 다시 풀지 않게 하자"입니다.

전환 멘트:

그럼 반복 구현이 실제로 어떤 비용으로 돌아오는지 먼저 보겠습니다.

---

## 02. 현재 구조의 비용

핵심 메시지: 반복 구현은 초기 속도처럼 보이지만 장기 유지보수 비용을 키운다.

발표 스크립트:

서비스별로 플레이어를 빠르게 붙이는 방식은 처음에는 빠르게 보일 수 있습니다.  
하지만 플레이어는 단순 화면이 아니라 정책과 검증 비용이 큰 영역입니다.

예를 들어 제스처, 자막, 배속 같은 UX 정책은 서비스마다 다시 구현하고 다시 맞춰야 합니다.  
DRM, 다운로드, 오프라인 재생은 시뮬레이터만으로 닫히지 않아서 실기기 이슈를 각 서비스가 따로 추적하게 됩니다.  
SDK 버전이 바뀌면 빌드, 링크, 런타임 영향 범위도 서비스별로 다시 확인해야 합니다.

이런 방식이 계속되면 기능 하나를 고쳐도 여러 서비스가 같은 결정을 반복합니다.  
이 비용을 줄이려면 공통으로 가져갈 구조와 서비스별로 달라질 지점을 분리해야 합니다.

전환 멘트:

그래서 목표는 모든 서비스를 똑같이 만드는 것이 아니라, 공통 재생 구조를 재사용 가능하게 만드는 것입니다.

---

## 03. 목표는 공통 재사용 모듈

핵심 메시지: 공통화할 것은 재생 구조이고, 달라질 것은 Host가 주입한다.

발표 스크립트:

이번 모듈의 목표는 한 번 만들고 여러 서비스가 재사용하는 구조입니다.  
여기서 중요한 건 "모든 서비스가 같은 화면을 써야 한다"는 뜻이 아니라는 점입니다.

공통으로 가져갈 것은 재생 명령, 상태, 정책 협상, 엔진 계약입니다.  
서비스별로 달라질 수 있는 것은 Host가 주입합니다. 예를 들면 서비스별 기능 정책, 버튼 구성, 오버레이, 테마, 현지화 정책 같은 것들입니다.

즉 Core는 공통 재생 구조를 책임지고, Engine은 실제 재생 방법을 책임지고, Skin은 조립 가능한 UI를 제공합니다.  
Host는 자기 서비스에 필요한 정책과 UI 조각을 주입합니다.

전환 멘트:

여기서 한 가지 질문이 생길 수 있습니다. 그러면 그냥 SDK wrapper를 만들면 되는 것 아닌가? 다음 슬라이드에서 그 차이를 보겠습니다.

---

## 04. 단순 SDK wrapper로는 부족하다

핵심 메시지: wrapper는 SDK 호출을 감싸지만, module은 우리 팀의 재생 계약을 만든다.

발표 스크립트:

SDK wrapper는 SDK 호출 위치를 한 군데로 모을 수는 있습니다.  
하지만 wrapper만 만들면 SDK의 API 모양과 사고방식이 Host 화면까지 그대로 올라오기 쉽습니다.

우리가 필요한 건 Kollus API를 조금 예쁘게 감싼 wrapper가 아닙니다.  
우리 도메인의 `PlaybackCommand`, `PlaybackState`, `PlaybackSource`를 먼저 정의하고, SDK는 그 뒤에 숨기는 구조입니다.

이 구조에서는 SDK가 바뀌어도 Host는 command와 state를 그대로 사용할 수 있습니다.  
SDK 차이는 EngineAdapter가 흡수하고, 서비스별 차이는 protocol, policy, blueprint로 주입합니다.

전환 멘트:

이 차이를 이해하려면 모듈을 이루는 세 축을 먼저 보면 됩니다.

---

## 05. 모듈의 핵심 구조

핵심 메시지: Core는 상태, Engine은 재생 방법, Skin은 화면 조립을 담당한다.

발표 스크립트:

이 모듈은 크게 Core, Engine, Skin 세 축으로 볼 수 있습니다.

Core는 재생 명령과 상태를 소유합니다.  
여기에는 `PlaybackCommand`, `PlaybackState`, `PlaybackStateReducer`가 들어갑니다. 상태 전이는 Core가 결정합니다.

Engine은 실제 재생 방법을 번역합니다.  
일반 URL이나 HLS는 `AVPlayerAdapter`가 처리하고, Kollus DRM이나 다운로드는 `KollusPlayerAdapter`가 처리합니다. 나중에 다른 SDK가 필요하면 같은 계약을 구현하는 adapter를 추가하는 방식입니다.

Skin은 UI를 조립합니다.  
고정된 플레이어 화면 하나를 강제하는 것이 아니라, slot과 block, theme을 조합해서 서비스별 화면을 만들 수 있게 합니다.

전환 멘트:

그럼 왜 굳이 SDK 의존을 줄여야 하는지, 그리고 그게 가능한 구조인지 이야기하겠습니다.

---

## 06. SDK는 사서 쓰되, 의존은 줄인다

핵심 메시지: SDK는 구매하되 앱 구조 전체가 SDK에 묶이면 안 된다.

발표 스크립트:

VOD, DRM, 다운로드, 라이선스 서버 같은 영역은 직접 만드는 것보다 전문 SDK를 사용하는 것이 효율적입니다.  
그래서 이 발표의 방향은 SDK를 직접 만들자는 것이 아닙니다.

하지만 SDK는 언제든 바뀔 수 있습니다.  
정책, 가격, 품질, 지원 범위가 바뀔 수 있고, 더 나은 SDK가 나올 수도 있습니다.

그때 Host 화면 전체를 다시 고쳐야 한다면 SDK 구매의 장점이 줄어듭니다.  
그래서 SDK 타입은 EngineAdapter 안에 가두고, Host는 `PlaybackCommand`와 `PlaybackState`만 바라보게 합니다.

전환 멘트:

서비스별 차이는 어떻게 다룰까요? 여기서 POP와 Host 주입 구조가 나옵니다.

---

## 07. POP와 Host 주입

핵심 메시지: 공통 모듈이지만 서비스별 커스텀은 주입으로 열어둔다.

발표 스크립트:

서비스별 요구를 상속이나 거대한 옵션 분기로 처리하면 시간이 지날수록 플레이어가 커집니다.  
어느 서비스에서만 필요한 기능이 공통 코드의 조건문으로 계속 들어오게 됩니다.

이 모듈은 그 방향 대신 protocol과 주입을 사용합니다.  
서비스 정책은 `PlayerFeaturePolicy`로 넣고, 엔진이 실제 지원하는 기능은 `EngineCapabilities`로 협상합니다.  
UI는 `PlayerSkinBlueprint`로 어떤 slot에 어떤 block을 넣을지 정합니다.

중요한 점은 커스텀을 막지 않는다는 것입니다.  
단, 커스텀이 모듈 경계를 깨고 SDK나 내부 상태를 직접 만지는 방식이 아니라, 정해진 주입 지점으로 들어오게 합니다.

전환 멘트:

그럼 Host 개발자가 실제로 알아야 하는 표면은 무엇인지 보겠습니다.

---

## 08. Host가 알면 되는 것은 두 가지다

핵심 메시지: Host는 command를 보내고 state를 구독한다.

발표 스크립트:

Host 입장에서 핵심은 단순합니다.  
무엇을 하고 싶은지는 command로 보냅니다. 예를 들어 play, pause, seek 같은 명령입니다.

그리고 화면에 무엇을 그릴지는 state stream을 구독해서 처리합니다.  
Host가 SDK delegate, DRM callback, AVPlayer KVO를 직접 소유하지 않습니다.

이 구조가 중요한 이유는 여러 서비스가 같은 사용 표면을 공유할 수 있기 때문입니다.  
엔진이 AVPlayer인지 Kollus인지 달라도 Host는 같은 command와 state를 다룹니다.

전환 멘트:

이 command와 state가 런타임에서 어떻게 흐르는지 이어서 보겠습니다.

---

## 09. 런타임 흐름

핵심 메시지: 명령과 상태는 한 방향으로 흐른다.

발표 스크립트:

런타임 흐름은 한 방향입니다.  
Host나 Skin이 `PlaybackCommand`를 보내면 `PlayerCore actor`가 정책과 capability를 확인합니다.

그 다음 Core가 EngineAdapter에 명령을 위임합니다.  
엔진은 AVPlayer나 Kollus SDK를 호출하고, SDK raw callback을 `PlayerEngineOutput`으로 변환합니다.

그 신호는 다시 reducer로 들어가고, reducer가 다음 `PlaybackState`를 결정합니다.  
마지막으로 Host와 Skin은 그 state를 렌더링합니다.

이렇게 단방향으로 만들면 디버깅 기준도 명확해집니다.  
마지막 command가 무엇인지, 마지막 output이 무엇인지, reducer가 어떤 state를 만들었는지를 보면 됩니다.

전환 멘트:

이 흐름을 유지하려면 SDK가 들어오는 경계도 명확해야 합니다.

---

## 10. product 경계가 SDK 경계다

핵심 메시지: SDK 격리는 말이 아니라 SPM product 경계로 강제한다.

발표 스크립트:

이 모듈은 SDK 격리를 말로만 하지 않습니다.  
SPM product 경계로 나눕니다.

`VideoPlayerCore`는 도메인, 상태, 엔진 계약만 알고 SDK를 모릅니다.  
`VideoPlayerEngineNative`는 일반 URL과 HLS를 다루고, Kollus 의존이 없습니다.  
`VideoPlayerEngineKollus`만 Kollus와 PallyCon binary를 압니다.  
`VideoPlayerSkin`도 엔진이나 SDK를 모릅니다.

이렇게 해야 Native만 필요한 화면은 vendor binary를 피할 수 있고, SDK 교체 영향도 Kollus engine product 안으로 제한할 수 있습니다.

전환 멘트:

다음은 이 구조에서 가장 중요한 원칙인 상태 소유권입니다.

---

## 11. 상태 소유권은 Core에 있다

핵심 메시지: SDK는 신호를 주고, 상태는 Core가 결정한다.

발표 스크립트:

SDK callback 순서는 우리가 완전히 통제할 수 없습니다.  
네트워크, buffering, prepare, finish 같은 이벤트가 늦게 오거나 예상과 다른 순서로 올 수 있습니다.

만약 SDK callback이 화면 상태를 직접 바꾸면, 늦은 buffering callback이 이미 finished인 상태를 다시 playing이나 buffering으로 되살릴 수 있습니다.

그래서 엔진은 상태를 결정하지 않고 신호만 냅니다.  
그 신호를 Core의 reducer가 현재 상태와 함께 보고 다음 상태를 결정합니다.

이 덕분에 상태 전이 로직은 vendor SDK 없이 pure test로 검증할 수 있습니다.

전환 멘트:

상태만큼 중요한 것이 기능 지원 차이입니다. 모든 엔진이 모든 기능을 지원할 수는 없습니다.

---

## 12. 기능 차이는 capability로 처리한다

핵심 메시지: 기능 차이는 분기가 아니라 capability로 관리한다.

발표 스크립트:

공통 모듈이라고 해서 모든 엔진이 모든 기능을 지원해야 하는 것은 아닙니다.  
예를 들어 배속, 자막, 북마크, 다운로드, PiP 같은 기능은 엔진별로 지원 범위가 다를 수 있습니다.

그래서 실제 노출 가능한 기능은 세 가지의 교집합으로 봅니다.  
Host가 허용한 정책, 엔진이 실제 지원하는 capability, 그리고 optional protocol 지원 여부입니다.

이 방식이면 사용자가 눌러보고 실패하는 UX가 아니라, 시작 시점에 가능한 기능만 UI에 노출할 수 있습니다.

전환 멘트:

이제 실제 개발자가 이 모듈로 어떻게 조립하는지 보겠습니다. 먼저 Native engine입니다.

---

## 13. Native engine으로 개발하기

핵심 메시지: SDK가 필요 없는 화면은 Native engine만으로 가볍게 붙일 수 있다.

발표 스크립트:

일반 URL이나 HLS는 `AVPlayerAdapter`로 조립합니다.  
`PlayerModuleWiring.makeModule`에 engine과 capability를 넣으면 module이 만들어집니다.

그 다음은 동일합니다.  
`module.core.start(source: .url(videoURL), policy: .default)`로 source를 준비하고, `module.core.execute(command: .play)`로 재생합니다.

이 경로는 vendor SDK가 필요 없는 화면에 적합합니다.  
예를 들어 미리보기 영상, 광고 영상, DRM 없는 콘텐츠는 Native engine만으로 가볍게 붙일 수 있습니다.

전환 멘트:

Kollus를 써야 하는 경우도 Host 입장에서 흐름은 크게 달라지지 않습니다.

---

## 14. Kollus engine으로 개발하기

핵심 메시지: Kollus는 engine 안에 있고, Host는 같은 command/state 표면을 쓴다.

발표 스크립트:

Kollus는 SDK 초기화 값이 필요하기 때문에 `KollusEnvironment`를 먼저 만듭니다.  
application key, bundle ID, expire date, storage path, DRM 설정 같은 값이 여기에 들어갑니다.

그리고 `environment.validate()`로 잘못된 설정을 일찍 잡습니다.  
이후 `KollusPlayerModuleFactory`에서 module을 만들고, 재생은 똑같이 `module.core.start`와 `module.core.execute`로 진행합니다.

여기서 중요한 부분은 source가 `.mediaKey(mediaContentKey)`라는 점입니다.  
Core는 Kollus라는 이름을 모릅니다. media key라는 중립적인 source를 받고, Kollus adapter가 그것을 해석합니다.

전환 멘트:

엔진만 바꿀 수 있으면 절반입니다. 실제 서비스에서는 UI도 달라져야 하므로 Skin 조립 구조를 보겠습니다.

---

## 15. 서비스별 Skin 커스텀하기

핵심 메시지: 공통 Core 위에 서비스별 Skin을 조립한다.

발표 스크립트:

Skin은 하나의 고정 UI를 강제하는 구조가 아닙니다.  
고정된 skeleton slot을 제공하고, 각 slot에 어떤 block을 넣을지를 `PlayerSkinBlueprint`로 정합니다.

예를 들어 `topCenter`에는 `TitleBlock`, `centerControls`에는 `CenterPlaybackControlsBlock`, `bottomBar`에는 `ProgressBarBlock`, `floatingBottomTrailing`에는 `ExtraFloatingBlock`을 넣을 수 있습니다.

그리고 `visibleSlots`에서 layout mode별로 어떤 slot을 보여줄지 정합니다.  
즉 같은 Core와 같은 state를 쓰더라도 서비스별로 UI 배치와 버튼 구성을 다르게 가져갈 수 있습니다.

마지막으로 `AssembledPlayerSkin`에 blueprint와 theme을 넣어 실제 Skin을 만듭니다.

전환 멘트:

이제 이 구조가 실제로 어떻게 보이는지는 Example app 데모에서 확인할 수 있습니다.

---

## 16. Example app과 데모

핵심 메시지: 데모는 기능 자랑이 아니라 구조 검증이다.

발표 스크립트:

Example app은 단순 샘플이 아니라 이 모듈을 서비스에서 어떻게 조립할지 보여주는 레퍼런스입니다.

HLS 재생 데모에서는 Native engine과 공통 state 흐름을 확인합니다.  
Kollus DRM 데모에서는 SDK 격리와 engine 교체 구조를 확인합니다.  
다운로드와 오프라인 재생은 DRM 설정, storage, download center 경계를 확인하는 지점입니다.  
Skin 제스처는 서비스별 UI 조립이 실제로 가능한지를 보여줍니다.

데모에서 봐야 할 것은 버튼 하나가 동작한다는 사실보다, 앞에서 말한 경계가 실제로 유지되는지입니다.

전환 멘트:

이 경계가 유지되면 앞으로의 확장 방식도 달라집니다.

---

## 17. 미래 확장 시나리오

핵심 메시지: 미래 변화는 adapter, capability, skin block으로 흡수한다.

발표 스크립트:

앞으로 더 좋은 VOD SDK가 나오면 Host 화면을 다시 짜는 것이 아니라 새 EngineAdapter를 추가하는 방향으로 갑니다.  
서비스별 UI 요구가 생기면 Skin block이나 theme을 추가합니다.  
기능 지원 차이가 생기면 capability나 optional protocol을 확장합니다.

다운로드 정책이 바뀌면 DownloadCenter contract를 확장하고, 해외 서비스 요구가 생기면 Host policy와 localization 주입으로 대응합니다.

핵심은 미래 요구가 올 때마다 공통 모듈을 포크하거나 Host 화면 전체를 다시 만드는 방식에서 벗어나는 것입니다.

전환 멘트:

공통 모듈이 되려면 구조뿐 아니라 검증 방식도 같이 분리되어야 합니다.

---

## 18. 검증 전략과 남은 한계

핵심 메시지: 공통 모듈은 코드 경계뿐 아니라 검증 경계도 가져야 한다.

발표 스크립트:

여러 서비스가 재사용할 모듈이라면 "내 화면에서 한 번 됐다"로는 부족합니다.  
검증 경계도 구조에 맞게 나눠야 합니다.

상태 전이는 reducer pure test로 봅니다.  
SDK 이벤트 매핑은 signal mapper test로 봅니다.  
SDK 타입이 Core나 Skin으로 새어 들어오지 않는지는 boundary test로 봅니다.  
통합 패턴은 Example app에서 확인하고, DRM과 다운로드, 백그라운드 오디오는 실기기 QA로 확인해야 합니다.

남은 한계도 명확히 봐야 합니다.  
예를 들어 Kollus PiP는 현재 capability로 열지 않고, DRM/다운로드/백그라운드 오디오는 실기기 검증이 필요합니다. 기존 UX와 새 Skin의 제스처/HUD 정렬도 더 다듬어야 합니다.

전환 멘트:

그래서 오늘 이 자리에서 결정하고 싶은 것은 모든 세부 구현이 아니라 다음 세 가지입니다.

---

## 19. 오늘 결정할 것

핵심 메시지: 오늘은 구조 승인과 파일럿 착수를 결정하는 자리다.

발표 스크립트:

오늘 모든 세부 구현을 닫을 필요는 없습니다.  
대신 방향과 다음 단계를 결정하고 싶습니다.

첫 번째는 Core, Engine, Skin 구조로 공통 모듈화를 진행하는 방향을 승인할지입니다.  
두 번째는 파일럿 범위입니다. 전면 교체가 아니라 Host의 1개 화면부터 feature flag로 적용하는 방식을 제안합니다.  
세 번째는 정책 차이 처리 방식입니다. 기존 UX 기준으로 정렬하되, 서비스별 override를 허용하는 방식이 필요합니다.

이 세 가지가 정리되면 다음 단계로 넘어갈 수 있습니다.

전환 멘트:

마지막으로 파일럿 계획을 정리하고 마무리하겠습니다.

---

## 20. 파일럿 계획과 마무리

핵심 메시지: 이 모듈은 플레이어를 팀 공통 자산으로 만들기 위한 첫 단계다.

발표 스크립트:

마지막으로 처음 문제로 돌아가겠습니다.  
우리가 하려는 것은 기술적으로 멋있는 플레이어를 하나 더 만드는 것이 아닙니다.

여러 서비스가 같은 플레이어 문제를 다시 풀지 않도록, 공통 재생 구조를 팀 자산으로 만들자는 것입니다.

파일럿은 되돌릴 수 있게 시작합니다.  
Example app에서 통합 패턴을 확인하고, Host의 1개 화면에 feature flag로 적용합니다.  
그 다음 실기기 QA와 기존 UX 정렬을 진행하고, 결과를 보고 유초등이나 해외사업부 같은 다른 서비스로 확장할 수 있는지 판단합니다.

마무리 문장:

이 모듈은 플레이어를 서비스별 구현물이 아니라 팀 공통 자산으로 만들기 위한 첫 단계입니다.  
오늘은 이 구조로 파일럿을 시작할 수 있을지 결정하고 싶습니다.

