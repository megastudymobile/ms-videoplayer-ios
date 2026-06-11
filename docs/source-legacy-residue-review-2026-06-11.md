# Sources 레거시 잔재 상세 검토

Author: JunyoungJung  
Date: 2026-06-11  
Scope: `Sources/`

## 검토 기준

이 문서는 `Sources/` 안에 남아 있는 레거시 코드 잔재 후보를 항목별로 설명한다. 단순히 문자열이 오래되었다는 이유만으로 문제로 보지 않고, 다음 기준 중 하나 이상에 해당하는 경우 잔재 후보로 분류했다.

- 현재 패키지 경계와 맞지 않는 host/domain 용어가 `Sources`에 남아 있음
- 전환기 구현 또는 test-only 구현이 프로덕션 모듈 코드 경로에 남아 있음
- 작업 단계, 이슈 번호, 설계 문서명 같은 과거 작업 맥락이 주석에 남아 있음
- 현재 API 의미보다 과거 구현 기준을 이름으로 드러냄
- asset catalog에 원본 export 흔적이나 중복 리소스명이 남아 유지보수 비용을 키움

검토는 정적 검색과 주변 코드 확인으로 진행했다. 빌드와 테스트는 실행하지 않았다.

## 1. `legacyStorage` 기반 Kollus prepare 경로

### 결론

`KollusPlayerAdapter` 안에 `legacyStorage`와 `prepareWithLegacyStorage` 경로가 남아 있다. 주석상 test-only 경로지만, 실제 `Sources`의 adapter 내부 분기로 유지되고 있어 최신 bootstrapper 기반 경로와 다른 prepare 계약을 가진다.

### 코드 근거

- `Sources/VideoPlayerEngineKollus/KollusPlayerAdapter.swift:60`
  - `private let legacyStorage: KollusStorage?`
- `Sources/VideoPlayerEngineKollus/KollusPlayerAdapter.swift:135`
  - `internal init()`이 `KollusStorage()`를 직접 생성
- `Sources/VideoPlayerEngineKollus/KollusPlayerAdapter.swift:143`
  - `init(storage: KollusStorage, ...)`
- `Sources/VideoPlayerEngineKollus/KollusPlayerAdapter.swift:200`
  - `prepare(source:)`에서 `bootstrapper != nil`이 아니면 `legacyStorage` 분기로 진입
- `Sources/VideoPlayerEngineKollus/KollusPlayerAdapter.swift:711`
  - `prepareWithLegacyStorage`가 SDK delegate 완료 콜백을 기다리지 않고 동기 `prepareToPlay` 직후 `.readyToPlay` 상태로 전이
- `Sources/VideoPlayerEngineKollus/KollusPlayerAdapter.swift:719`
  - `"legacy storage 누락"` 에러 문자열

### 왜 레거시 잔재인가

현재 권장 조립 경로는 `KollusSessionBootstrapper`와 `KollusEnvironment`를 받는 initializer다. 이 경로는 SDK bootstrap, delegate bridge, prepare 완료 대기, observer/diagnostics 배선까지 포함한다.

반면 `legacyStorage` 경로는 storage를 직접 넣고 bridge/delegate 완료를 기다리지 않는 테스트 스캐폴딩이다. 코드 주석도 프로덕션 계약을 의도적으로 지키지 않는다고 설명한다. 즉, 현재 구조의 핵심 경로가 아니라 과거 직접 storage 주입 방식이 adapter 내부에 남은 형태다.

### 영향

- adapter가 두 prepare 계약을 동시에 갖게 되어 동작 추론이 어려워진다.
- test-only 경로가 프로덕션 타입 내부에 남아 있어 향후 리팩터링 때 실사용 경로로 오해될 수 있다.
- `"legacy storage"` 같은 에러 문자열이 외부에 노출될 가능성은 낮지만, 노출되면 현재 구조와 맞지 않는 메시지가 된다.

### 권장 정리 방향

1. `KollusPlayerAdapter()` 기본 internal init을 사용하는 테스트를 bootstrapper + fake storage 기반으로 옮긴다.
2. `init(storage:)`, `legacyStorage`, `prepareWithLegacyStorage`를 제거한다.
3. 즉시 제거가 어렵다면 이름을 `testStorage` / `prepareWithTestStorage`처럼 목적 기반으로 바꾸고, `#if DEBUG`가 아니라 `internal` 테스트 유틸 또는 테스트 support로 격리한다.

### 검증 포인트

- `swift test --filter KollusPlayerModuleFactoryTests`
- `swift test --filter KollusPlayerAdapterPrepareTests`
- `swift test --filter KollusAdapterSubtitleBookmarkTests`

## 2. `Legacy*` UI 명칭

### 결론

`VideoPlayerSkin`에 `LegacySubCaptionLabel`과 `applyLegacyMetrics`가 남아 있다. 구현은 현재 UI에 필요한 보정으로 보이지만, 이름이 과거 구현 기준을 현재 코드 의미로 고정하고 있다.

### 코드 근거

- `Sources/VideoPlayerSkin/PlayerCaptionView.swift:19`
  - `private let secondaryLabel = LegacySubCaptionLabel()`
- `Sources/VideoPlayerSkin/PlayerCaptionView.swift:182`
  - `private final class LegacySubCaptionLabel: UILabel`
- `Sources/VideoPlayerSkin/Assembly/AssembledPlayerSkin.swift:83`
  - `applyLegacyMetrics(state)`
- `Sources/VideoPlayerSkin/Assembly/AssembledPlayerSkin.swift:350`
  - `private func applyLegacyMetrics(_ state: PlayerSkinState)`

### 왜 레거시 잔재인가

현재 패키지는 host 앱과 분리된 reusable skin을 제공한다. 이 레이어에서 중요한 것은 "어떤 화면 요구를 만족하는가"이지 "과거 어떤 UI와 맞추는가"가 아니다.

`LegacySubCaptionLabel`은 실제로 secondary caption에 top padding을 부여하는 label이다. `applyLegacyMetrics`도 slot spacing과 floating bottom offset을 layout mode에 따라 조정하는 함수다. 즉, 이름을 현재 동작 기준으로 표현할 수 있는데도 `Legacy`라는 과거 기준을 노출한다.

### 영향

- 신규 개발자가 해당 코드가 제거 예정이거나 임시 호환 코드라고 오해할 수 있다.
- 문서의 "레거시 코드 참조 금지" 규칙과 충돌한다.
- UI 보정값의 근거가 현재 layout rule인지 과거 화면 parity인지 불명확해진다.

### 권장 정리 방향

- `LegacySubCaptionLabel` -> `PaddedSecondaryCaptionLabel`
- `applyLegacyMetrics` -> `applyLayoutMetrics`
- 필요하면 metric 이름도 현재 의미 중심으로 정리한다.
  - 예: `primaryBottomOffsetWhenSecondaryVisible`
  - 예: `floatingBottomConstraint`에 적용되는 offset 규칙을 layout mode 기준으로 명명

### 검증 포인트

- `swift test`
- Example 앱에서 primary/secondary caption 노출, fullscreen iPad spacing, vertical split floating control 위치 확인

## 3. `lecturePlayer.*` accessibility identifier

### 결론

`VideoPlayerSkin`의 accessibility identifier가 `lecturePlayer.*` prefix를 사용한다. `Sources` 패키지는 강의 화면 전용 모듈이 아니므로 host/domain 용어가 skin 내부에 남은 상태다.

### 코드 근거

대표 예시는 다음과 같다.

- `Sources/VideoPlayerSkin/PlayerCaptionView.swift:79`
  - `lecturePlayer.captionView`
- `Sources/VideoPlayerSkin/PlayerGestureHUDView.swift:134`
  - `lecturePlayer.gestureHUDView`
- `Sources/VideoPlayerSkin/PlayerRenderSurfaceView.swift:75`
  - `lecturePlayer.renderSurface.placeholderLabel`
- `Sources/VideoPlayerSkin/Blocks/PlayButtonBlock.swift:9`
  - `lecturePlayer.skin.playPauseButton`
- `Sources/VideoPlayerSkin/Blocks/ProgressBarBlock.swift:78`
  - `lecturePlayer.skin.progressSlider`

검색 기준으로는 `Sources/VideoPlayerSkin` 안에서 `lecturePlayer.` identifier가 25건 확인됐다.

### 왜 레거시 잔재인가

이 패키지의 목적은 host 앱이 `PlaybackSource`, `PlaybackCommand`, `PlaybackState`와 skin contract를 통해 재생 UI를 조립하게 하는 것이다. `lecturePlayer`는 특정 host 화면의 도메인 명칭에 가깝다.

패키지 내부 identifier가 host 화면 이름을 쓰면, 재사용 가능한 skin이 실제로는 강의 플레이어 전용이라는 인상을 준다. 또한 다른 host가 사용할 때 UI automation identifier가 의미적으로 맞지 않는다.

### 영향

- host 독립 패키지라는 경계가 흐려진다.
- UI 테스트나 접근성 디버깅에서 identifier가 실제 모듈 책임과 다르게 보인다.
- 나중에 강의 외 사용처가 생기면 identifier rename 범위가 더 커진다.

### 권장 정리 방향

identifier prefix를 현재 모듈 의미에 맞춰 통일한다.

- 추천 prefix: `videoPlayer.skin.*`
- 대안 prefix: `playerSkin.*`

예시:

```swift
button.accessibilityIdentifier = "videoPlayer.skin.playPauseButton"
slider.accessibilityIdentifier = "videoPlayer.skin.progressSlider"
```

단, 기존 host UI 테스트가 `lecturePlayer.*`에 의존할 수 있으므로 rename 전 테스트 의존성을 먼저 검색해야 한다.

### 검증 포인트

- 패키지 테스트: `swift test`
- host 앱 UI 테스트 또는 QA 스크립트에서 `lecturePlayer.` 검색
- Example 앱 접근성 identifier 기반 테스트가 있다면 함께 갱신

## 4. 파일 헤더와 작업번호 주석

### 결론

`Sources` 여러 파일에 `Phase`, `Txxx`, `Created by 모바일팀_정준영`, `Copyright © 2026 megastudyedu` 같은 과거 작업/조직 맥락이 남아 있다.

### 코드 근거

- `Sources/VideoPlayerEngineKollus/KollusPlayerModuleFactory.swift:5`
  - `Updated by 모바일개발팀_정준영 on 2026/05/15 (Phase 3 T026).`
- `Sources/VideoPlayerEngineKollus/Downloads/KollusStorageBridge.swift:5`
  - `Created by 모바일개발팀_정준영 on 2026/05/15 (Phase 6 T042).`
- `Sources/VideoPlayerEngineKollus/Downloads/KollusDownloadCenter.swift:5`
  - `Created by 모바일개발팀_정준영 on 2026/05/15 (Phase 6 T043).`
- `Sources/VideoPlayerEngineKollus/KollusDelegateBridge.swift:6`
  - `Updated on 2026/05/15 (Phase 3 refactor): ...`
- `Sources/VideoPlayerSkin/*`
  - `Copyright © 2026 megastudyedu. All rights reserved.`

검색 기준으로 `Created by 모바일*`, `Updated by 모바일*`, `Copyright © 2026 megastudyedu` 계열은 72개 파일/라인에서 확인됐다.

### 왜 레거시 잔재인가

AGENTS 주석 규칙은 작업번호, 설계안 식별자, 레거시 참조, spec/phase류 주석을 금지한다. 이런 정보는 코드의 현재 동작을 설명하지 않고 과거 작업 이력을 설명한다.

또한 이 패키지는 `VideoPlayerModule contributors` 기준 헤더를 쓰는 파일도 있고, `megastudyedu` copyright를 쓰는 파일도 있어 소유권 표기가 섞여 있다.

### 영향

- 코드 주석이 현재 제약보다 과거 작업 이력을 설명한다.
- 모듈 사용자에게 특정 조직/host 소유 코드처럼 보일 수 있다.
- 파일 생성 규칙과 실제 헤더 스타일이 일관되지 않다.

### 권장 정리 방향

- `Phase`, `Txxx`, `refactor` 작업 단계 주석은 제거한다.
- 파일 상단 보일러플레이트를 유지할 경우 작성자는 Git user name인 `JunyoungJung`로 통일한다.
- copyright 문구는 프로젝트 정책에 맞춰 하나로 통일한다.
- 코드의 "왜"를 설명해야 하는 경우 작업번호 대신 현재 제약을 자연문으로 남긴다.

예시:

```swift
// SDK delegate 콜백을 단일 bridge로 모아 engine signal과 observer 이벤트로 분배한다.
```

### 검증 포인트

- `rg -n "Phase [0-9]|T[0-9]{3}|megastudyedu|Created by 모바일|Updated by 모바일" Sources`
- 주석 정리만 수행한 경우 `swift test`로 컴파일 영향 확인

## 5. 전환기 mirror / deprecated 표현 — 정리 완료 (2026-06-11)

### 결론

`eventStream`, `currentState`, `.stateDidChange` bridge와 관련해 `전환기`, `deprecated mirror` 표현이 남아 있다. 현재 호환 경로라면 당장 버그는 아니지만, 전환 완료 여부를 판단해야 하는 잔재다.

### 처리 결과

권장 정리 방향 1안(전환 완료 판단 → mirror 제거)으로 처리했다.

- `PlayerPlaybackEngine`에서 `currentState`/`eventStream` 요구를 제거하고 `outputStream`을 엔진의 유일한 출력으로 변경. 후속으로 전환기 분리 protocol이었던 `PlayerEngineOutputProducing`을 `PlayerPlaybackEngine`에 흡수해 삭제.
- `PlayerCore`의 미전환 엔진용 `eventStream` bridge(`engineOutput(from:)`)를 제거. `.event(.stateDidChange)` 분기는 custom engine 방어용 compatibility guard로 목적을 명시해 유지.
- 어댑터 3종(Kollus/Native/UnsupportedEnvironment)에서 mirror 발행 경로 전부 제거. 이벤트는 signal mapper가 `outputStream`으로 동일하게 발행함을 확인.
- 소비처 확인 결과: host 앱은 엔진 mirror를 직접 소비하지 않았고(Core `eventStream`의 `.stateDidChange`는 reducer가 계속 발행하므로 영향 없음), Example 앱의 `module.engine.currentState` 소비 3곳은 Core 스트림 기반 스냅샷 추적으로 대체.
- 검증: macOS `swift test` + iOS 시뮬레이터 전체 테스트 통과. `docs/HANDOVER/05-engine-contract.md` 계약 스니펫 동기화.

### 코드 근거

- `Sources/VideoPlayerEngineKollus/KollusPlayerAdapter.swift:51`
  - `eventStream/currentState는 전환기 deprecated mirror`
- `Sources/VideoPlayerEngineNative/AVPlayerAdapter.swift:29`
  - 같은 의미의 `deprecated mirror`
- `Sources/VideoPlayerCore/Internal/PlayerCore.swift:322`
  - `전환기 bridge 경로`
- `Sources/VideoPlayerEngineKollus/KollusPlayerAdapter.swift:709`
  - `아래 switch는 전환기 mirror(eventStream/state) + 부수효과...`

### 왜 레거시 잔재인가

현재 아키텍처 기준으로 상태의 권위 경로는 `PlayerEngineOutput` -> `PlaybackStateReducer` -> `PlaybackState`다. 그런데 기존 `eventStream` / `currentState` mirror도 동시에 유지되고 있다.

호환을 위해 남긴 API일 수는 있지만, 주석은 "전환기"라고 말한다. 전환기가 끝난 상태라면 제거해야 하고, 아직 외부 계약이라면 deprecated가 아니라 compatibility surface로 명확히 정의해야 한다.

### 영향

- 상태 소유권이 Core인지 engine mirror인지 읽는 사람이 혼동할 수 있다.
- event/state 이중 발행이 필요한 이유가 현재 계약인지 과거 마이그레이션 잔재인지 불명확하다.
- 장기적으로 reducer 중심 구조를 단순화하는 데 방해가 된다.

### 권장 정리 방향

선택지는 둘 중 하나다.

1. 전환 완료로 판단되면 `eventStream/currentState` mirror와 `.stateDidChange` bridge 소비 경로를 제거한다.
2. 아직 외부 호환 계약이면 주석을 "전환기"가 아니라 "compatibility mirror" 또는 "legacy consumer compatibility"처럼 목적 기반으로 바꾸고, 제거 조건을 문서화한다.

현재 패키지 공개 API와 host 앱 소비 경로를 먼저 확인한 뒤 결정해야 한다.

### 검증 포인트

- `PlayerEngineAdapter` 구현체의 `eventStream` 사용처 검색
- sibling host 앱에서 `eventStream`, `currentState`, `.stateDidChange` 직접 소비 여부 확인
- `swift test`
- host build

## 6. Skin asset catalog 원본 export 잔재

### 결론

`PlayerSkin.xcassets`에 원본 디자인 툴 export 흔적으로 보이는 파일명과 중복 리소스명이 많이 남아 있다. 일부는 `Contents.json`에서 실제 참조되므로 단순 삭제 대상은 아니지만, 리소스 정리 잔재로 분류할 수 있다.

### 코드 근거

대표 예시는 다음과 같다.

- `Sources/VideoPlayerSkin/Resources/PlayerSkin.xcassets/PlayerBookmarkAddNormal.imageset/Contents.json:15`
  - `ic_add_bookmark 1.png`
- `Sources/VideoPlayerSkin/Resources/PlayerSkin.xcassets/PlayerBookmarkListSelected.imageset/Contents.json:4`
  - `Property 1=Select.png`
- `Sources/VideoPlayerSkin/Resources/PlayerSkin.xcassets/PlayerControlRateDown.imageset/Contents.json:4`
  - `Group 98.png`
- `Sources/VideoPlayerSkin/Resources/PlayerSkin.xcassets/PlayerBackwardNormal.imageset/Contents.json:15`
  - `btn_____.png`
- `Sources/VideoPlayerSkin/Resources/PlayerSkin.xcassets/PlayerRateMinusButton.imageset/Contents.json:31`
  - `plusDarkButton@@x.png`
- `Sources/VideoPlayerSkin/Resources/PlayerSkin.xcassets/PlayerNextLectureButtonIcon.imageset/Contents.json:4`
  - `Vector.png`

검색 기준으로 `* 1.png`, `Property 1=*`, `Group *`, `Vector*`, `Ellipse*`, `btn_____*`, `*@@x.png` 후보가 70개 확인됐다.

### 왜 레거시 잔재인가

asset catalog의 외부 API는 보통 imageset 이름이다. 내부 파일명은 앱 동작에 직접 노출되지는 않지만, 유지보수자는 파일명을 보고 어떤 이미지인지 판단한다. `Group 98`, `Vector`, `Property 1=Select`, `btn_____` 같은 이름은 현재 UI 의미를 설명하지 못한다.

또한 같은 imageset 안에 normal/dark appearance 이미지가 `파일명 1.png` 패턴으로 섞여 있어, 리소스를 교체할 때 실수할 가능성이 높다.

### 영향

- asset 교체 또는 비교 시 어떤 파일이 실제 참조되는지 확인 비용이 커진다.
- `plusDarkButton@@x.png`처럼 오타성 파일명은 scale 리소스 관리 실수를 유발할 수 있다.
- 코드상 image name은 정리되어 있어도 실제 번들 리소스 품질이 낮아 보인다.

### 권장 정리 방향

- 각 imageset 안의 파일명을 현재 asset 의미와 appearance/scale 기준으로 rename한다.
- `Contents.json`의 filename도 함께 갱신한다.
- 동일 이미지 중 실제 참조되지 않는 파일이 있으면 제거한다.
- 리소스 rename 후 Example 앱에서 주요 버튼 이미지를 육안 확인한다.

예시:

```text
ic_add_bookmark 1.png      -> player_bookmark_add_dark.png
Property 1=Select@2x.png   -> player_bookmark_list_selected@2x.png
Group 98@3x.png            -> player_rate_down_dark@3x.png
```

### 검증 포인트

- `swift test`
- Example 앱 build
- 플레이어 skin 주요 버튼 렌더 확인
- `rg -n " 1\\.png|Property 1|Group 98|Vector|Ellipse|btn_____|@@x" Sources/VideoPlayerSkin/Resources/PlayerSkin.xcassets`

## 우선순위 제안

1. `legacyStorage` 경로 정리
   - 실제 코드 분기이며 prepare 계약이 다르므로 가장 먼저 판단해야 한다.
2. `lecturePlayer.*` identifier 정리
   - host/domain 누수라 모듈 경계에 직접 영향을 준다.
3. `Legacy*` 네이밍 정리
   - 동작 변경 없이 의미를 바로잡기 쉽다.
4. `Phase/Txxx`와 헤더 정리
   - AGENTS 주석 규칙 위반이며 mechanical cleanup 가능성이 높다.
5. ~~전환기 mirror 주석/계약 정리~~ — 완료 (mirror 제거, 위 5번 처리 결과 참조)
6. asset catalog 정리
   - 영향 범위는 낮지만 파일 수가 많아 별도 PR로 분리하는 편이 안전하다.

