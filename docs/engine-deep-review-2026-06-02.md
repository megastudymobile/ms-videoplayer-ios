# 엔진 심층 검토 리포트 — videoplayer-ios-ms

- 작성자: 모바일팀_정준영
- 작성일: 2026-06-02
- 검토 방식: 멀티에이전트 병렬 읽기 전용 검토 (생명주기/리소스 · 동시성 · 에러·상태·커맨드 · DRM·PiP·세션·capability·보안)
- 검증: KollusSDK 헤더 + 레거시 ObjC 플레이어(`MegaKollus`/`MegaStudy`/`SLKollusManager`) 2차 대조 (2026-06-02)
- 호스트: smartlearning-ios-ms PlayerModule (Clean Architecture)
- 검토 대상 브랜치: `feature/player-module-refactor/origin`

> 모든 발견은 인용된 코드 라인으로 검증했다. 단정 불가한 부분(vendor 바이너리 내부 등)은 명시했다. 코드는 변경하지 않았다.
> **2차 검증 반영**: KollusSDK 헤더 및 레거시 ObjC 플레이어와 대조해 SDK API명/매직넘버 의미/레거시 동작 서술을 정정했다(§7 참조). 정정 항목은 본문에 `[정정]`/`[검증]`으로 표기.

---

## 0. 요약 — 두 가지 뿌리 원인

대부분의 HIGH 결함이 아래 두 구조적 결핍에서 파생된다.

- **(A) 명시적 상태머신 가드 부재** — `PlayerCore.transition(to:)`는 어떤 상태→어떤 상태든 무조건 덮어쓴다. 전이 가드가 없어 idle/failed에서의 커맨드 수용, 취소 후 `.preparing` 잔류, terminal 상태 역전, stale 완료 누출이 모두 여기서 파생된다. (H4·H5·H6·H7)
- **(B) 정의만 되고 실경로에서 안 쓰이는 추상화** — `PlayerError`의 network/auth/decoding 케이스, `EngineCapabilities`/PiP capability가 정의되어 있으나 실제 매핑·소비 경로가 없다. 에러는 전부 `.unknown`/`.engineError`로 평탄화되고, capability는 실동작과 어긋난다. (H3·H8·H9)

가장 효과적인 수정 순서는 §6 권장 묶음 참조.

---

## 1. CRITICAL / HIGH

### H1 — 신호 순서 역전 (Task-per-signal)
- 심각도: **HIGH**
- 파일: `Sources/VideoPlayerEngineKollus/KollusPlayerAdapter.swift:466-476` (`onSignal`/`onBookmarks`), `Sources/VideoPlayerEngineNative/AVPlayerAdapter.swift:226-283` (KVO 핸들러)
- 현상: SDK delegate 콜백(MainActor 순차 도착)을 받는 `onSignal`이 **매 신호마다 새 `Task { await self?.handleSignal(signal) }`** 를 생성한다. 분리된 unstructured Task는 actor 실행 순서를 보장하지 않는다. `positionChanged → stopStarted`를 연속 발행해도 actor 도달 순서가 비결정적 → 정지 후 위치 갱신이 뒤집혀 잘못된 상태가 publish된다.
  ```swift
  onSignal: { signal in
      Task { [weak self] in
          await self?.handleSignal(signal)   // actor 도달 순서 비보장
      }
  }
  ```
- AVPlayer 측도 동일: `statusObservation`/`timeControlObservation`(KVO, 임의 스레드)와 periodic observer(main queue) 이벤트가 각자 `Task { await self.handle… }`로 actor에 진입 → 인터리브로 `handleTimeControlStatus(.playing)`과 `handlePeriodicTimeUpdate` 순서 역전.
- 수정 방향: 어댑터별 단일 `AsyncStream<KollusEngineSignal>`(및 AVPlayer 이벤트 스트림)로 수렴. 콜백은 (MainActor에서) continuation에 **동기 yield**만 하고, adapter가 `for await`로 단일 Task에서 순차 소비 → FIFO 보장.
- ROI: **최고** (순서역전 클래스 버그 일괄 제거).

### H2 — legacy prepare 완료 미대기 (조기 `.readyToPlay`)
- 심각도: **HIGH**
- 파일: `KollusPlayerAdapter.swift:565-599` (legacy), 대비 `:522-555` (bootstrapped)
- 현상: legacy 경로는 `prepareToPlay(withMode:)` 호출 직후 **동기적으로 `.readyToPlay`** 를 만들어 반환한다. **[정정]** Kollus `prepareToPlayWithMode:error:`는 동기 `BOOL` 반환(준비 *시작* 성공/실패만, `KollusPlayerView.h:196`)이고, 재생 준비 *완료*는 별도 비동기 delegate `kollusPlayerView:prepareToPlayWithError:`(`KollusPlayerDelegate.h:20`)로 통지된다. (초판이 SDK 콜백을 "`prepareToPlayWithError`(`prepareToPlayCompleted`)"로 병기했으나 `prepareToPlayCompleted`는 SDK API가 아니라 엔진 내부 `KollusEngineSignal.swift:13` case명 — 두 출처 혼용 정정.) bootstrapped 경로는 `installPrepareContinuation` + delegate 완료 대기로 이 계약을 지키지만(주석 `:522-524`), legacy 경로는 이를 위반한다. 준비 실패해도 `.readyToPlay`로 보고된 뒤, 늦게 도착하는 실패 delegate는 legacy 경로에 bridge wiring이 없어 수신조차 안 된다.
- **[검증] 레거시는 이 계약을 정확히 지킴** — `MegaKollusMoviePlayerController.m:355-361`의 동기 반환값은 "준비 시작" 여부일 뿐, 실제 준비 완료는 delegate `prepareToPlayWithError:`(`:941-965`)에서 통지되고, `MegaStudyMoviePlayerController.m`의 `didCompletePreparationToPlay:`(`:5325`) → `completePreparationToPlay`(`:2832`) → `[self play]`(`:2913`)로 **준비 완료 후에만 play**한다. 즉 레거시 = bootstrapped 경로와 동일 계약. 신규 엔진 legacy 경로만 이탈.
- 영향: autoplay가 SDK 준비 완료 전에 `play()`를 호출. legacy init이 test-only 표기라도 동작 차이는 유지보수 위험.
- 수정 방향: legacy도 bootstrapped와 동일하게 continuation + delegate 완료 대기로 통일(레거시 ObjC 패턴이 레퍼런스).

### H3 — `mapToPlayerError` dead code + 에러 미분류
- 심각도: **HIGH**
- 파일: `Sources/VideoPlayerCore/Internal/PlayerCore.swift:419-425`, `KollusPlayerAdapter.swift:880-885`
- 현상:
  ```swift
  private func mapToPlayerError(_ error: Error) -> PlayerError {
      if let playerError = error as? PlayerError { return playerError }
      return .unknown((error as NSError).localizedDescription)
  }
  ```
  `PlayerError`가 아닌 모든 에러(URLError, DRM 인증 실패, 디코딩 실패)가 무조건 `.unknown`. `PlayerError`에 `networkError/authenticationFailed/decodingError` 케이스가 있는데 매퍼가 전혀 활용 못 함. 게다가 Kollus prepare/play/stop 실패 경로(`:608, :623, :628, :653, :671`)는 전부 `.engineError("…: \(error.localizedDescription)")`로만 감싸 **`mapToPlayerError`를 단 한 번도 호출하지 않는다**(사실상 dead code). 네트워크/DRM/인증 에러를 UI에서 구분 불가.
- 수정 방향: NSError domain(NSURLErrorDomain 등)·code 기반 분류 매핑 추가, Kollus 실패 경로도 매퍼 경유로 일관화.

### H4 — prepare 취소 시 `.preparing` 잔류
- 심각도: **HIGH**
- 파일: `PlayerCore.swift:94, 109-112`
- 현상: `start()` 진입 시 `.preparing` 전이 후, prepare가 취소되면(`.stop` 또는 연속 `.load`로 `pendingPrepareTask?.cancel()`) `catch is CancellationError` 블록이 상태를 복원하지 않는다.
  ```swift
  transition(to: currentState.updating(status: .preparing, ...))   // L94
  ...
  } catch is CancellationError {
      if pendingPrepareTask?.isCancelled == true { pendingPrepareTask = nil }
      // ← .idle 복원 없음. .preparing 잔류
  }
  ```
  트리거가 `.stop`이면 이후 `.idle`로 덮여 가려지지만, 연속 `.load`로 취소된 경우엔 두 번째 start가 다시 `.preparing`을 써서 우연히 가려질 뿐 — 깨끗한 idle 복원 보장 없음.
- 수정 방향: `catch is CancellationError`에서 `transition(to: .idle)` 명시.

### H5 — `pendingPrepareTask` race (동일성 비교 부재)
- 심각도: **HIGH**
- 파일: `PlayerCore.swift:102-112`
- 현상:
  ```swift
  pendingPrepareTask = task
  do {
      try await task.value
      if pendingPrepareTask?.isCancelled == false { pendingPrepareTask = nil }
  }
  ```
  `task.value` await 중 actor 재진입으로 다른 `start()`/`.stop()`이 `pendingPrepareTask`를 새 task로 교체할 수 있다. await 복귀 후 검사가 "내가 만든 task"가 아닌 "현재 멤버 변수"를 보므로, **진행 중인 새 task를 nil로 날린다**. 이후 cleanup 이중 실행 등 추적 불능.
- 수정 방향: 로컬 `task`와 `pendingPrepareTask`의 **`===` 동일성** 비교 후 자기 자신일 때만 nil 처리. generation 토큰 병행 권장(H7과 공통).

### H6 — 상태 전이 가드 전무
- 심각도: **HIGH**
- 파일: `PlayerCore.swift:245-252`(`transition`), `:203-243`(`consume`), seek 무시 `KollusPlayerAdapter.swift:135-143`
- 현상: `transition(to:)`가 가드 없이 무조건 덮어쓴다.
  - `.idle`에서 `seek`/`play`/`pause` 명령이 그대로 엔진 전달. play/pause는 `playerView == nil`이면 throw하지만, **seek는 `playerView?.currentPlaybackTime`을 옵셔널 체이닝으로 조용히 무시하고도 `.timeDidChange`를 emit**하고 currentTime을 갱신 → idle에서 가짜 시간 이벤트.
  - `.failed` 상태에서도 모든 명령 수용.
- 수정 방향: status별 허용 커맨드 가드 테이블 도입, 부적합 전이는 무시 또는 명시적 에러.

### H7 — 연속 `.load` 시 stale 실패 이벤트 누출
- 심각도: **HIGH**
- 파일: `PlayerCore.swift:91-119`, `execute(.load):124-125`
- 현상: `.load`는 `start()` 호출, `start()`는 진입 즉시 `pendingPrepareTask?.cancel()`로 이전 prepare를 취소한다. 하지만 첫 `start()`는 여전히 `await task.value` 중. 취소된 task가 `CancellationError`가 아닌 다른 에러로 끝나면(예: continuation이 cancel resume 전에 `prepareToPlay`가 다른 에러 throw) 첫 start의 catch가 `.failed` 전이 + `didFail` emit + throw. 두 번째 load가 성공해도 첫 load의 실패 이벤트가 뒤늦게 흘러 **UI가 에러로 깜빡임**.
- 수정 방향: 세대(generation) 토큰으로 stale 완료 무시 (H5·H4와 복합).

### H8 — capabilities vs 실동작 불일치 (배경재생)
- 심각도: **HIGH**
- 파일: `KollusPlayerAdapter.swift:27`, factory `KollusPlayerModuleFactory.swift:36-40`, `applyEffectivePolicy:258-276`
- 현상: `static let capabilities: EngineCapabilities = []`라 `continuesWithoutSurface` 미보유 → 배경재생 정책이 항상 다운그레이드(`:263`)되어 `policyDowngraded` 이벤트를 쏜다. 그런데 어댑터는 `environment.audioBackgroundPlayPolicy`(`:511`)로 실제 배경 오디오 재생을 켠다. **정책 레이어는 "배경재생 불가"로 다운그레이드하는데 엔진은 배경재생을 수행** — 정반대.
- **[검증] 레거시 대조**: 레거시는 capability 추상화 없이 `playerSetting.backgroundPlayMode` **단일 진실원**으로 `setAudioBackgroundPlay:`(SDK, `MegaStudy…:2840`)와 `AVAudioSessionCategoryPlayback`(`:3509`)을 직접 연동. 정책 모순 없음. 신규가 이식할 모델.
- 수정 방향: capabilities를 실제 환경/기능에 맞게 채우거나 audioBackgroundPlay와 정책을 연동(레거시 단일 진실원 패턴).

### H9 — PiP 죽은(orphaned) 기능
- 심각도: **HIGH**
- 파일: `KollusPlayerAdapter.swift:26-27, 353-385`, `Sources/VideoPlayerCore/Contract/PlayerEngineAdapter.swift:24, 94-98`
- 현상:
  1. `PlayerPiPCapability`를 채택하지만 `capabilities = []`라 `.nativePiP`가 절대 안 켜진다(`:27`).
  2. `PlayerCore`/`PlayerLifecycleCoordinator` 어디에서도 `.nativePiP`/`startPiP`/`isPiPActive`를 참조하지 않는다(코어 grep 사용처 0).
  3. `startPiP()`/`stopPiP()`는 실제 PiP를 시작하지 않고 `isPiPRunning` 내부 플래그만 토글 후 `.policyDowngraded(... "host AVPictureInPictureController 통합 필요")` 이벤트만 발행(`:362-379`). `AVPictureInPictureController`는 엔진/코어 어디에도 없음.
- 영향: `isPiPActive`가 실제 PiP 상태가 아닌 호출 여부만 반영 → 호출자 오도. capability 질의로 PiP 지원 판별 불가.
- 수정 방향: (a) 미지원이면 `PlayerPiPCapability` 채택 제거, 또는 (b) host AVPictureInPictureController 통합 인터페이스 정의 + Native 엔진에서 `AVPlayerLayer` 기반 실구현(`AVPlayerAdapter`가 `playerLayer` 보유라 가장 적합).

### H10 — proxy teardown 타이머 race 잔존
- 심각도: **HIGH**
- 파일: `KollusPlayerAdapter.swift:452-459`(bootstrapped), `:566-570`(legacy), `:835-844`(performStop); 호출측 `LecturePlayerCoordinator.swift:685-690`
- 현상: 코드 주석(`:452-454`)이 명시하는 알려진 크래시 — 이전 playerView를 stop 없이 폐기하면 `KollusProxyPlayerView`의 `releaseServerAndStop`(NSTimer)가 해제 메모리에서 발화해 크래시. 현재 방어는 prepare 재진입/정상 stop에서 `playerView.stop()` 선행. **잔존 race**:
  - `try? previous.stop()`(`:456`, `:568`)이 **에러를 무시**. stop 실패 시 proxy 타이머 활성인 채 view 폐기 → 동일 크래시 재현 가능.
  - 비정상 종료 경로(`.stop` 누락 + dispose/dealloc만)에서 `performStop`의 `playerView.stop()` 미호출 → 타이머가 dealloc 타이밍에 발화.
  - adapter `deinit`(`:111-113`)에 playerView stop 없음. `playerView`가 `@MainActor` 격리라 actor deinit에서 동기 접근 불가 — stop을 명시 커맨드/prepare에 의존하게 만든 근본 원인.
- **[검증] SDK 헤더**: `proxyPort`(`KollusPlayerView.h:97`) 존재 → proxy가 playerView에 묶인다는 가설 뒷받침. playerView stop = `stopWithError:`(`:223`). `releaseServerAndStop`/NSTimer는 **`.a` 바이너리 내부**라 헤더 grep 불가(초판의 "바이너리 내부 간접 확인" 표기 정확).
- **[검증] 레거시 대조**: 레거시도 `prepareToPlay`/`initVariable`에서 기존 playerView를 stop 없이 nil화(`MegaKollusMoviePlayerController.m:188-193, 142-155`)하나, **강의 전환 정상 경로는 상태머신(`isLoad`/`isStarted`/`isPreparing`)으로 SDK stop을 새 prepare에 강제 선행**한다(`finishWithIgnoreNextPlay:` `:997-1004` → `[self stop]` → stop delegate → 다음 prepare). 즉 레거시는 stop이 delegate-driven으로 강제돼 신규(`try?`로 best-effort)보다 견고. `applicationWillTerminate`(`:5151`)도 `finishWithIgnoreNextPlay:YES`로 방어.
- 수정 방향: `try? previous.stop()` 실패 로깅 + fallback 강제 정리, M1(dispose 순서 보장)과 함께 닫음. **레거시의 finish→stop→stop-delegate→prepare 체인이 "unbind→stop→dispose" 권고의 레퍼런스.**

### H11 — storage stop API 부재 (vendor 한계)
- 심각도: **HIGH** (단, vendor 제약 + 캐시로 재진입 누적은 방지됨)
- 파일: `KollusStorageAdapter.swift:80-83`, `KollusSessionBootstrapper.swift:85-89`, `Vendor/KollusSDK/include/KollusSDK/KollusStorage.h`
- 현상: `KollusStorage`는 `startStorage()`로 시작되나, 헤더 전체(187줄)를 grep한 결과 **`start*` 계열만 존재하고 `stop`/`release`/`shutdown` 류가 헤더에 없다**. vendor가 명시 stop API를 노출하지 않으며 정리는 `dealloc` 의존. `KollusStorageAdapter.deinit`(`:29-33`)은 `storage.delegate = nil`만.
- **[검증] SDK 헤더**: `KollusStorage.h`(187줄)에 시작 계열 4종(`startStorage:`/`startStorageWithFirst:`/`startStorageWithCheck:`/`startStorageWithNewPlayerID:`)만 존재, stop/release/shutdown/close/finalize 전무. 콘텐츠 단위 `removeContent:`/`removeCacheWithError:`만 있고 인스턴스 stop 불가 → 주장 정확. `serverPort`(`:40`) 존재.
- 누수 메커니즘: bootstrapper가 `cachedStorage`로 인스턴스당 단일 storage 캐시(`:21,:38-39,:56`), factory가 단일 bootstrapper를 adapter·DownloadCenter와 공유(`:26,:29,:41-43`). 따라서 **강의 재진입 반복해도 누적되지 않음**(당초 우려 반증 — 검증됨). 단 factory 교체 단위 세션은 stop 없이 dealloc까지 잔류.
- **[검증] 레거시 대조**: 레거시도 동일 — `SLKollusManager.m:148-162`가 `KollusStorage` **싱글톤 1개 lazy 생성**, `startStorageWithCheck:`/`startStorageWithNewPlayerID:`(`:271,:274`)만 호출, **stop/release 호출 코드 전체 0건**(dealloc 의존). 강의 전환 시 재생성 안 하고 재사용. 신규 bootstrapper `cachedStorage`는 이 싱글톤 패턴 그대로 이식. "재진입 무누적" 결론도 레거시와 일치.
- 불확실(명시): proxy 서버/포트가 storage(`serverPort` `:40`)에 묶이는지 playerView(`proxyPort` `KollusPlayerView.h:97`)에 묶이는지는 vendor 바이너리 내부라 단정 불가. 두 포트 속성 모두 헤더 존재 — playerView 측 관리 가능성이 높음(H10 참조).
- **[보강] 동적 DRM 주입 경로가 둘**: `extraDrmParam`이 `KollusPlayerView.h:152`뿐 아니라 `KollusStorage.h:43`에도 존재. M5(host top-level `extraDrmParameters` 무시) 결론엔 영향 없으나, SDK 레벨 동적 DRM 주입점이 이원이라는 사실 보강.
- 수정 방향: `KollusStorageAdapter`에 stop 대칭(=`storage = nil`로 ARC dealloc 앞당기기) + bootstrapper `invalidate()`로 factory teardown 시 `cachedStorage = nil`. vendor가 강제 stop을 안 주므로 "참조 해제 시점 보장"이 최선.

---

## 2. MEDIUM

| # | 항목 | 파일 | 핵심 |
|---|------|------|------|
| M1 | `dispose()`가 engine stop 안 함 | `PlayerCore.swift:73-80` | 정상 경로는 `.stop`(viewWillDisappear)이 dispose보다 선행되어 안전. 비정상 종료/Task 순서 비보장이 구조적 위험. H10과 연결 |
| M2 | `bind`/`unbind` fire-and-forget | `KollusPlayerAdapter.swift:409-430`, `AVPlayerAdapter.swift:186-213` | detach를 `Task{@MainActor}`로 분리 → 빠른 전환 시 attach/detach 순서 경쟁, 새 view가 의도치 않게 `removeFromSuperview` |
| M3 | finished→playing 역전 | `PlayerCore.swift:211-226` | terminal `.finished`서 늦은 `bufferingDidChange(false)`가 `else → .playing` 전이. terminal 보존 필요 |
| M4 | duration=0 덮어쓰기 | `PlayerCore.swift:207-210`, `AVPlayerAdapter.swift:344-350` | periodic observer가 미확정 duration 0으로 기존 정상 duration 덮음. `duration<=0`이면 기존 유지 |
| M5 | `extraDrmParameters` 죽은 필드 | `KollusEnvironment.swift:32,55,76` | top-level `extraDrmParameters`가 어디서도 안 읽힘. adapter는 `environment.drm.extraParameters`만 주입(`:498-502`). host가 동적 DRM 파라미터 넣으면 조용히 무시 → 인증 실패 소지 |
| M6 | DRM 인증 실패 소실 | `KollusDelegateBridge.swift:144-148`, `KollusPlayerAdapter.swift:699-709` | DRM 콜백 `kollusPlayerView:request:json:error:`(`KollusPlayerDRMDelegate.h:21`, error 파라미터 실재 — 검증)의 error가 옵셔널 observer로만 전달, nil이면 증발. **[정정]** `.mediaContentKeyResolved`는 DRM delegate가 아니라 일반 `KollusPlayerDelegate.kollusPlayerView:mck:`(`:191`) 파생 엔진 신호이며 adapter가 `break`로 미매핑. 레거시는 DRM delegate를 빈 구현으로 두고 SDK가 종료/`unknownError`로 승격→alert(`MegaStudy…:5125`)로 노출(증발 경로 없음) |
| M7 | `KollusPlayerType` vendor 누출 | `KollusPlayerAdapter.swift:67,359,374` | public init이 vendor enum 노출 + 매직넘버 `1` + `KollusPlayerType(rawValue: 1)!` force-unwrap. **[검증]** `1` = `PlayerTypeNative`(`KollusSDK.h:13-20`: Kollus=0/Native=1/HLS=2). rawValue 1은 유효 case라 런타임 크래시 없음. 도메인 중립 enum으로 매핑 권장 |
| M8 | bootstrapper `cachedStorage` 무효화 부재 | `KollusSessionBootstrapper.swift:37-63` | 캐시가 영구 유지, `applicationExpireDate` 만료/손상/`removeCache` 후에도 동일 storage 재사용. 재인증 수단 없음 |
| M9 | Swift6 차단요인 | `KollusPlayerAdapter.swift:409-420`, `KollusEngineSignal.swift:12` | renderSurface(non-Sendable UIView 보유)를 actor→`Task{@MainActor}` 캡처. `KollusEngineSignal: Sendable`인데 `Error` 페이로드는 non-Sendable. Swift6서 컴파일 에러 |
| M10 | setPlaybackRate Float/Double 경계 | `PlayerCore.swift:283` | `rate <= Double(currentPolicy.maxPlaybackRate)` — 1.4·1.6 등 정책 상한서 `Double(Float())` 오차로 경계 어긋남. 정책 rate도 Double 통일 |
| M11 | nextEpisode seek-skip emit 누락 | `KollusPlayerAdapter.swift:735-773` | positionChanged 기반(`:662-668`)이라 showAt 구간을 seek로 건너뛰면 emit 누락. callbackURL 파싱 실패는 조용히 return(`:759-764`). **[검증]** SDK 프로퍼티 `nextEpisodeShowTime`/`CallbackURL`/`ShowButton`/`CallbackParams` 모두 실재(`KollusPlayerView.h:160-166`, readonly). 레거시는 jwt next_episode 미사용 — **앱 강의목록 인덱스 기반**(`nextLectureWithCurrentLecture:` `MegaStudy…:2222`)으로 다음강의 결정, 버튼 노출만 jwt `uservalue15`(30초). host가 이미 강의목록 구동으로 보강한 방향과 일치 |
| M12 | subtitle/font 실패를 다운그레이드로 삼킴 | `KollusPlayerAdapter.swift:233-250` | Kollus 미지원인데 `try await`는 성공 반환, `policyDowngraded`만. `isSubtitleVisible`(`:234`)은 저장만 되고 안 읽힘 |
| M13 | legacy prepare 비동기 미대기 | `KollusPlayerAdapter.swift:557-600` | H2와 동일 뿌리 — 동기 throw 시 `.preparing` 잔류, 실패 delegate 미수신 |

---

## 3. LOW

- **매 prepare 새 view 생성** (`KollusPlayerAdapter.swift:455-463, 567-575`) — stop 선행으로 lifecycle 안전, 메모리 spike/prepare 지연 비용만. **[정정] 레거시도 동일하게 매 prepare마다 새 `KollusPlayerView`를 alloc**한다(`MegaKollusMoviePlayerController.m:188-216`: 기존 view `removeFromSuperview`+nil 후 `[[KollusPlayerView alloc] init…]`). 초판의 "레거시 단일 view 재사용 대비 무거움" 대조는 **사실이 아님** — 신규=레거시 동등. source 교체식 재사용은 양쪽 모두 미사용. 이 항목은 "개선 여지"로만 유효하고 레거시 대조 근거는 무효.
- **AVPlayerAdapter observer 정리** — KVO/notification/periodic observer 모두 `cleanupCurrentItemObservers()`(`:286-307`) + deinit(`:48-65`)에서 견고하게 정리. 양호. (LOW: `stop`의 `replaceCurrentItem(nil)`을 actor 컨텍스트서 직접 호출 — main thread 권장)
- **`handleTimeControlStatus`** (`AVPlayerAdapter.swift:354-355`) — `.paused` 분기가 status를 `.paused`로 전이 안 함. 제어센터 등 시스템 일시정지 시 state가 playing 잔류.
- **`PlayerSession` 계열 프로토콜** (`PlayerCapabilities.swift:29-85`) — 정의만 되고 어댑터 채택 0. dead 추상화, 혼란.
- **`streamInfoList` 매핑** (`KollusPlayerAdapter.swift:334-348`) — `[String:Any]` 캐스팅 실패 시 빈 배열. SDK 반환 타입 미확정이라 ABR 정보 항상 비어있을 소지.
- **`KollusEnvironment.observer/diagnostics/chat`** (`:31,34,35`) — observer는 DownloadCenter에서만, diagnostics/chat은 미사용. 주입 경로(환경 vs 팩토리) 이원화로 혼동.
- **force_unwrap** — `PlayerCore.swift:46-47`, `KollusPlayerAdapter.swift:73`의 continuation `!`. AsyncStream 클로저 동기 실행이라 안전하나 host SwiftLint `force_unwrapping` 에러 룰과 충돌 패턴.

---

## 4. 보안

엔진 측 Swift 코드 전반에 **하드코딩된 시크릿/토큰/URL/키 없음**.

- DRM 인증서·라이선스 URL(`fpsCertURL`, `fpsDrmURL`) 및 파라미터는 전부 host 주입 `KollusEnvironment.drm`에서만 유입(`KollusPlayerAdapter.swift:492-502`). 엔진에 박힌 상수 URL/키 없음.
- `applicationKey`/`applicationBundleID`/`keychainGroup` 전부 주입값.
- 로깅 양호 — 엔진 Swift에 `print`/`NSLog`/`os_log`/`Logger` 전무, `playerView.debug = false`(`:487, :577`)로 SDK 디버그 로그 차단. JWT/키/DRM 응답 콘솔 출력 경로 없음.
- **유일 주의**: DRM request/response 원본 딕셔너리가 `KollusObserver`로 그대로 전달된다. 엔진 자체는 로깅하지 않지만, host observer 구현이 이를 로그/전송하면 민감정보 노출 가능. **host 계약에 마스킹 책임 명시 필요**.

호스트(smartlearning)에는 레거시 ObjC 플레이어용 DRM 헤더만 존재하고, 신규 엔진은 아직 DRM 경로로 연결되지 않은 상태로 보인다.

---

## 5. 검증된 양호 항목 (재조사 불요)

- **AVPlayerAdapter 리소스 정리**: KVO 2종 + notification 2종 + periodic observer 전부 cleanup + deinit 해제. CRITICAL/HIGH 없음.
- **재진입 storage 누적 없음**: bootstrapper `cachedStorage` + `inFlightTask` 직렬화로 `startStorage` 정확히 1회. 동시/재진입 안전.
- **caption C 포인터**: `KollusDelegateBridge.swift:231-241`에서 동기 String 변환, `subtitlePathBuffer` retain(`:256-271`)으로 dangling 없음.
- **DRM delegate retain**: bridge가 `self.bridge` strong retain(`:519`), weak delegate 조기 해제 위험 없음.
- **정상 dismiss 순서**: `viewWillDisappear → .stop`(engine stop) → `viewDidDisappear → dispose` 순서 보장(host). 정상 경로 안전.

---

## 6. 권장 수정 묶음 (ROI 순)

1. **신호 직렬화** (H1, AVPlayer KVO) — bridge/KVO 콜백을 어댑터별 단일 `AsyncStream`로 수렴, FIFO 소비. 순서역전 클래스 일괄 제거. **최우선**.
2. **상태머신 가드 + 취소 복원** (H4·H5·H6·H7) — status별 허용 커맨드 가드, `catch`서 `.idle` 복원, task `===` 동일성 비교, generation 토큰으로 stale 무시.
3. **에러 분류 실연결** (H3) — NSError domain/code → network/auth 매핑, Kollus 경로도 매퍼 경유.
4. **teardown 순서 보장** (H10, M1) — `unbind → stop → dispose` 단일 await 체인, `dispose`가 stop idempotent 선행. proxy race + 세션 잔류 동시 해결.
5. **capability/PiP 정합** (H8·H9) — capabilities 실동작 반영 or 배경재생-정책 연동, PiP는 Native 엔진서 `AVPlayerLayer` 기반 실구현 or 채택 제거.
6. **legacy prepare 통일** (H2, M13) — bootstrapped와 동일 delegate-await.
7. **Swift6 사전작업** (M9) — `Error` 페이로드 Sendable화, actor 경계 non-Sendable 캡처 제거. 이후 타깃별 `strictConcurrency` 점진 적용.
8. **정리** (M5·M7·M8 등) — 죽은 필드/이원 채널 제거, vendor enum 격리, 캐시 무효화.

---

## 7. 2차 검증 정정 요약 (KollusSDK 헤더 + 레거시 ObjC 대조)

### 정정된 서술
| 항목 | 초판 서술 | 정정 |
|------|----------|------|
| **LOW 매 prepare 새 view** | "레거시 단일 view 재사용 대비 무거움" | **오류**. 레거시도 매 prepare 새 `KollusPlayerView` alloc(`MegaKollusMoviePlayerController.m:188-216`). 신규=레거시 동등. 대조 근거 무효, "개선 여지"로만 유효 |
| **H2/M13 메서드명** | 완료 콜백 "`prepareToPlayWithError`(`prepareToPlayCompleted`)" 병기 | `prepareToPlayCompleted`는 SDK 아님(엔진 내부 signal). SDK 실제 = `kollusPlayerView:prepareToPlayWithError:`(`KollusPlayerDelegate.h:20`). `prepareToPlayWithMode:error:`는 동기 BOOL(시작 여부만) |
| **M6 mck 출처** | DRM 단락에 `.mediaContentKeyResolved` 배치 | DRM delegate 아니라 일반 `KollusPlayerDelegate.kollusPlayerView:mck:`(`:191`) 파생 |
| **M7 매직넘버 1** | "매직넘버 1" 의미 비움 | `1` = `PlayerTypeNative`(`KollusSDK.h:13-20`). 유효 case라 force-unwrap 런타임 크래시는 없음(룰 위반만) |
| **M5/H11 DRM 주입** | host top-level `extraDrmParameters`만 언급 | SDK `extraDrmParam`이 playerView(`:152`)+storage(`:43`) 이원 존재(보강) |

### 헤더로 검증된 사실 (초판 정확)
- H11 storage stop API 부재(start* 4종만), H10 `proxyPort` 실재(playerView 바인딩 뒷받침), H6 seek=`currentPlaybackTime` setter, prepare 동기BOOL+비동기delegate, DRM 콜백 error 파라미터 실재, nextEpisode 4프로퍼티 실재, `disablePlayRate`/`seekable`/`bookmarkModifyEnabled` readonly 실재.
- `releaseServerAndStop`/NSTimer는 `.a` 바이너리 내부 — 초판의 "바이너리 내부 간접 확인" 한계 표기 정확.

### 레거시에서 배울 이식 패턴 (신규 엔진 개선 후보)
1. **prepare 완료 delegate 대기** (H2 직결) — 레거시는 `prepareToPlay` 동기 반환을 불신, `prepareToPlayWithError:` 완료 후에만 `play`(`:941→:5325→:2913`). 신규 legacy 경로도 콜백-await로 통일.
2. **상태 가드 3-플래그로 전환 직렬화** (H4·H5·H6·H7 직결) — 레거시 `isPreparing`/`isLoad`/`isStarted`로 "준비 중 재생 차단/로드 완료 전 강의 차단/play 완료 전 다음강의 차단" 강제(`moveToNextLecture:` `:5964-5983` 3중 가드). 신규 상태머신 가드 부재의 직접 레퍼런스.
3. **강의 전환 = stop 선행 강제** (H10·M1 직결) — 모든 전환이 `finishWithIgnoreNextPlay:`→`[self stop]`(SDK)→stop delegate→다음 prepare 순서. "unbind→stop→dispose" 권고의 원형.
4. **배경재생 단일 진실원** (H8 직결) — `playerSetting.backgroundPlayMode` 하나로 SDK 플래그+AVAudioSession 직접 연동(`:2840,:3509`). capability-정책 이원화 모순 제거 모델.
5. **에러 코드 기반 사용자 메시지** (H3·M6 부분 보완) — `SLKollusManager errorMessageWithError:`(`:585-609`)가 NSError code별 사용자 메시지 가공(예: -8056 공공장소 제한). 신규 `mapToPlayerError` 분류와 결합 시 UI 품질↑.

### 종합
초판 HIGH/MEDIUM의 **결함 판정은 전부 유효**(H2·H8·H10·H11·M6·M7·M11 모두 SDK/레거시로 사실 확인). 정정은 **SDK API명·매직넘버 의미·레거시 동작 서술의 정밀도** 수준이며, LOW "매 view" 대조 1건만 명백한 오류였다. 레거시는 신규 엔진이 갖춰야 할 상태머신·prepare-await·stop-선행·배경재생 단일원의 **검증된 레퍼런스 구현**임이 확인됨.

---

## 부록 — 참조 핵심 파일

```
Sources/VideoPlayerCore/Internal/PlayerCore.swift
Sources/VideoPlayerCore/Contract/PlayerEngineAdapter.swift
Sources/VideoPlayerCore/Domain/PlaybackState.swift, PlaybackCommand.swift, PlayerEvent.swift, NextEpisodeInfo.swift, PlayerCapabilities.swift
Sources/VideoPlayerEngineKollus/KollusPlayerAdapter.swift
Sources/VideoPlayerEngineKollus/KollusDelegateBridge.swift
Sources/VideoPlayerEngineKollus/KollusEngineSignal.swift
Sources/VideoPlayerEngineKollus/KollusSessionBootstrapper.swift
Sources/VideoPlayerEngineKollus/KollusStorageAdapter.swift
Sources/VideoPlayerEngineKollus/KollusPlayerModuleFactory.swift
Sources/VideoPlayerEngineKollus/KollusEnvironment.swift
Sources/VideoPlayerEngineNative/AVPlayerAdapter.swift
Sources/VideoPlayerShellSupport/PlayerModuleWiring.swift, PlayerLifecycleCoordinator.swift
Vendor/KollusSDK/include/KollusSDK/KollusStorage.h, KollusPlayerView.h, KollusSDK.h, KollusPlayerDelegate.h, KollusPlayerDRMDelegate.h
Package.swift (swift-tools 5.9, strictConcurrency 미설정 → Swift 5 모드)
```

검증 참조(레거시, smartlearning-ios-ms):
```
ObjcFeature/Player/MegaKollus/Player/Controller/MegaKollusMoviePlayerController.m  (Kollus SDK 직접 래퍼)
ObjcFeature/Player/MegaStudy/Player/Controller/MegaStudyMoviePlayerController.m    (앱 상태머신/delegate, 6964줄)
ObjcFeature/Player/Mega/Player/Controller/MegaMoviePlayerController.m/.h           (베이스/상태 정의)
ObjcFeature/Manager/Kollus/SLKollusManager.m                                       (storage 싱글톤 생명주기)
```
