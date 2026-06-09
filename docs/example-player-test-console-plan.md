# Example 앱 — 플레이어 + 테스트 콘솔 화면 개선 계획

- **작성자**: JunyoungJung
- **작성일**: 2026-06-08
- **대상**: `videoplayer-ios-ms/Example`
- **참고 레이아웃**: `smartlearning-ios-ms` 의 `PlayerModule/UI/Container/LecturePlayerContainerViewController` (`verticalSplit`)

---

## 1. 목표

메인 화면에서 "플레이어" 진입 시 **상단에 영상(16:9) + 하단에 탭 콘솔**이 보이는 화면으로 개선한다.
하단 탭 콘솔은 **설정 / 북마크 / 자막 / 메타데이터** 탭으로 구성하여 플레이어 기능을 전부 확인·테스트할 수 있게 한다.
메인 화면의 "세팅" 버튼은 제거한다.

### 동작 요약

| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| 메인 "플레이어" 버튼 | `PlayerViewController` 풀스크린 `present` | `PlayerTestConsoleContainerViewController` `push` |
| 메인 "세팅" 버튼 | 존재 (`SettingViewController` push) | **제거** (세팅은 하단 탭으로 이동) |
| 세로(portrait) | 영상 풀스크린 | 상단 영상 16:9 + 하단 탭 콘솔 |
| 가로(landscape) | 영상 풀스크린 | **영상 풀스크린** (Lecture parity, 사용자 선택) |

---

## 2. 핵심 제약 (먼저 해결)

1. **skin 레이아웃 모드 역방향 문제**
   `PlayerViewController.layoutMode(for:)` 는 `width > height` 면 `.fullScreen` 을 반환한다.
   embed 된 16:9 상단 프레임은 portrait 화면에서도 자기 `view.bounds` 가 항상 가로로 넓다 →
   그대로 두면 skin 이 `.fullScreen` 모드(전체 chrome)로 렌더되어 의도(`.verticalSplit`, 최소 chrome)와 반대다.
   → **컨테이너가 skin 레이아웃 모드를 명시 주입**해야 한다.

2. **close 소유권**
   `route(.closeRequested)` → `dismiss(animated:)`. push 된 자식에는 부적합.
   → `PlayerViewController` 에 `onClose` 주입(기본 `dismiss`, 컨테이너는 `pop` 으로 override).

3. **하단 pane ↔ 플레이어 통신**
   하단 탭 pane 들이 플레이어 기능을 호출(명령)하고 상태/이벤트를 관찰해야 한다.
   → `PlayerViewController` 에 control/observe 채널 노출 (protocol 의존).

---

## 3. 진입 방식 결정: push (present 아님)

- 하단 설정 탭의 하위 화면 `push`(Codec / Gesture / Shortcut / Device / FAQ) 와 picker 액션시트가
  **같은 nav 스택**에서 그대로 동작한다 (present 시 nav controller 없어 무동작).
- 플레이어 수명이 깔끔하다: 설정 하위 화면을 push 해도 player 는 살아있고,
  컨테이너를 `pop` 할 때만 `interactor.tearDown()` 이 호출된다 (`isMovingFromParent`).

---

## 4. 변경/신규 파일

### 4.1 수정 — `Example/Sources/Main/MainViewController.swift`

- `settingsButton`, `didTapSettings()` 삭제. `UIStackView` arrangedSubviews 에서 제거.
- `didTapPlayer()`: 풀스크린 `present` → 컨테이너 `push` 로 변경.

```swift
let container = PlayerTestConsoleContainerViewController(
    source: .url(streamingURL),
    moduleProvider: PlayerModuleProvider.shared
)
navigationController?.pushViewController(container, animated: true)
```

### 4.2 수정 — `Example/Sources/Player/PlayerViewController.swift` (seam 추가, 기존 동작 보존)

- `var onClose: () -> Void` 추가 (기본값 `dismiss`). `.closeRequested` 에서 `onClose()` 호출.
- `var isEmbeddedInSplit = false` 추가. `layoutMode(for:)` 분기:
  - embed + portrait → `.verticalSplit` 강제
  - embed + landscape → `.fullScreen` (가로 = 풀스크린)
  - 비embed → 기존 로직
- 관찰 fan-out 훅 추가:
  - `var onSkinStateChanged: ((PlayerSkinState) -> Void)?` — `skin.render` 경로에서 함께 호출
  - `var onPlayerEvent: ((PlayerEvent) -> Void)?` — `handle(event:)` 경로에서 함께 호출
- `PlayerControlChannel` 채택 (명령 위임 + 현재 스냅샷 노출).

### 4.3 신규 — `Example/Sources/Player/PlayerControlChannel.swift` (protocol)

pane 이 구체 타입(`PlayerViewController`)에 결합하지 않도록 protocol 로만 의존.

```swift
@MainActor
protocol PlayerControlChannel: AnyObject {
    var currentSkinState: PlayerSkinState { get }
    func togglePlayPause()
    func skip(_ delta: TimeInterval)
    func seek(to time: TimeInterval)
    func setPlaybackRate(_ rate: Double)
    func addBookmarkAtCurrentTime()
    func setCaptionFontSize(_ size: CGFloat)
    func setCaptionHidden(_ hidden: Bool)
}
```

### 4.4 신규 — `Example/Sources/Player/PlayerTestConsoleContainerViewController.swift` (핵심)

- child: top = `PlayerViewController`, bottom = `PlayerConsoleViewController`.
- Example-local 레이아웃 리졸버 작성 (`LecturePlayerLayoutResolver` 동등, 의존 없음):
  - **portrait**: shell top (`height = width * 1/aspectRatio`, 16:9) + divider + console bottom → `view.bottom`
  - **landscape**: player 풀스크린, console `isHidden = true`
  - `viewWillTransition` 에서 재적용
- wiring:
  - `player.isEmbeddedInSplit = true`
  - `player.onClose = { [weak self] in self?.navigationController?.popViewController(animated: true) }`
  - `player.onSkinStateChanged` / `player.onPlayerEvent` → console pane 들로 fan-out
  - console pane 에 `PlayerControlChannel` (= player) 주입

### 4.5 신규 — `Example/Sources/Player/Console/PlayerConsoleViewController.swift`

- `UITabBar` (설정 / 북마크 / 자막 / 메타데이터) + container view 에서 pane child 교체.
  (`UITabBarController` 대신 경량 탭바 + child-swap — 상단 공유 player 와 split embed 에 적합.)
- pane 4종 모두 `PlayerControlChannel` 주입. state/event fan-out 을 활성 pane 에 전달.

---

## 4.6 하단 탭 pane 4종

| 파일 | 탭 | 내용 |
|------|-----|------|
| (재사용) `SettingViewController` | 설정 | 기존 그대로 — 백그라운드오디오 / 시크간격 / 디코더 / 자막크기·색상 / 기기정보 / 초기화 등 |
| `Console/BookmarkPaneViewController.swift` | 북마크 | "현재 위치 추가" → `channel.addBookmarkAtCurrentTime()`; 목록(`bookmarksDidLoad` 이벤트) 탭 → `seek(to:)` |
| `Console/CaptionPaneViewController.swift` | 자막 | on/off 토글, 폰트 크기 stepper, 보조자막 토글, 현재 자막 텍스트 미리보기(`captionDidUpdate`) |
| `Console/MetadataPaneViewController.swift` | 메타데이터 | `onSkinStateChanged` 구독 → currentTime / duration / status / 배속 / buffering / lock / displayScale / layoutMode + source URL / 엔진 종류 라이브 표시 |

---

## 5. 미해결 / 범위 명시

- **자막 on/off**: interactor 에 자막 트랙 제어 명령이 없고 `setCaptionFontSize` 만 존재.
  자막 탭의 on/off 는 우선 `captionView` 가시성 토글로 처리. 엔진 레벨 자막 트랙 제어 API 부재 시 그 범위를 명시.
- **`tearDown` 타이밍**: 컨테이너 `pop`(`isMovingFromParent`) 시 player child 정상 해제 — 기존 `viewDidDisappear` 로직 유지.

---

## 5.1 엣지케이스 검토

### HIGH — 구현 전 반드시 처리

| # | 엣지케이스 | 원인 | 대응 |
|---|-----------|------|------|
| H1 | **setUp/tearDown 레이스 → 모듈 누수** | push 직후 player `viewDidLoad` 가 async `setUp`/`start` 실행. 완료 전 back(pop) → `viewDidDisappear`(`isMovingFromParent`) `tearDown` 가 `playerModule=nil`. 이후 setUp Task 가 `playerModule=module` 재할당 → 그 모듈은 영원히 미해제. (현 present/dismiss 코드에도 잠재하나 back 버튼으로 발생 쉬움) | `PlayerInteractor` 에 `isDisposed` 플래그 또는 setUp Task 핸들 보관. `tearDown` 시 Task cancel + 플래그 set. setUp 완료부에서 `guard !isDisposed` 로 모듈 즉시 해제. |
| H2 | **설정 하위화면 back 내비 충돌** | 컨테이너가 host nav bar 를 숨기면(lecture parity) 설정 탭에서 push 한 Codec/Gesture 화면도 nav bar 없음 → back 버튼 없어 갇힘 | 본 테스트 앱은 **host nav bar 유지**(back 버튼·title 노출). player top 을 nav bar 아래에 배치. lecture 식 nav 숨김 미적용. player close 버튼은 pop 과 중복이나 무해. |
| H3 | **빠른 더블탭 → 컨테이너 2회 push** | `didTapPlayer` 가 push 후 `defer` 로 버튼 즉시 재활성 → 연타 시 중복 push. (smartlearning `58b1b2a` 동일 버그 전례) | push 직전 `navigationController?.topViewController is PlayerTestConsoleContainerViewController` 가드, 또는 진입 플래그. |
| H4 | **자막 크기 소스 이중화** | 설정 탭 "자막 크기"(`PreferenceManager.subtitleSize`) 와 자막 탭 폰트 stepper(`captionFontSize`) 가 별개 값 → 불일치 | 단일 소스로 통일. 자막 탭 stepper 도 `PreferenceManager.captionFontSize` 읽고 쓰기. 두 탭이 같은 키 공유. |
| H5 | **채널 retain cycle** | pane 이 `PlayerControlChannel`(=player VC) 강참조 → 컨테이너→player + 컨테이너→console→pane→player 순환 | pane 의 channel 참조 `weak`. |

### MEDIUM

| # | 엣지케이스 | 대응 |
|---|-----------|------|
| M1 | **skin 모드 소스** — player 자체 `viewWillTransition` 은 회전 시에만 발화. iPad 토글 등 제약만 바뀌는 전환은 미발화 → skin 모드 stale | 컨테이너가 레이아웃 변경 시 **player 에 skin 모드를 명시 주입**(`player.applySkinLayoutMode(_:)`). player 자체 transition 의존 금지. |
| M2 | **bookmark 목록 초기 타이밍** — pane 이 `bookmarksDidLoad` 발화 후 구독 시작하면 초기 목록 누락 | 컨테이너가 player 시작 전 event 구독 + 채널 스냅샷(`var bookmarks`)으로 pull 가능하게. pane 활성화 시 snapshot 으로 초기화. |
| M3 | **메타데이터 과다 갱신** — `timeDidChange` ~0.5s 마다 `onSkinStateChanged` → 비활성 pane 까지 reload | fan-out 을 **활성 탭 pane 에만** 전달. 비활성 pane skip. |
| M4 | **시뮬레이터 = `UnsupportedEnvironmentEngine`** — bookmark/zoom 등 capability 캐스트 nil → 북마크 탭 무반응 | 북마크 탭에 "엔진 미지원" 안내 표시. 메타데이터 탭에 엔진 종류 노출(디버깅 도움). |
| M5 | **landscape orientation 허용 여부** | pbxproj 에 orientation 키 없음 → 기본값이 landscape L/R 허용. 별도 작업 불필요. 단 컨테이너 `supportedInterfaceOrientations` 가 landscape 차단 안 하도록 확인. |

### LOW

| # | 엣지케이스 | 대응 |
|---|-----------|------|
| L1 | split portrait 에서 status bar 숨김 부자연 | 컨테이너 `prefersStatusBarHidden`: split=false, fullscreen=true 분기 (선택) |
| L2 | 하단 테이블 safe area bottom(홈 인디케이터) inset | 테이블 bottom = `view.bottom`, contentInset 자동 처리 의존 |
| L3 | iPad landscape 시 콘솔 소실(영상 풀스크린) | 사용자 선택 수용. portrait 복귀로 콘솔 재노출 |
| L4 | 회전 중 설정 하위화면이 스택 위에 있을 때 | 하위화면이 풀스크린 덮음 → 컨테이너 relayout 은 뒤에서 진행, pop 복귀 시 정상. 무해 |

### 자막 on/off 확정 (계획 §5 보강)

`PlayerCaptionView.setVisible(_:)` 가 이미 존재 — `isVisible=false` 면 텍스트 있어도 숨김 유지(`update(text:)` 가 `isVisible` 보존). 엔진 자막 트랙 제어 없이도 **시각적 on/off 완전 동작**.
→ 채널 `setCaptionHidden(_:)` 은 `player.captionView.setVisible(!hidden)` 로 구현. (captionView 는 player private → player 에 위임 메서드 추가)

---

## 6. 산출물 규모

- 신규 5파일 (`PlayerControlChannel`, 컨테이너, 콘솔, pane 3종)
- 수정 2파일 (`MainViewController`, `PlayerViewController`)
- 빌드 검증은 `apple-platform-build-tools:builder` 에이전트 위임.
