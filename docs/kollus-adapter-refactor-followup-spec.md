# 후속 작업 spec: adapter outputStream 전환 (A 작업)

> 작성: 모바일개발팀_정준영 · 2026-06-04
> 선행: [kollus-adapter-refactor-architecture.md](kollus-adapter-refactor-architecture.md) (설계), [kollus-adapter-refactor-tasks.md](kollus-adapter-refactor-tasks.md) (태스크)
> 대상 실행자: Kollus/Native adapter 내부와 실기기 QA 환경을 모두 다룰 수 있는 개발자
> 상태: **미착수 / device QA 필수**

---

## 0. 왜 분리됐나

US1~US3에서 다음은 완료·검증됐다.

- `PlaybackStateReducer`(순수)가 상태 전이 단일 진실원.
- `PlayerCore`가 `PlayerEngineOutput`을 소비해 reducer로 상태를 만든다.
- 미전환 엔진은 `PlayerCore.engineOutput(from:)` **비손실 bridge**로 그대로 동작.
- `KollusSignalMapper`, `AVPlayerSignalMapper`(순수) + 단위 테스트.
- iOS sim 회귀 208 통과.

남은 A 작업은 **adapter가 직접 `outputStream`을 발행하고 내부 상태머신을 버리는 것**이다. 이것은:

1. 1085줄 Kollus adapter / Native adapter의 hot-path를 바꾼다.
2. `PlayerCore.execute()`의 command-origin 변경이 **두 엔진 모두**에 영향을 준다.
3. 실제 SDK(`KollusSDKBinary`, AVPlayer) 재생 동작은 시뮬레이터로 검증 불가 — 실기기 필요.

따라서 순수 매퍼(검증 완료)를 빌딩블록으로, **두 엔진을 한 PR에서 동시 전환**하고 device QA로 닫는다.

---

## 1. 불변 조건 (전환 전후 동일해야 함)

전환은 행위 보존이 목표다. reducer가 기존 `consume`/`handleSignal` 로직과 등가임은 `PlaybackStateReducerTests`로 입증됐다. 추가로 다음을 깨면 안 된다.

- **prepare await 계약**: `prepare(source:)`는 prepare 완료/실패까지 suspend하고 결과를 throw로 전달한다. (`pendingPrepareContinuation`)
- **prepareGeneration 가드**: 더 새로운 `start`가 끼어들면 이전 source의 늦은 `.prepared`/`.prepareFailed`가 새 상태를 덮어쓰지 않는다. (PlayerCore.swift:21/113/129)
- **position polling**: Kollus는 재생 중 주기 통지가 없어 0.5s 폴링으로 `timeDidChange`를 만든다. playStarted 시작 / pause·stop 중지.
- **next-episode 1회 emit**: `readyStateSnapshot`에서 메타 캐시 + 플래그 리셋, positionChanged hot-path에서 산술 비교만.
- **단일 FIFO 소비**: bridge 신호는 단일 consumer가 순서대로 처리(상태 역전 방지).
- **terminal guard**: `.finished`/`.failed`는 늦은 buffering/paused로 되살아나지 않는다.

---

## 2. Core 변경 (T020/T033) — 두 엔진 공통, 먼저

### 2.1 `execute(command:)` command-origin

현재 play/pause/seek/seekWithOrigin/stop은 명령 성공 후 무조건 낙관적 `transition`을 한다. 전환 후:

- 권위 콜백이 있는 엔진(`emitsObservedCommandState == true`, Kollus): 낙관적 전이 **제거**. 상태는 outputStream의 `.stateInput`이 만든다.
- 권위 콜백이 없는 엔진(`== false`, Native): Core가 명령 성공 직후 command-origin `PlaybackStateInput`을 reducer에 넣는다.

```swift
// PlayerCore
private func applyCommandOriginIfNeeded(_ input: PlaybackStateInput) {
    guard !engineCapabilities.contains(.emitsObservedCommandState) else { return }
    apply(stateReducer.reduce(input, state: currentState))
}

// execute(command:) 내부
case .play:
    try await executeEngineCommand { try await engine.play() }
    applyCommandOriginIfNeeded(.playStarted)
case .pause:
    try await executeEngineCommand { try await engine.pause() }
    applyCommandOriginIfNeeded(.pauseStarted)
case .seek(let time):
    try await executeEngineCommand { try await engine.seek(to: time) }
    applyCommandOriginIfNeeded(.positionChanged(time: time, duration: nil))
case .seekWithOrigin(let time, let origin):
    let target = seekTargetTime(for: time, origin: origin)
    try await executeEngineCommand { try await engine.seek(to: target) }
    applyCommandOriginIfNeeded(.positionChanged(time: target, duration: nil))
case .stop:
    pendingPrepareTask?.cancel(); pendingPrepareTask = nil
    try await executeEngineCommand { try await engine.stop(reason: .userClosed) }
    currentSource = nil
    apply(stateReducer.reduce(.stopped(.userClosed), state: currentState))  // stop은 양쪽 멱등
```

> ⚠️ **이벤트 의미 변화**: 현재 seek는 `transition(emitEvent: true)`로 `stateDidChange`를 발행한다. command-origin `.positionChanged`는 `timeDidChange`를 발행한다(`stateDidChange` 아님). seek 후 이벤트를 구독하는 호출자(skin/shell)가 있는지 확인하고, 있으면 `timeDidChange`로 충분한지 검증.

### 2.2 검증

- `PlayerCoreRound4Tests`, `PlayerInterfaceTests`, `PlayerCoreCommandCoverageTests`를 새 의미로 갱신.
- **신규 regression**: `emitsObservedCommandState=false` fake로 play 성공 → status `.playing` 도달 검증. `=true` fake로 play 성공 후 outputStream `.playStarted` 전까지 `.playing` 미도달 검증.

---

## 3. Kollus 전환 (T026~T031)

### 3.1 outputStream 추가 + 채택 (T027)

```swift
public final actor KollusPlayerAdapter: ..., PlayerEngineOutputProducing {
    public let outputStream: AsyncStream<PlayerEngineOutput>
    private let outputContinuation: AsyncStream<PlayerEngineOutput>.Continuation
    // init: AsyncStream(bufferingPolicy: .unbounded) — 단일 장수명 인스턴스
    // deinit: outputContinuation.finish()
}
```

`eventStream`/`currentState`는 전환 기간 deprecated로 남긴다(병행 계약). Core는 `PlayerEngineOutputProducing` 채택을 감지해 outputStream을 소비한다(이미 구현됨, PlayerCore.activate).

### 3.2 capability (T031)

```swift
nonisolated static let capabilities: EngineCapabilities = [.continuesWithoutSurface, .emitsObservedCommandState]
```

### 3.3 handleSignal → mapper (T028)

부수효과(polling/prepare/next-episode)는 adapter에 남기고, 상태/이벤트 발행만 mapper→outputStream으로 옮긴다.

```swift
func handleSignal(_ signal: KollusEngineSignal) async {
    // 1) 부수효과 (상태 무관)
    switch signal {
    case .playStarted(_, nil):                 startPositionPolling()
    case .pauseStarted(_, nil), .stopStarted:  stopPositionPolling()
    case .positionChanged(let time, false):    emitNextEpisodeIfNeeded(currentTime: time)
    default: break
    }

    // 2) prepare는 await 계약 때문에 별도 경로 (3.4)
    if case .prepareToPlayCompleted(let error) = signal {
        await handlePrepareCompleted(error: error)
        return
    }

    // 3) 나머지는 mapper → outputStream
    guard let output = await KollusSignalMapper.normalize(
        signal,
        preparedSnapshot: { await self.makePlaybackPreparedSnapshot() },
        mapError: { self.playerError(from: $0, operation: $1) }
    ) else { return }
    outputContinuation.yield(output)
}
```

> 내부 `state` / `transition(to:)` / `publish(event:)`(eventStream) 의존을 제거한다. adapter가 SDK 조회용으로 position을 캐시해야 하면 별도 경량 필드를 두되, **권위 상태는 Core**다.

### 3.4 prepare completion 분리 (T030)

```swift
private func handlePrepareCompleted(error: Error?) async {
    guard let output = await KollusSignalMapper.normalize(
        .prepareToPlayCompleted(error: error),
        preparedSnapshot: { await self.makePlaybackPreparedSnapshot() },
        mapError: { self.playerError(from: $0, operation: $1) }
    ) else { return }

    outputContinuation.yield(output)   // Core가 generation/source guard로 stale 억제

    switch output {
    case .stateInput(.prepared):                completePendingPrepare(with: .success(()))
    case .stateInput(.prepareFailed(let e)):    completePendingPrepare(with: .failure(e))
    default: break
    }
}
```

> **generation guard 위치 결정**: outputStream `.prepared`가 stale일 때 Core가 무시해야 한다. 두 옵션 — (1) Core가 `start(source:)`마다 generation 증가, output 소비 시 active generation의 prepared만 reducer 통과. (2) `PlaybackStateInput.prepared`에 source identity 첨부. **(1) 권장** — 기존 `prepareGeneration` 재사용. 이 가드를 반드시 추가(현재는 start() task 결과에만 적용되고 stream prepared에는 미적용 — US1 bridge에선 readyToPlay가 stateDidChange로 와서 문제 없었으나, `.prepared` stateInput 전환 후엔 필요).

### 3.5 makePlaybackPreparedSnapshot (T029)

기존 `readyStateSnapshot()`에서 **`PlaybackState` 생성만 제거**하고 `PlaybackPreparedSnapshot`을 반환. next-episode 메타 캐시 + `hasEmittedNextEpisode` 리셋 부수효과는 유지.

```swift
private func makePlaybackPreparedSnapshot() async -> PlaybackPreparedSnapshot {
    let snap = await MainActor.run { /* 기존 ReadySnapshot 조회 그대로 */ }
    hasEmittedNextEpisode = false
    nextEpisodeMeta = (snap.nextEpisodeShowAt > 0) ? NextEpisodeMeta(...) : nil
    let liveDuration: TimeInterval? = snap.liveDuration > 0 ? snap.liveDuration : nil
    return PlaybackPreparedSnapshot(
        position: snap.position, duration: snap.duration,
        isLive: snap.isLive, liveDuration: liveDuration
    )
}
```

### 3.6 Error Sendable-clean (T026)

`KollusEngineSignal`의 `Error?` payload는 `KollusDelegateBridge`가 bridge event stream에 yield하기 **전에** `PlayerError`로 변환한다. 그래야 actor/stream 경계 밖으로 non-Sendable `Error`가 나가지 않는다. (Swift 6 strict concurrency 차단요인 — 설계 §6) 매퍼의 `mapError`만으로는 늦으므로 bridge 단에서 조기 변환.

---

## 4. Native 전환 (T036~T038)

### 4.1 outputStream + 채택 (T036) / capability (T038)

```swift
public final actor AVPlayerAdapter: ..., PlayerEngineOutputProducing {
    public let outputStream: AsyncStream<PlayerEngineOutput>  // .unbounded, deinit finish
    nonisolated static let capabilities: EngineCapabilities = [/* 기존 */]  // emitsObservedCommandState 미포함 = false
}
```

### 4.2 observer → mapper (T037)

`ObserverEvent`를 `AVPlayerSignal`로 매핑해 `AVPlayerSignalMapper.normalize` → outputStream.

```swift
// observer consumer
case .itemFailed(let e), .failedToEnd(let e): yield(.failed(e))
case .timeControl(let s):                     yield(.timeControl(s))
case .didFinish:                              yield(.didFinish)
case .periodicTime(let sec):                  yield(.periodicTime(seconds: sec))
// where yield(x) = if let o = AVPlayerSignalMapper.normalize(x) { outputContinuation.yield(o) }
```

prepare/play/pause/seek는 observer가 아니라 명령 결과다 → outputStream으로 보내지 **않는다**. Core command-origin(`emitsObservedCommandState=false`)이 닫는다.

> ⚠️ **`.playing` 이벤트 차이**: 현재 `handleTimeControlStatus(.playing)`은 `state.isBuffering`일 때만 buffering-off를 emit한다. mapper는 무조건 `.bufferingChanged(false)`를 만든다 → reducer가 매번 `bufferingDidChange(false)` 발행. 버퍼링 아닐 때 잉여 이벤트가 생긴다. 무해하다고 판단되면 수용, 아니면 adapter에서 직전 buffering 여부 가드 후 yield.

### 4.3 prepare 상태

현재 Native `prepare`는 `transition(to: readyToPlay)`로 직접 상태를 만든다. 전환 후엔 prepare 성공 시 adapter가 `outputContinuation.yield(.stateInput(.prepared(snapshot)))`. duration은 `waitUntilReady`에서 이미 알고 있으므로 스냅샷에 채운다.

---

## 5. 작업 순서

```
1. Core (§2)  — command-origin + fake regression. sim 검증 가능.
2. Native (§4) — AVFoundation은 sim 검증 비교적 용이. command-origin 경로 확인.
3. Kollus (§3) — 실기기 필수.
4. 전체 device QA (§6).
```

Core(1)와 Native(2)는 시뮬레이터에서 상당 부분 검증된다. Kollus(3)만 실기기. 단, command-origin(1)은 두 엔진 capability 신고가 끝나야 일관 동작하므로, 1~3을 한 PR로 묶되 위 순서로 빌드/검증.

---

## 6. Device QA 체크리스트 (실기기)

전환 후 **실기기**에서 확인. 시뮬레이터로 대체 불가.

### Kollus
- [ ] 일반 강의 재생 시작 → `.playing` 도달, 재생바 currentTime 0.5s 갱신
- [ ] pause/resume → 상태·재생바 정확, polling 중지/재개
- [ ] seek (scrubber/skip) → 위치 점프, 잉여 상태 이벤트 없음
- [ ] 영상 종료 → `.finished` + didFinish 1회
- [ ] 다음 회차 진입 시간 도달 → nextEpisodeAvailable **1회만**
- [ ] 강의 연속 전환(다음강의 버튼/자동전환) → 이전 source 늦은 prepared가 새 상태 안 덮음 (generation guard)
- [ ] 동일 source 중복 load coalesce (ResCode 23/42 충돌 없음)
- [ ] DRM 보호 컨텐츠 재생 + DRM 실패 경로
- [ ] 백그라운드 전환/복귀 (`.appLifecycle` stop)
- [ ] 자막 on/off, 외부 자막, 배속, 북마크 추가/삭제, 줌/스크롤, 화질(bandwidth)
- [ ] 재진입(viewWillDisappear→재진입) 크래시 없음, playerView teardown

### Native (AVPlayer url source)
- [ ] 재생/일시정지/seek → command-origin으로 `.playing`/`.paused`/위치 정확
- [ ] 버퍼링(waiting) → `.buffering`, 재개 시 복귀
- [ ] 종료 → `.finished`
- [ ] stop/finish 후 늦은 paused가 상태 안 되살림 (`.paused` 무시 확인)

### 공통
- [ ] `swift test` + iOS sim 전체 스위트 무회귀
- [ ] outputStream이 burst(빠른 position/buffering)에서 입력 누락 없음 (.unbounded)

---

## 7. 롤백 전략

- 각 엔진 전환은 capability 신고(`emitsObservedCommandState`) + `PlayerEngineOutputProducing` 채택 여부로 격리된다.
- 문제 발생 시 해당 adapter의 `PlayerEngineOutputProducing` 채택만 제거하면 Core가 자동으로 **eventStream 비손실 bridge** 경로로 폴백(US1 구조) → 즉시 현행 동작 복귀.
- 즉, Kollus만 롤백 / Native만 롤백이 독립적으로 가능. 한 엔진 회귀가 다른 엔진을 막지 않는다.

---

## 8. 완료 기준 (DoD)

- 두 adapter 모두 `PlayerEngineOutputProducing` 채택, 내부 권위 상태머신 제거.
- `PlayerCore.execute()` command-origin 적용, capability 기반 분기.
- bridge(`engineOutput(from:)`)는 폴백 경로로만 남음(또는 더 이상 필요 없으면 제거 검토).
- §6 device QA 전 항목 통과.
- `KollusEngineSignal` Error payload가 경계 밖으로 안 나감(Sendable-clean) → tools 6 상향 시 진단 0(T050).
