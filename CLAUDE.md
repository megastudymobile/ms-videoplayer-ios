# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 개요

`videoplayer-ios-ms`는 영상 재생을 **공통 상태 머신 + 교체 가능한 재생 엔진**으로 다루는 Swift Package. host 앱(smartlearning-ios-ms)은 `PlaybackSource` / `PlaybackCommand` / `PlaybackState`만 다루고, 실제 재생은 `AVPlayerAdapter`(일반 URL/HLS)나 `KollusPlayerAdapter`(Kollus MCK + DRM + 다운로드)가 맡는다.

PR 기본 base 브랜치: `main` (state-ownership 리팩터링이 main에 머지됨, 2026-06-05).

## 명령어

```bash
# 전체 테스트 (Swift Testing 사용, macOS에서는 #if canImport(UIKit) 가드로 iOS 전용 테스트 제외됨)
swift test

# 단일 테스트 필터
swift test --filter PlaybackStateReducerTests

# Kollus binary packaging 변경 시 검증
./scripts/verify_kollus_packaging.sh

# Example 앱 (Tuist 기반)
cp Example/Resources/kollus.local.plist.example Example/Resources/kollus.local.plist  # 최초 1회, gitignored
tuist generate
xcodebuild build \
    -workspace VideoPlayerExample.xcworkspace \
    -scheme VideoPlayerExample \
    -configuration Debug \
    -destination 'platform=iOS Simulator,name=iPhone 15'

# Example 단위 테스트 (VideoPlayerExampleTests — ViewModel/Resolver 순수 로직)
xcodebuild test \
    -workspace VideoPlayerExample.xcworkspace \
    -scheme VideoPlayerExample \
    -configuration Debug \
    -destination 'platform=iOS Simulator,name=iPhone 15'
```

Kollus 실제 재생/DRM/다운로드는 시뮬레이터로 닫기 어려움 — 해당 변경은 실기기 검증 결과를 별도로 남긴다.

## 아키텍처

명령 흐름: Shell/UseCase → `PlayerCore`(actor) → `PlayerPlaybackEngine` 구현체 → `PlayerEngineOutput` → `PlaybackStateReducer` → `PlaybackState` 스트림 → 화면.

### 모듈 의존 그래프 (Package.swift)

```
VideoPlayerCore  (의존 없음 — SDK/UIKit 모름)
  └── VideoPlayerShellSupport  (wiring, render surface, lifecycle/audio)
        ├── VideoPlayerEngineNative   (AVPlayerAdapter)
        └── VideoPlayerEngineKollus   (Kollus/PallyCon — Binaries/*.xcframework binary target)
  └── VideoPlayerSkin  (Core + ShellSupport 의존, 엔진 의존 없음 — host가 조립한 모듈 주입)
```

### VideoPlayerCore 내부 레이어

- `Domain/` — `PlaybackSource`, `PlaybackCommand`, `PlaybackState`, `PlayerEvent`, `PlayerFeaturePolicy`(앱 정책), `EngineCapabilities`(엔진 실제 지원 기능), `PlayerError`
- `Contract/` — `PlayerEngineAdapter`(모든 엔진의 계약, 전 명령 `async throws`), `PlayerEngineOutput`(엔진→코어 단방향 출력)
- `StateTransition/` — `PlaybackStateReducer`: 순수 함수 상태 머신. 엔진 출력(`PlaybackStateInput`)을 받아 상태 전이 결정. 상태 소유권은 코어에 있고 엔진은 신호만 발행
- `Internal/PlayerCore.swift` — actor. 정책·capability 협상 후 엔진에 명령 위임
- `UseCase/` — start / control / observe

### 엔진 측 패턴

- 각 엔진은 `Signal/` 디렉터리의 mapper(`KollusSignalMapper`, `AVPlayerSignalMapper`)로 SDK raw 이벤트 → `PlayerEngineOutput` 변환. 매핑 로직은 순수 함수로 분리되어 단독 테스트됨
- `KollusEnvironment` — host가 주입하는 SDK bootstrap/DRM/다운로드/진단 설정의 단일 진입점. `validate()`로 필수 값 검증
- 같은 `KollusPlayerModuleFactory`에서 만든 모듈들은 `KollusSessionBootstrapper` + `KollusDownloadCenter`(`Downloads/`)를 공유

### VideoPlayerSkin

재사용 가능한 플레이어 UI (Rx/ReactorKit/SnapKit 의존 없음). `Blocks/`(ProgressBar 등 UI 조각), `Contract/`, `Assembly/`, `Theme/`, `Resources/PlayerSkin.xcassets`. host와는 `PlayerSkinAction` / `PlayerSkinState`로 통신.

## 경계 규칙

- `Core`는 SDK를 모른다. Kollus/PallyCon import는 `VideoPlayerEngineKollus` 안에서만
- host 앱 코드는 Kollus SDK를 직접 import하지 않고 이 패키지의 product만 사용
- SmartLearning 화면/라우팅/Remote Config/LMS 분석 코드는 이 패키지로 가져오지 않는다
- 엔진 명령은 모두 `async throws` — 실패 가능성을 숨기지 않는다
- 엔진은 actor로 격리해 상태 변경 순서를 보장
- `PlayerModuleBoundaryTests`가 패키지 소스에 서비스 앱 용어("MegaStudy" 등) 포함을 금지 — 주석에도 금지어 사용 불가. 레거시 코드를 언급할 때는 "레거시 host 앱" 식으로 일반화해서 작성

## Kollus SDK packaging

- `Vendor/` 원본 산출물은 직접 수정 금지. `Packaging/` + `scripts/`로 XCFramework 재현 가능해야 함
- SDK 교체 시 checksum 갱신 및 packaging 절차 기록
- 스크립트: `sync_*_vendor.sh` → `rebuild_*_xcframework.sh` → `verify_kollus_packaging.sh`

## 테스트

- **Swift Testing** (`import Testing`, `@Test`/`#expect`) 사용. XCTest 아님
- iOS 전용 모듈(Skin, ShellSupport, 엔진) 테스트는 `#if canImport(UIKit)` 가드 필수 — 테스트 타깃이 macOS에서도 컴파일되기 때문
- 순수 로직(Reducer, SignalMapper)은 `Tests/VideoPlayerModuleTests/Core/`, `Kollus/`, `Native/`에 분리. 새 상태 전이나 신호 매핑 추가 시 여기에 테스트 추가
- 테스트 공용 팩토리는 `Tests/VideoPlayerModuleTests/Support/`

## 문서

`docs/`에 설계·작업 문서 유지:

- `example-app-rebuild-plan.md` — Example 앱(메인/플레이어/세팅 3화면, skin 조립) 설계·구현 상태·실기기 QA 체크리스트. Example 작업 시 이 문서 상태 갱신

참고: README의 "폴더 구조" 섹션은 구버전 레이아웃(`Sources/VideoPlayerModule/...`)을 보여주므로 실제 구조는 `Package.swift`를 기준으로 한다.
