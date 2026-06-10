# Kollus 플레이어 파리티 검토 보고서

- 작성자: JunyoungJung
- 작성일: 2026-06-10
- 비교 대상
  - 신규: `videoplayer-ios-ms/Sources` (VideoPlayerSkin / VideoPlayerCore / VideoPlayerEngineKollus / VideoPlayerShellSupport)
  - 레거시: `smartlearning-ios-ms/SmartPlayer/SmartPlayer/ObjcFeature/Player` (MGPlayerSkinView, MGPlayerViewController, MegaKollusMoviePlayerController 등)

## 총평

핵심 UI/기능 파리티 대체로 달성. **격차 6건**, **설계상 호스트 위임 항목 3건** 발견.

## 1. 일치 항목

| 영역 | 비교 결과 |
|---|---|
| UI 컨트롤 세트 | 닫기·제목·화면비율·잠금·더보기(상단), ±10초·재생/일시정지(중앙), 목차·북마크(좌측), 배속, 슬라이더·시간·회전(하단) — 레거시 `MGPlayerSkinView` 전 컨트롤에 대응 블록 존재 (`Sources/VideoPlayerSkin/Blocks/`) |
| 화면비율 | aspectFit → aspectFill → fill 순환 3모드, Kollus contentMode 매핑 동일 |
| 배속 | 0.5~2.0 표준 / 0.5~4.0 확장(강의), 0.1 step — 레거시 `SLPlayerSetting` 값과 일치. 레거시의 "Play delegate 이후 배속 설정" 이슈(2024.01.04)는 신규에서 권위 신호(`emitsObservedCommandState`) 구조로 흡수 |
| 구간반복 | 시작→끝 2단계 설정, `SectionRepeatState`(idle/started/looping) 동일. 레거시는 자동 루프 TODO 미해결, 신규는 상태 모델 보유 — 개선 |
| 자막 | 주/보조(AI) 2채널, Kollus `charset:caption:` / `charsetSub:captionSub:` 델리게이트 매핑 동일 (`KollusSignalMapper`) |
| 북마크 | add/remove/권위 목록 동기화. `KollusBookmarkStore` 낙관 캐싱은 레거시에 없던 개선 (SDK 반영 지연 대응) |
| 백그라운드 재생 | AVPlayer detach/reattach (`KollusBackgroundAudioKeeper`) — 레거시 `MegaStudyBackgroundPlayerManager` 패턴과 동일 |
| 이미지 에셋 | 레거시 스킨 사용 27종 전부 포함, iPad 분기 이미지(`*iPad`) 포함 |
| iPhone/iPad 분기 | `PlayerSkinLayoutMode` 3모드(verticalSplit / horizontalSplit / fullScreen)로 대응 |
| 롱프레스 2배속 | `longPressBegan/Ended` 제스처 액션 + HUD `presentRate` 대응 존재 |

## 2. 격차 (수정 검토 필요)

### 2.1 제스처 HUD 이미지 4종 누락

`PlayerBrightnessNormal`, `PlayerVolumeNormal`, `PlayerBackwardGestureNormal`, `PlayerForwardGestureNormal` 이 `Sources/VideoPlayerSkin/Resources/PlayerSkin.xcassets`에 없음.

`PlayerGestureHUDView.applyIcon`은 이미지 미발견 시 텍스트 라벨 fallback (`Sources/VideoPlayerSkin/PlayerGestureHUDView.swift:156-168`) → 밝기/볼륨/시킹 제스처 시 레거시와 시각 표현 다름.

- 레거시 근거: `MGPlayerViewController.m:40-62` (제스처 이미지 상수)
- 조치: 레거시 에셋 4종 복사

### 2.2 더블탭 제스처 정책 차이

`PlayerGestureAction`(`Sources/VideoPlayerSkin/PlayerGestureAction.swift`)과 Example host는 더블탭을 좌/우 10초 이동 전용으로 제공한다.

레거시는 더블탭 재생/일시정지가 기본 ON (`usePlayDoubleTapGesture=YES`, `MGPlayerViewController.m:1292-1336`). 설정에 따라 좌/우 더블탭 ±10초 모드도 지원한다.

- 현재 결정: Example은 더블탭 재생/일시정지 모드를 제거하고 `doubleTapSkip(forward:)` 기반 10초 이동만 허용한다. 파리티 관점에서는 레거시 기본값과 다르므로 host 제품 정책으로 유지 여부를 관리한다.

### 2.3 줌 상태 화면 이동(pan move) 스킨 액션 부재

레거시 `MGPlayerPanGestureMove`(핀치 확대 후 드래그로 영상 위치 이동, `MGPlayerViewController.h:34-72`) 대응 없음.

엔진에는 `scroll`/`zoom` 명령 존재 (`Sources/VideoPlayerEngineKollus/KollusPlayerAdapter.swift:360`) — 스킨 측 제스처 액션만 빠진 상태.

- 조치: `PlayerGestureAction`에 scroll/pan 케이스 추가 + 호스트 라우팅 경로 마련

### 2.4 자막 폰트 크기 범위 상이

| | 범위 | 단위 | 기본값 |
|---|---|---|---|
| 레거시 | 10~40pt | 5pt | 20pt (`SLPlayerSetting.h:160-167`) |
| 신규 | 14~22pt | — | 16pt (`Sources/VideoPlayerCore/Domain/PlayerFeatureSet.swift:79-80`) |

host가 `captionFontSizes` 주입으로 맞출 수 있으나 default 불일치.

- 조치: default를 레거시 값으로 맞출지 정책 결정

### 2.5 제스처 HUD 표시 시간 상이

- 레거시: 2.0초 (`kMGPlayerGestureDuration`, `MGPlayerViewController.m:96`)
- 신규: 1.2초 (`Sources/VideoPlayerSkin/PlayerGestureHUDView.swift:53`)

### 2.6 재생 중 스킨 자동 숨김 누락

레거시는 재생 중 스킨이 표시된 상태에서 사용자 입력이 없으면 약 3초 후 컨트롤을 숨긴다. 신규 Example host는 `controlsVisible` 초기값이 `true`이고 탭 토글 외 자동으로 끄는 예약 로직이 없어 재생 중에도 스킨이 계속 표시된다.

- 레거시 근거: `kAutoHideTimeStandard = 3`, 재생 진행 타이머에서 표시 시간 누적 후 `hidePlayerSkin`
- 조치: host에서 `isPlaying && controlsVisible && !isLoading && !isLocked` 조건일 때 3초 자동 숨김 예약, 사용자 상호작용 시 리셋

## 3. 설계상 호스트 위임 (패키지 결함 아님 — host 앱 구현 시 누락 주의)

1. **제스처 인식기 자체** — 패키지 Sources에 tap/pan/pinch/longPress 인식기 없음. Example의 `PlayerViewController`가 소유. host 마이그레이션 시 레거시 제스처 파라미터 재현 책임은 host 몫:
   - 팬 시킹 환산: `translation.x / 15.0` (1단위 ≈ 1초)
   - 팬 인식 기준: 10pt (`kMGPlayerPanGestureTranslationStandard`)
   - 상하 팬 좌측=밝기, 우측=볼륨 분기
2. **이어보기 확인 팝업** — 레거시 alert + "마지막 5초 → 0초 조정" 로직(`MegaStudyMoviePlayerController.m:5325-5533`)은 패키지에 없음. 시작 위치는 `PlaybackSource`로 주입.
3. **다음 강의 자동재생** — 패키지는 `nextEpisodeAvailable` 이벤트만 발행 (`KollusNextEpisodeEmitter`). 자동재생 판단·강의 전환은 host.

## 4. 격차 아님 (확인 완료)

- **PiP**: 양쪽 다 미지원 (`KollusPlayerAdapter.swift:162` 명시 주석)
- **썸네일 시킹**: 레거시도 v4.1.0+ 비활성, 신규 `thumbnailReady` 신호 매핑 nil — 동등
- **배속 컨트롤 위치**: 레거시 우측 사이드 vs 신규 floating 버튼 + fullscreen rate control — 배치 다름. 의도된 리디자인인지 확인 필요 (보류)

## 5. 권장 조치 순서

1. 제스처 HUD 에셋 4종 복사 (§2.1) — 단순 에셋 추가
2. 더블탭 제스처 정책 확인 (§2.2) — 현재 Example은 10초 이동 전용
3. 줌-팬 이동 스킨 액션 추가 (§2.3) — 액션 + 엔진 라우팅
4. 자막 크기 default 정책 결정 (§2.4)
5. HUD 표시 시간 2.0초로 조정 여부 결정 (§2.5)
6. 재생 중 스킨 자동 숨김 구현 (§2.6)
