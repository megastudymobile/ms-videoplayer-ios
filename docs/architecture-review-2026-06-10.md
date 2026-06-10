# videoplayer-ios-ms 아키텍처 검토 보고서

- 작성자: JunyoungJung
- 작성일: 2026-06-10
- 검토 기준 브랜치: `feature/example-app-rebuild` (e83a5ee)
- 검토 목적: 설계 의도(① SDK 교체 시 최소 수정, ② 여러 서비스에서 플레이어 재활용) 충족 여부 평가 및 개선점 도출
- 관련 문서: [kollus-sdk-coverage-review-2026-06-10.md](./kollus-sdk-coverage-review-2026-06-10.md) — Kollus SDK 기능 구현 대조 검토
- 개선 설계: [improvement-plan-2026-06-10.md](./improvement-plan-2026-06-10.md)

---

## 1. 총평

의도 대비 설계 충실도는 높다. **공통 상태 머신(Core) + 교체 가능 엔진(Adapter) + 재사용 UI(Skin)** 분리가 일관되게 지켜지고 있으며, `PlayerModuleBoundaryTests`가 서비스 앱 용어 유입을 기계적으로 차단하는 장치도 우수하다. Example 앱에서 엔진 스왑(Kollus ↔ UnsupportedEnvironmentEngine)과 skin blueprint 확장이 실증되어 재생 경로 한정으로는 교체 가능성이 입증되었다.

다만 **"SDK 교체 최소 수정" 목표에는 구조적 구멍 3개**가 있다(§3). 이 3개를 해소해야 목표가 실제로 달성된다.

| 영역 | 평가 | 비고 |
|------|------|------|
| 상태 소유권 / 상태 머신 | 우수 | 순수 reducer, 엔진은 신호만 발행 |
| 엔진 계약 (PlayerEngineAdapter) | 양호 | capability 협상 방식 적절, 사전 협상 부재 |
| Core의 SDK 중립성 | **미흡** | `PlaybackSource.kollus` 벤더명 누수 |
| 다운로드/DRM 추상화 | **미흡** | Kollus 전용 API에 host 직접 의존 |
| Skin 재사용성 | 우수 | 엔진 import 0, theme 토큰, blueprint 확장 실증 |
| 동시성 설계 | 우수 | delegate bridge → 단일 consumer, generation 추적 |
| 테스트 | 양호 | Reducer/Mapper 커버리지 좋음, Skin 블록 공백 |

---

## 2. 잘된 점

### 2.1 상태 소유권 단일화
엔진은 신호만 발행하고 `PlaybackStateReducer`(순수 함수)가 전이를 결정한다. 상태가 Core에만 존재하므로 UI-상태 desync가 구조적으로 차단되고, 전이 로직이 단독 테스트된다.

### 2.2 Capability 협상 — SDK 이름 없는 일반화
`EngineCapabilities.emitsObservedCommandState` 비트(`PlayerEngineAdapter.swift:35`)가 Kollus(콜백 권위)와 Native(명령 권위)의 차이를 "Kollus인가?"가 아니라 "권위 콜백을 발행하는가?"로 추상화했다. 올바른 방향. `continuesWithoutSurface` 기반 백그라운드 정책 다운그레이드(`PlayerCore.swift:444-463`)도 동일한 패턴.

### 2.3 동시성 설계
- SDK delegate(임의 스레드) → `@MainActor` bridge → unbounded `AsyncStream` → 단일 consumer Task. FIFO 보장, 입력 손실 없음.
- prepare generation 추적(`PlayerCore.swift:28-31`)으로 stale 완료가 새 소스를 덮어쓰는 것 방지.
- seek chase 패턴(QA1820 스타일)으로 연타 seek가 SDK를 압도하지 않음.

### 2.4 Skin 격리
- 엔진 모듈 import 0개. `PlayerSkinAction`/`PlayerSkinState`만으로 host와 통신.
- Theme 토큰(색 5종, 폰트 7종, 아이콘 fallback 체인)으로 포크 없이 리브랜딩 가능. iPad 전용 variant 지원.
- Example의 `LiveBadgeBlock`(`PlayerSkinBlueprint+Example.swift:14-22`)이 `AssembledPlayerSkin` 무수정 확장(OCP)을 실증.

### 2.5 경계 강제 장치
`PlayerModuleBoundaryTests`가 패키지 소스 전체에서 서비스 앱 용어("SmartLearning", "MegaStudy" 등)를 스캔해 빌드 실패시킴. 규칙을 문서가 아니라 테스트로 강제하는 좋은 사례.

### 2.6 Render surface 추상화
`PlayerRenderSurface`는 `containerView: UIView` + attach/detach 콜백만 요구. Kollus(KollusPlayerView 부착)와 Native(AVPlayerLayer 부착) 모두 동일 계약으로 동작 — 엔진 중립 완성.

---

## 3. 핵심 개선점 (SDK 교체 목표 기준 우선순위)

### 3.1 `PlaybackSource.kollus` — Core에 벤더명 누수 ★최우선

```swift
// Sources/VideoPlayerCore/Domain/PlaybackSource.swift:11-14
public enum PlaybackSource: Equatable, Sendable {
    case kollus(mediaContentKey: String)
    case url(URL)
}
```

- "Core는 SDK를 모른다" 규칙을 Core의 공개 도메인 타입이 직접 위반.
- 새 SDK 추가 시 Core enum 수정 필요 → 모든 어댑터의 switch가 연쇄 수정됨.
- **제안**: 벤더 중립 케이스로 개명.
  ```swift
  public enum PlaybackSource: Equatable, Sendable {
      case url(URL)
      case mediaKey(String)            // 어댑터가 해석 책임
      // 또는 확장형: case remote(id: String, metadata: [String: String])
  }
  ```
- 지금은 어댑터가 2개뿐이라 마이그레이션 비용 최소. 가장 먼저 착수 권장.

### 3.2 다운로드/DRM에 엔진 중립 계약 없음

- host가 `KollusDownloadCenter`, `KollusEnvironment`(30+ 필드), `KollusObserver`, `KollusContentSnapshot`을 직접 import·의존.
- 재생 경로는 교체 가능하지만 **오프라인/DRM 경로는 SDK 교체 시 host 코드 전면 재작성**. 실사용 host(LMS 연동, 다운로드 관리)에서는 이 표면이 재생 API보다 크다.
- **제안**: Core 또는 ShellSupport에 엔진 중립 프로토콜 정의.
  ```swift
  public protocol PlayerDownloadCenter: Actor {
      func resolve(contentURL: URL) async throws -> DownloadHandle
      func startDownload(_ handle: DownloadHandle) async throws
      func cancelDownload(_ handle: DownloadHandle) async
      func remove(_ handle: DownloadHandle) async throws
      var contents: AsyncStream<[DownloadedContentSnapshot]> { get }
  }
  ```
  Kollus 구현은 `VideoPlayerEngineKollus`에 두고, host는 프로토콜만 의존.

### 3.3 기능 비대칭이 사전에 드러나지 않음

- 자막·북마크·줌·스크롤·adaptive streaming은 전부 Kollus 어댑터 전용. Native로 교체하면 해당 명령이 런타임 throw 또는 조용한 `.policyDowngraded`로만 드러남.
- host가 "이 엔진에서 어떤 기능이 가능한가"를 init 시점에 알 방법이 없음. `PlayerStateSnapshot.unavailableCapabilities`는 명령 실패 후 반응적으로만 채워짐.
- **제안**: init 시점에 capability 스냅샷 제공(엔진의 optional protocol 채택 여부를 Core가 조회 → 지원 기능 목록 노출). UI는 이를 보고 버튼을 사전에 숨김.

---

## 4. 중요 개선점

### 4.1 PiP 가짜 구현
`KollusPlayerAdapter`(line 480-512)가 `PlayerPiPCapability`를 채택하지만 `startPiP()`는 항상 `.policyDowngraded` 발행, `isPiPActive`는 항상 false (H9 주석: host AVPictureInPictureController 통합 필요). 미구현이면 프로토콜 채택을 제거하거나 명시적으로 throw할 것. 현재는 "지원한다고 광고하고 실제로는 안 됨" 상태.

### 4.2 Reducer 잠재버그 (의도적 보존)
`PlaybackStateReducer.swift:118-128` — paused 상태에서 buffering 종료 시 `.playing`으로 복귀(레거시 동작 보존 주석 있음). buffering 진입 전 status를 기억해 복원하는 수정 필요. 수정 시점을 정해둘 것.

### 4.3 Seek Task 미취소
`PlayerCore.swift:378-385` — unstructured seek Task가 `dispose()`에서 취소되지 않음. `pendingPrepareTask`/`engineEventTask`처럼 보관 후 취소 필요.

### 4.4 `KollusPlayerAdapter` god object (1,202줄)
프로토콜 12개 채택 + position 폴링 + 북마크 캐시 + next-episode 캐싱 + DRM 부트스트랩 + 26개 delegate 핸들러. 분리 후보:
- `KollusBookmarkManager` — 낙관적 북마크 캐시
- `KollusPositionPoller` — 0.5s 폴링 (간격도 설정값으로)
- `KollusNextEpisodeEmitter` — 메타 캐시 + 임계 체크

(비교: `AVPlayerAdapter`는 503줄로 적정.)

### 4.5 UseCase 레이어 = 순수 보일러플레이트
`Start/Control/ObservePlaybackUseCase` 3개 모두 Core 메서드 1:1 위임. 변환·정책·로깅 없음. cross-cutting(로깅, 재시도) 계획이 없으면 삭제 권장 — 유지 비용만 발생.

---

## 5. 사소한 발견

| 항목 | 위치 | 내용 |
|------|------|------|
| seek 명령 중복 | `PlaybackCommand.swift:15-16` | `seek` / `seekWithOrigin` 두 케이스 → `seek(to:origin:)` 기본값으로 통합 가능 |
| 하드코딩 문자열 | `PlayerNowPlayingCenter.swift:71` | "메가스터디 강의" fallback — boundary 테스트 금지어에 없어 통과 중. 주입 파라미터로 변경 |
| 미존재 문서 참조 | `PlayerSkin.swift:17` | `docs/player-skin-customization-architecture.md` 참조하나 파일 없음 |
| 미사용 capability | `PlayerEngineAdapter.swift:23-24` | `seamlessSurfaceSwap`, `nativePiP` 선언만 되고 Core 로직에서 미사용 |
| duration 음수 방어 없음 | `PlaybackStateReducer.swift:89-95` | 0 방어는 있으나 음수 미방어 — `max(0, _)` 추가 |
| 테스트 전용 init 미가드 | `KollusPlayerAdapter.swift:148,156` | 주석으로만 test-only 표시. 프로덕션 오용 방지 가드 검토 |
| 공개 API 과다 | `StateTransition/` 타입들 | `PlaybackStateInput` 등은 어댑터 전용 — host 노출 범위 점검 |

---

## 6. 테스트 커버리지 현황

| 영역 | 상태 |
|------|------|
| `PlaybackStateReducer` | ✅ 순수 로직 테스트 충실 |
| Signal mapper (Kollus/Native) | ✅ 단위 테스트 존재 |
| `PlayerLifecycleCoordinator` / AudioSession | ✅ 통합 테스트 |
| 경계 규칙 | ✅ `PlayerModuleBoundaryTests` 기계 강제 |
| Skin 블록 19개 | ⚠️ 스모크 테스트만 — 개별 블록 단위 테스트 없음 |
| `PlayerPlaybackRatePanelViewController` (467줄) | ❌ 미테스트 |
| 어댑터 통합(동일 시나리오 → 동등 상태 스트림) | ❌ 없음 — 엔진 교체 보증의 핵심 테스트로 추가 권장 |

---

## 7. 권장 조치 순서

1. **`PlaybackSource` 벤더 중립화** (§3.1) — 어댑터 2개인 지금이 최저 비용
2. **엔진 중립 `PlayerDownloadCenter` 프로토콜 도입** (§3.2)
3. **init 시점 capability 스냅샷** (§3.3) + 엔진×기능 호환성 매트릭스 문서화
4. PiP 채택 제거 또는 명시 throw (§4.1)
5. seek Task 취소 처리 (§4.3)
6. 어댑터 동등성 통합 테스트 추가 (§6)
7. `KollusPlayerAdapter` 분리 리팩터링 (§4.4) — 기능 변경 없이 점진 진행

---

## 8. 결론

구조 자체는 의도에 맞게 설계되었고, 재생 경로 한정으로는 SDK 교체 가능성이 Example 앱으로 입증되었다. 실제 교체 시나리오를 막는 것은 **소스 타입의 벤더 누수(§3.1), 다운로드/DRM 비추상화(§3.2), 기능 매트릭스 사전 협상 부재(§3.3)** 3가지다. 이를 해소하면 "최소 수정으로 SDK 교체" 목표는 달성 가능한 상태다.
