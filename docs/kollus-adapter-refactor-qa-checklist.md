# QA 체크리스트: adapter outputStream 전환 (A 작업)

> 작성: 모바일개발팀_정준영 · 2026-06-04
> 대상 브랜치: `refactor/player-engine-state-ownership`
> 선행: [followup-spec](kollus-adapter-refactor-followup-spec.md) §6
> 목적: Core가 두 엔진을 outputStream→reducer로 소비하도록 전환한 변경의 실동작 검증.

---

## 0. 사전 셋업

### 0.1 빌드 (DEBUG — 로그 활성)
- 앱 타깃 SmartPlayer를 **DEBUG**로 실기기에 설치. (Kollus 경로는 시뮬레이터에서 실행 불가 — 실제 SDK 필요)
- Native(AVPlayer url source) 시나리오는 시뮬레이터로도 일부 검증 가능.

### 0.2 로그 캡처
```bash
# A) xclog (구조화 JSON, 권장)
xclog launch com.megastudy.SmartPlayer --timeout 120s | grep -E "PlayerCore|Kollus.out|Native.out"

# B) Console.app — 기기 선택 후 검색창에 태그 입력:
#    [PlayerCore.out   [PlayerCore.cmd   [Kollus.out   [Native.out

# C) 터미널 실시간 (기기 연결):
xcrun devicectl ... 또는 idevicesyslog | grep -E "PlayerCore|Kollus.out|Native.out"
```

### 0.3 로그 태그 읽는 법
| 태그 | 의미 |
|---|---|
| `[PlayerCore.out] <input> \| <전>-><후> \| source=` | reducer가 만든 상태 전이 (권위) |
| `[PlayerCore.out] bridge stateDidChange -> X` | 미전환 엔진 폴백 경로 (전환 후엔 안 보여야 정상) |
| `[PlayerCore.out] event X` | 상태 무관 passthrough |
| `[PlayerCore.cmd] command-origin X` | Core가 명령 결과로 상태 닫음 (Native) |
| `[PlayerCore.cmd] skip command-origin ...` | 권위 콜백 엔진이라 스킵 (Kollus) |
| `[Kollus.out] <signal> -> <output>` | Kollus adapter 발행 |
| `[Native.out] <signal> -> <output>` | Native adapter 발행 |

> ⚠️ **전환 성공 핵심 신호**: 정상 전환이면 재생 중 `[PlayerCore.out]`에 `bridge stateDidChange`가 **거의 안 보여야** 한다(엔진이 outputStream으로 stateInput을 보내므로). bridge가 자주 보이면 해당 엔진이 outputStream 미발행 = 전환 누락.

---

## Part A. Native (AVPlayer, url source) — 시뮬레이터 가능

| # | 시나리오 | 절차 | 기대 로그 / 상태 | 판정 |
|---|---|---|---|---|
| A1 | 재생 시작 | url 강의 진입 → 자동/수동 재생 | `[Native.out] prepared duration=...` → `[PlayerCore.out] prepared(...) \| preparing -> readyToPlay` → play 시 `[PlayerCore.cmd] command-origin playStarted` → `... -> playing` | ☐ |
| A2 | 일시정지/재개 | pause → resume | pause: `[PlayerCore.cmd] command-origin pauseStarted \| playing -> paused`. resume: `command-origin playStarted -> playing` | ☐ |
| A3 | seek | scrubber 또는 skip±10s | `[PlayerCore.cmd] command-origin positionChanged(...)`. 재생바 점프 정확. 잉여 `stateDidChange` 없음 | ☐ |
| A4 | 버퍼링 | 약한 네트워크/시작 버퍼 | `[Native.out] timeControl(waiting...) -> stateInput(bufferingChanged(true))` → `... -> buffering`, 재개 시 `timeControl(playing) -> bufferingChanged(false)` → `-> playing` | ☐ |
| A5 | 종료 | 영상 끝까지 | `[Native.out] didFinish -> stateInput(stopped(finished))` → `... -> finished`, `didFinish` 이벤트 1회 | ☐ |
| A6 | 늦은 paused 무시 | 종료/정지 직후 | `timeControl(paused)`가 와도 `[Native.out]`에 출력 **없음**(mapper nil). finished/idle 상태 안 되살아남 | ☐ |
| A7 | 실패 | 잘못된 url | `[Native.out] failed(...) -> stateInput(failed)` → `-> failed(...)`, `didFail` 1회 | ☐ |

---

## Part B. Kollus (실 SDK) — 실기기 필수

| # | 시나리오 | 절차 | 기대 로그 / 상태 | 판정 |
|---|---|---|---|---|
| B1 | 일반 강의 재생 | 강의 진입 → 재생 | `[Kollus.out] prepareToPlayCompleted(nil) -> stateInput(prepared(...))` → `[PlayerCore.out] prepared \| preparing -> readyToPlay`. play: `[Kollus.out] playStarted -> playStarted` + `[PlayerCore.cmd] skip command-origin` + `[PlayerCore.out] playStarted -> playing` | ☐ |
| B2 | 재생바 갱신 | 재생 중 관찰 | 0.5s마다 `[Kollus.out] positionChanged -> positionChanged` → `[PlayerCore.out] ... timeDidChange`. 재생바 currentTime 실시간 갱신 | ☐ |
| B3 | 일시정지/재개 | pause → resume | pause: `[Kollus.out] pauseStarted -> pauseStarted` → `-> paused`, polling 중지(position 로그 멈춤). resume: playStarted → playing, polling 재개 | ☐ |
| B4 | seek | scrubber/skip | seek 후 위치 점프. `[Kollus.out] positionChanged(isSeeking)` 는 **출력 없음**(mapper nil), 실제 위치는 polling이 반영 | ☐ |
| B5 | 종료 | 끝까지 재생 | `[Kollus.out] stopStarted(userInteraction:false) -> stopped(finished)` → `-> finished`, `didFinish` 1회 | ☐ |
| B6 | **다음 회차 1회** | 다음회차 진입시간 도달 | `nextEpisodeAvailable` 이벤트 **정확히 1회**. 중복 없음 | ☐ |
| B7 | **⚠️ 강의 연속 전환 (stale prepared)** | 강의 A 재생 중 → 다음강의 버튼/자동전환으로 B 진입 | `[PlayerCore.out] prepared \| ... -> readyToPlay \| source=B` 이후 **source=A의 prepared가 다시 나타나면 안 됨**. 나타나면 stale 덮어쓰기 = **generation guard 필요 (spec §3.4) — FAIL** | ☐ |
| B8 | 동일 source 중복 load | 다음강의+자동전환 동시 트리거 | prepare cancel-restart 충돌(ResCode 23/42) 없음. coalesce 동작 | ☐ |
| B9 | DRM 재생 | DRM 보호 컨텐츠 | 정상 재생. DRM 실패 시 에러 경로 확인 | ☐ |
| B10 | 백그라운드/복귀 | 재생 중 홈 → 복귀 | `.appLifecycle` stop 경로. 복귀 후 정상. 크래시 없음 | ☐ |
| B11 | 기능 위임 | 배속/자막/외부자막/북마크 추가·삭제/줌/스크롤/화질 | 각각 동작. 상태 꼬임 없음 | ☐ |
| B12 | 재진입 | viewWillDisappear → 재진입 반복 | playerView teardown 정상, 크래시 없음(KollusProxyPlayerView 타이머) | ☐ |

---

## Part C. 공통 / 회귀

| # | 항목 | 기대 | 판정 |
|---|---|---|---|
| C1 | bridge 미사용 확인 | 두 엔진 재생 중 `[PlayerCore.out] bridge stateDidChange`가 거의 안 보임(전환 완료 신호) | ☐ |
| C2 | command-origin 분기 | Native=`command-origin`, Kollus=`skip command-origin` 로그로 확인 | ☐ |
| C3 | 버스트 무손실 | 빠른 seek/buffering 연타 시 상태 desync 없음(.unbounded) | ☐ |
| C4 | sim 회귀 | `xcodebuild test ... VideoPlayerModuleTests` 208 통과 | ☐ |

---

## 판정 요약

| Part | 통과/전체 | 비고 |
|---|---|---|
| A (Native) | / 7 | |
| B (Kollus) | / 12 | **B7 stale prepared가 가장 중요** |
| C (공통) | / 4 | |

### FAIL 시 조치
- **B7 stale prepared FAIL** → `PlaybackStateInput.prepared`에 source identity/generation 첨부 또는 Core가 active generation의 prepared만 reducer 통과(spec §3.4 option 1). **머지 차단 이슈**.
- **C1 bridge 자주 보임** → 해당 엔진 outputStream 미발행. emitOutput 경로 점검.
- **임의 엔진 회귀** → 해당 adapter의 `PlayerEngineOutputProducing` 채택만 제거 → eventStream bridge로 즉시 폴백(엔진별 독립 롤백).

---

## 진행 메모 (세션 중 기록)

```
(여기에 각 항목 실측 로그/결과를 붙여넣으며 진행)
```
