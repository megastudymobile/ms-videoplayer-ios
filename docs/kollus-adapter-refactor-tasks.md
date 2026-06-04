# Tasks: 플레이어 엔진 어댑터 리팩터링 (B안 — Core 단일 상태 소유)

> 작성: 모바일개발팀_정준영 · 2026-06-04
> 출처 설계: [kollus-adapter-refactor-architecture.md](kollus-adapter-refactor-architecture.md)
> 범위: `VideoPlayerCore`가 유일한 `PlaybackState` 소유자가 되고, 엔진 어댑터는 SDK 신호를 `PlaybackStateInput`/passthrough `PlayerEvent`로 정규화하는 구조로 전환.

이 문서는 설계 문서 §8 마이그레이션 7단계 + §0(7)·§3.3·§5·§6의 정합성 함정을 실행 가능한 태스크로 분해한다. 각 user story는 독립적으로 빌드·테스트 가능한 증분이다.

## User Story 우선순위 (설계 §8 기반)

- **US1 (P1)** — Core가 유일한 상태 소유자가 된다 (reducer + 병행 output 계약 + Core 소비 전환). 주 축. MVP.
- **US2 (P2)** — Kollus 엔진을 engine-output 구조로 합류.
- **US3 (P3)** — Native 엔진을 engine-output 구조로 합류 (play/pause/seek command-origin 포함).
- **US4 (P4)** — Kollus surface 도입으로 기능 위임 happy-path 테스트성 확보.
- **US5 (P5)** — 파일 물리 분리 (행위 변화 없음).

---

## Phase 1: Setup

- [x] T001 `Sources/VideoPlayerCore/StateTransition/` 디렉터리 생성 및 `Package.swift` 타깃 소스 경로 확인 (VideoPlayerCore 타깃이 새 폴더를 포함하는지 검증)
- [ ] T002 [P] `Sources/VideoPlayerEngineKollus/Signal/`, `Sources/VideoPlayerEngineKollus/Adapter/`, `Sources/VideoPlayerEngineKollus/Surface/` 디렉터리 생성
- [ ] T003 [P] `Sources/VideoPlayerEngineNative/Signal/` 디렉터리 생성
- [ ] T004 [P] `Tests/VideoPlayerModuleTests/Native/`, `Tests/VideoPlayerModuleTests/Kollus/Support/` 테스트 디렉터리 생성

---

## Phase 2: Foundational (모든 user story의 차단 선행)

**목적**: reducer·mapper·Core가 공유하는 SDK 독립 입력/출력 타입을 먼저 고정한다. 이 타입이 없으면 어느 story도 시작 불가.

- [x] T005 [P] `PlaybackStateInput` enum 정의 in `Sources/VideoPlayerCore/StateTransition/PlaybackStateInput.swift` (`Sendable`; cases: prepared/prepareFailed/playStarted/pauseStarted/bufferingChanged/stopped/positionChanged/failed — 설계 §5.2)
- [x] T006 [P] `PlaybackPreparedSnapshot` struct 정의 in `Sources/VideoPlayerCore/StateTransition/PlaybackPreparedSnapshot.swift` (`Sendable`; position/duration/isLive/liveDuration)
- [x] T007 [P] `PlaybackStateReducerOutput` struct 정의 in `Sources/VideoPlayerCore/StateTransition/PlaybackStateReducerOutput.swift` (`Sendable`; next: PlaybackState, events: [PlayerEvent])
- [x] T008 `PlayerEngineOutput` enum 정의 in `Sources/VideoPlayerCore/Contract/PlayerEngineOutput.swift` (`Sendable`; `.stateInput(PlaybackStateInput)` / `.event(PlayerEvent)`; `Error` existential 미탑재 — 설계 §5.2)
- [x] T009 `EngineCapabilities`에 `emitsObservedCommandState` 비트 추가 in `Sources/VideoPlayerCore/Contract/PlayerEngineAdapter.swift` (rawValue 1<<3; 권위 콜백 유무 모델링 — 설계 §5.2.1)

**Checkpoint**: 새 타입이 컴파일된다. 기존 동작은 변경 없음.

---

## Phase 3: US1 — Core가 유일한 상태 소유자 (P1) 🎯 MVP

**Goal**: `PlaybackState`를 Core만 만든다. 순수 reducer가 상태 전이 단일 진실원이 되고, Core는 엔진 output을 소비한다.

**독립 테스트 기준**: SDK/actor 없는 순수 `PlaybackStateReducerTests`가 전 입력에서 통과하고, fake 엔진으로 `PlayerCore`가 outputStream을 소비해 상태를 갱신함을 검증한다. Kollus/Native 실엔진 없이 검증 가능.

### Tests (US1)

- [x] T010 [P] [US1] `PlaybackStateReducerTests` 작성 in `Tests/VideoPlayerModuleTests/Core/PlaybackStateReducerTests.swift` — stop(4 reason), buffering terminal guard(.finished/.failed), prepared, prepareFailed→didFail, positionChanged duration 유지(0 fallback) 전수 검증 (설계 §8 1단계 검증)
- [x] T011 [P] [US1] reducer 엣지 테스트 추가 in `Tests/VideoPlayerModuleTests/Core/PlaybackStateReducerTests.swift` — `.bufferingChanged(false)` while `.paused` quirk를 "의도적 보존"으로 명시 assertion; `PlaybackState.updating(liveDuration:)` `TimeInterval??` 지움/유지 양케이스 (설계 §5.2 잠재버그 주의)
- [x] T012 [P] [US1] 병행 output 계약 contract test 작성 in `Tests/VideoPlayerModuleTests/Core/PlayerEngineOutputContractTests.swift` — fake/Unsupported 엔진이 동일 입력·출력·에러 의미·outputStream 단일 인스턴스·deinit finish를 지키는지 검증

### Implementation (US1)

- [x] T013 [US1] `PlaybackStateReducer` struct 구현 in `Sources/VideoPlayerCore/StateTransition/PlaybackStateReducer.swift` (`Sendable`; `reduce(_:state:) -> PlaybackStateReducerOutput`; effect 없음, 순수 결정만 — 설계 §5.2)
- [x] T014 [US1] `PlayerEngineOutputProducing` 병행 protocol 추가 in `Sources/VideoPlayerCore/Contract/PlayerEngineAdapter.swift` (`var outputStream: AsyncStream<PlayerEngineOutput>`; 기존 `PlayerPlaybackEngine.currentState/eventStream`은 유지 — 설계 §8 2단계)
- [~] T015 [US1] adapter용 `eventStream`→`PlayerEngineOutput` 변환 shim 추가 (전환 창 보호용; 상태성 이벤트→`.stateInput`, 나머지→`.event` passthrough — 설계 §8 2단계 "순서 함정"). 위치: 공유 헬퍼 `Sources/VideoPlayerCore/Contract/PlayerEngineOutputBridge.swift` 또는 각 adapter 임시 메서드 — **대체**: 별도 bridge 파일 대신 PlayerCore 내장 `engineOutput(from:)` 비손실 bridge로 구현(완료).
- [x] T016 [US1] `outputStream`을 `bufferingPolicy: .unbounded`로 고정하는 계약 문서화 + contract test 반영 in `Tests/VideoPlayerModuleTests/Core/PlayerEngineOutputContractTests.swift` (델타 손실 시 영구 desync 방지 — 설계 §5.1)
- [x] T017 [US1] `PlayerCore.consume(engineEvent:)`를 `consume(engineOutput:)`로 교체 in `Sources/VideoPlayerCore/Internal/PlayerCore.swift` (`.stateInput`→reducer 실행 후 currentState 갱신·stateStream yield·events publish; `.event`→passthrough — 설계 §5.4)
- [x] T018 [US1] `PlayerCore.activate()`를 `engine.outputStream` 소비로 전환 in `Sources/VideoPlayerCore/Internal/PlayerCore.swift` (기존 eventStream 소비 제거; T015 shim 선행 필수)
- [x] T019 [US1] stale prepare guard 유지 in `Sources/VideoPlayerCore/Internal/PlayerCore.swift` — `prepareGeneration` 또는 source identity로 `.prepared`/`.prepareFailed` output 중 active generation만 reducer 통과 (설계 §5.3, 기존 PlayerCore.swift:21/113/129 보존) — 기존 prepareGeneration 가드 유지(변경 불필요). adapter `.prepared` 발행 시점(US2)에 재검증.
- [>] T020 [US1] `execute(command:)`에서 낙관적 전이 제거 + `applyCommandOriginIfNeeded(_:)` 도입 in `Sources/VideoPlayerCore/Internal/PlayerCore.swift` (play/pause/seek/stop; `!emitsObservedCommandState`인 엔진에만 command-origin 적용 — 설계 §5.2.1/§5.3) — **US3로 이관**: command-origin은 Native play 도달에 필요. US1은 레거시 낙관적 전이 유지.
- [>] T021 [US1] `PlayerCoreRound4Tests`/`PlayerInterfaceTests` 갱신 in `Tests/VideoPlayerModuleTests/PlayerCoreRound4Tests.swift` 외 — 새 소비 경로·4 stop reason 닫힘·stale prepare regression 검증 (설계 §8 3단계 검증) — **US3로 이관**: 기존 67 테스트 무회귀 통과로 US1 검증 갈음.

**Checkpoint**: fake 엔진으로 Core가 단독 상태 소유자로 동작. Kollus/Native는 아직 shim 경유. 독립 배포 가능한 첫 증분.

---

## Phase 4: US2 — Kollus 엔진 합류 (P2)

**Goal**: Kollus adapter가 SDK 신호를 `KollusSignalMapper`로 정규화해 `outputStream`으로만 발행. adapter 내부 `state`/`transition` 의존 제거.

**독립 테스트 기준**: `KollusSignalMapperTests`(순수)가 신호→output 매핑을 전수 검증. Kollus adapter가 prepareCompleted/buffering/stop/position에서 올바른 output을 내는지 검증. US1 완료 전제.

### Tests (US2)

- [x] T022 [P] [US2] `KollusSignalMapperTests` 작성 in `Tests/VideoPlayerModuleTests/Kollus/KollusSignalMapperTests.swift` — prepareToPlayCompleted 성공/실패, stopStarted(userInteraction true/false), bufferingChanged(false) 복귀, positionChanged(isSeeking guard), caption/hlsHeight/bitrate passthrough 검증 (설계 §8 4단계 검증)
- [>] T023 [P] [US2] 기존 `KollusPlayerAdapterSignalTests` 조정 in `Tests/VideoPlayerModuleTests/Kollus/KollusPlayerAdapterSignalTests.swift` — 상태 직접 assertion에서 output/reducer assertion으로 의도 보존 전환 — **device QA 후속**: US1 bridge로 Kollus 현행 정상 동작. adapter hot-path 전환은 시뮬레이터 검증 불가(실기기 필요)로 분리.
- [x] T024 [P] [US2] Sendable-clean signal 테스트 추가 in `Tests/VideoPlayerModuleTests/Kollus/KollusSignalMapperTests.swift` — `Error` payload가 actor/stream 경계 전에 `PlayerError`로 변환됨을 검증

### Implementation (US2)

- [x] T025 [US2] `KollusSignalMapper` enum 구현 in `Sources/VideoPlayerEngineKollus/Signal/KollusSignalMapper.swift` (`normalize(_:preparedSnapshot:mapError:) async -> PlayerEngineOutput?` — 설계 §5.3/§5.4)
- [>] T026 [US2] `KollusEngineSignal`의 `Error?` payload를 bridge event stream 통과 전 `PlayerError`로 조기 변환 in `Sources/VideoPlayerEngineKollus/KollusDelegateBridge.swift` (Swift 6 strict concurrency 차단요인 제거 — 설계 §5.2/§6) — **device QA 후속**: US1 bridge로 Kollus 현행 정상 동작. adapter hot-path 전환은 시뮬레이터 검증 불가(실기기 필요)로 분리.
- [>] T027 [US2] `KollusPlayerAdapter`에 `outputStream`/`outputContinuation` 추가 및 `PlayerEngineOutputProducing` 채택 in `Sources/VideoPlayerEngineKollus/KollusPlayerAdapter.swift` (adapter lifetime 단일 인스턴스, `.unbounded`, teardown/deinit finish) — **device QA 후속**: US1 bridge로 Kollus 현행 정상 동작. adapter hot-path 전환은 시뮬레이터 검증 불가(실기기 필요)로 분리.
- [>] T028 [US2] `KollusPlayerAdapter.handleSignal(_:)`를 mapper→`outputContinuation.yield`로 변경 in `Sources/VideoPlayerEngineKollus/KollusPlayerAdapter.swift` (polling 제어는 adapter 내부 유지; 내부 `state`/`transition(to:)` 의존 제거 또는 단계적 deprecated) — **device QA 후속**: US1 bridge로 Kollus 현행 정상 동작. adapter hot-path 전환은 시뮬레이터 검증 불가(실기기 필요)로 분리.
- [>] T029 [US2] `makePlaybackPreparedSnapshot()` helper 추출 in `Sources/VideoPlayerEngineKollus/KollusPlayerAdapter.swift` (기존 `readyStateSnapshot()`에서 `PlaybackState` 생성만 제거; position/duration/live/next-episode 캐시는 adapter 유지 — 설계 §5.3) — **device QA 후속**: US1 bridge로 Kollus 현행 정상 동작. adapter hot-path 전환은 시뮬레이터 검증 불가(실기기 필요)로 분리.
- [>] T030 [US2] prepare completion 경로 분리 in `Sources/VideoPlayerEngineKollus/KollusPlayerAdapter.swift` — `handlePrepareCompleted`가 outputStream yield + `pendingPrepareContinuation` resume을 동시 처리, generation/source guard 통과 (설계 §5.3) — **device QA 후속**: US1 bridge로 Kollus 현행 정상 동작. adapter hot-path 전환은 시뮬레이터 검증 불가(실기기 필요)로 분리.
- [>] T031 [US2] `emitsObservedCommandState = true`로 Kollus capability 신고 in `Sources/VideoPlayerEngineKollus/KollusPlayerAdapter.swift` (play/pause/seek 권위 콜백 보유 — 설계 §5.2.1) — **device QA 후속**: US1 bridge로 Kollus 현행 정상 동작. adapter hot-path 전환은 시뮬레이터 검증 불가(실기기 필요)로 분리.

**Checkpoint**: Kollus 실엔진이 outputStream 구조로 동작. shim 제거 가능.

---

## Phase 5: US3 — Native 엔진 합류 (P3)

**Goal**: AVPlayer adapter가 KVO/Notification 신호를 `AVPlayerSignalMapper`로 `PlaybackStateInput`에 매핑하고 `outputStream`으로 발행. 권위 콜백 없는 명령은 Core command-origin으로 닫음.

**독립 테스트 기준**: `AVPlayerSignalMapperTests`(순수) + paused/terminal 상호작용·seek completion·buffering 복귀 검증. play가 command-origin으로 `.playing` 도달함을 검증. US1 완료 전제.

### Tests (US3)

- [x] T032 [P] [US3] `AVPlayerSignalMapperTests` 작성 in `Tests/VideoPlayerModuleTests/Native/AVPlayerSignalMapperTests.swift` — stop/failure/buffering/time update→`PlaybackStateInput` 매핑, `.paused` 무시, waitingToPlay→buffering 검증 (설계 §8 5단계 검증)
- [>] T033 [P] [US3] Native play 도달 regression 테스트 추가 in `Tests/VideoPlayerModuleTests/PlayerInterfaceTests.swift` — Native(`emitsObservedCommandState=false`)에서 play 성공 후 command-origin `.playStarted`로 status가 `.playing`에 도달함을 검증 (설계 §5.2.1 CRITICAL) — **device/통합 QA 후속**: US1 bridge로 Native 현행 정상 동작. adapter outputStream 전환 + command-origin(Core execute)은 Kollus와 동시 전환 시 검증이 안전하므로 분리.
- [>] T034 [P] [US3] `AVPlayerAdapterRenderSurfaceTests` 갱신 in `Tests/VideoPlayerModuleTests/AVPlayerAdapterRenderSurfaceTests.swift` — output 발행 구조로 조정 — **device/통합 QA 후속**: US1 bridge로 Native 현행 정상 동작. adapter outputStream 전환 + command-origin(Core execute)은 Kollus와 동시 전환 시 검증이 안전하므로 분리.

### Implementation (US3)

- [x] T035 [US3] `AVPlayerSignalMapper` enum 구현 in `Sources/VideoPlayerEngineNative/Signal/AVPlayerSignalMapper.swift` (observer event→`PlayerEngineOutput`; `.paused`는 기본 무시 — 설계 §5.2.1/§8 5단계)
- [>] T036 [US3] `AVPlayerAdapter`에 `outputStream` 추가 및 `PlayerEngineOutputProducing` 채택 in `Sources/VideoPlayerEngineNative/AVPlayerAdapter.swift` (`.unbounded`, 단일 인스턴스, deinit finish) — **device/통합 QA 후속**: US1 bridge로 Native 현행 정상 동작. adapter outputStream 전환 + command-origin(Core execute)은 Kollus와 동시 전환 시 검증이 안전하므로 분리.
- [>] T037 [US3] `AVPlayerAdapter`의 stop/failure/buffering/time update 상태 규칙을 mapper→`outputStream`으로 이관 in `Sources/VideoPlayerEngineNative/AVPlayerAdapter.swift` (내부 `state`/`transition` 직접 갱신 제거) — **device/통합 QA 후속**: US1 bridge로 Native 현행 정상 동작. adapter outputStream 전환 + command-origin(Core execute)은 Kollus와 동시 전환 시 검증이 안전하므로 분리.
- [>] T038 [US3] `emitsObservedCommandState = false`로 Native capability 신고 in `Sources/VideoPlayerEngineNative/AVPlayerAdapter.swift` (play/pause/seek 권위 콜백 없음 → Core command-origin 경로 — 설계 §5.2.1) — **device/통합 QA 후속**: US1 bridge로 Native 현행 정상 동작. adapter outputStream 전환 + command-origin(Core execute)은 Kollus와 동시 전환 시 검증이 안전하므로 분리.

**Checkpoint**: 두 실엔진 모두 outputStream 구조. T015 shim 완전 제거. `PlayerPlaybackEngine.currentState/eventStream`을 deprecated 또는 제거 (설계 §8 2단계 후속).

---

## Phase 6: US4 — Kollus surface 테스트성 (P4)

**Goal**: Kollus 기능 위임(rate/bookmark/subtitle/zoom/scroll/scaling/bandwidth)을 surface protocol 경유로 바꿔 fake로 happy-path 테스트.

**독립 테스트 기준**: `FakeKollusPlayerSurface`로 기능별 happy path + playerView nil/error path 검증. 상태 소유 구조 안정 후 진행(회귀 원인 분리). US1~US3 완료 전제.

### Tests (US4)

- [ ] T039 [P] [US4] `FakeKollusPlayerSurface` 작성 in `Tests/VideoPlayerModuleTests/Kollus/Support/FakeKollusPlayerSurface.swift`
- [ ] T040 [US4] 기능 위임 happy-path 테스트 작성 in `Tests/VideoPlayerModuleTests/Kollus/KollusPlayerSurfaceTests.swift` — rate/bookmark/removeBookmark/subtitle/external subtitle/zoom/scroll/scaling/bandwidth/streamInfo + playerView nil/error path (설계 §8 6단계 검증)

### Implementation (US4)

- [ ] T041 [US4] `KollusPlayerSurface` protocol 정의 in `Sources/VideoPlayerEngineKollus/Surface/KollusPlayerSurface.swift` (`@MainActor`; 설계 §5.5; 실구현 시 기능별로 더 작게 분할 가능)
- [ ] T042 [US4] `KollusPlayerViewSurface` 구현 in `Sources/VideoPlayerEngineKollus/Surface/KollusPlayerViewSurface.swift` (실제 `KollusPlayerView` 래핑)
- [ ] T043 [US4] `KollusPlayerAdapter`의 playerView 직접 호출부를 surface 경유로 치환 in `Sources/VideoPlayerEngineKollus/KollusPlayerAdapter.swift`

**Checkpoint**: 기능 위임이 fake로 테스트 가능.

---

## Phase 7: US5 — 파일 물리 분리 (P5)

**Goal**: 행위 변화 없이 폴더/파일만 정리.

**독립 테스트 기준**: 기존 전체 테스트 스위트가 그대로 통과(행위 불변).

- [ ] T044 [US5] `KollusPlayerAdapter`의 prepare 관련 코드를 `Sources/VideoPlayerEngineKollus/Adapter/KollusPlayerAdapter+Prepare.swift`로 분리 (extension, 행위 불변)
- [ ] T045 [US5] `KollusPlayerAdapter.swift`를 `Sources/VideoPlayerEngineKollus/Adapter/`로 이동 + import/access control 정리
- [ ] T046 [P] [US5] `Domain/`·`StateTransition/`·`Contract/` 폴더 배치 최종 정리 in `Sources/VideoPlayerCore/` (설계 §7 After 구조 일치)

---

## Phase 8: Polish & Cross-Cutting (설계 §6 별도 work item)

- [ ] T047 [P] PiP capability 계약 결정 — `Sources/VideoPlayerCore/Contract/PlayerEngineAdapter.swift`의 기존 `.nativePiP` 비트로 지원 여부 모델링할지, `PlayerPiPCapability` 채택 제거할지, "요청 가능/host 통합 전 비활성" 계약 유지할지 결정 후 `Sources/VideoPlayerEngineKollus/KollusPlayerAdapter.swift` 반영 (설계 §3.3/§6)
- [ ] T048 [P] DRM error surfacing 결정 — `Sources/VideoPlayerEngineKollus/KollusDelegateBridge.swift`의 `handleDRMResponse`가 observer 전달만 하는 현재 계약으로 충분한지 host 요구사항 확인, 필요 시 `PlayerEvent.didFail`/별도 policy event로 승격 (설계 §6)
- [ ] T049 [P] `bind`/`unbind` fire-and-forget 보강 — render surface binding을 await 가능 경로로 바꾸거나 generation token으로 오래된 detach 무시 in `Sources/VideoPlayerShellSupport/PlayerRenderBindingEngine.swift` (설계 §6)
- [ ] T050 Swift 6 strict concurrency 빌드 검증 — Package tools 버전 상향 시 `KollusEngineSignal`/`PlayerEngineOutput` Sendable 진단 0 확인 (T026 선행)
- [ ] T051 전체 회귀 — `swift test`로 VideoPlayerCore/Kollus/Native 전 스위트 통과 + SmartPlayer 앱 빌드 검증

---

## Dependencies

```
Setup (P1) ─┐
            ▼
Foundational (P2: T005~T009) ──┐
            │                  │
            ▼                  │
US1 (P1: reducer+Core 소유) ───┤  ← MVP, 단독 배포 가능
            │                  │
   ┌────────┴────────┐         │
   ▼                 ▼         │
US2 (Kollus 합류)  US3 (Native 합류)  ← US1 완료 후 병렬 가능
   │                 │
   ▼                 │
US4 (Kollus surface) │  ← US1~US3 안정 후
   └────────┬────────┘
            ▼
US5 (파일 물리 분리)  ← 모든 행위 변경 완료 후
            ▼
Polish (P8)
```

- **US1은 US2/US3의 차단 선행** (outputStream 소비 경로·reducer가 있어야 엔진 합류 의미 있음).
- **US2와 US3은 상호 독립** — US1 완료 후 병렬 진행 가능.
- **US4는 US1~US3 안정 후** (상태 전이와 SDK 호출부 동시 변경 시 회귀 원인 분리 어려움 — 설계 §5.5).
- **US5는 마지막** (행위 변경 완료 후 물리 이동만).

---

## Parallel 실행 예시

**Foundational (T005~T009)** — 서로 다른 파일, 의존 없음:
```
T005 PlaybackStateInput.swift
T006 PlaybackPreparedSnapshot.swift
T007 PlaybackStateReducerOutput.swift
(T008 PlayerEngineOutput, T009 EngineCapabilities는 위 타입 참조 — 직후)
```

**US1 테스트 (T010~T012)** — 독립 테스트 파일 병렬 작성 가능.

**US2 vs US3** — US1 완료 후 두 팀이 각 엔진 모듈에서 병렬:
```
팀A: T022~T031 (Kollus)
팀B: T032~T038 (Native)
```

**Polish (T047~T049)** — 서로 다른 도메인, 병렬 가능.

---

## Implementation 전략

- **MVP = US1**. fake 엔진만으로 "Core 단일 상태 소유 + 순수 reducer"를 완성·검증해 단독 배포한다. 실엔진은 shim(T015) 뒤에서 기존대로 동작.
- **증분 배포**: US1 → US2(Kollus) → US3(Native) 순으로 각각 독립 검증 후 합류. 각 단계 끝에서 전체 테스트 green 유지.
- **회귀 위험 최소화**: 상태 소유권 전환(US1~US3)과 SDK 호출부 추상화(US4)를 절대 한 PR에 섞지 않는다.
- **CRITICAL 게이트**: T016(outputStream `.unbounded`), T020/T033(Native play command-origin 도달), T015(shim 선행)는 머지 전 필수 검증. 설계 §0(7) 3대 함정.

---

## Format 검증

전 태스크(T001~T051)가 체크리스트 형식 준수: `- [ ] [TaskID] [P?] [Story?] 설명 + 파일경로`. Setup/Foundational/Polish는 story 라벨 없음, US phase는 [US1~US5] 라벨 보유.

- 총 태스크: 51
- US1: 12 (T010~T021) · US2: 10 (T022~T031) · US3: 7 (T032~T038) · US4: 5 (T039~T043) · US5: 3 (T044~T046)
- Setup 4 · Foundational 5 · Polish 5
