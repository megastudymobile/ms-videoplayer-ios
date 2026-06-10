# Kollus 플레이어 파리티 개선 계획 (구현 명세)

- 작성자: JunyoungJung
- 작성일: 2026-06-10
- 근거 문서: [kollus-player-parity-review.md](./kollus-player-parity-review.md)
- 대상 독자: 이 문서만 보고 구현 가능한 수준의 명세. 각 트랙은 독립 — 순서 무관하게 작업/머지 가능.

## 0. 공통 규칙 (모든 트랙에 적용 — 위반 시 CI 실패)

1. **경계 규칙**: `VideoPlayerSkin`은 엔진 모듈(`VideoPlayerEngineKollus` 등)을 import하지 않는다. Skin↔host 통신은 `PlayerSkinAction`/`PlayerGestureAction`/`PlayerSkinState`로만.
2. **금지어**: 패키지 `Sources/` 안에서는 주석 포함 서비스 앱 용어("MegaStudy" 등) 사용 금지. `PlayerModuleBoundaryTests`가 검사한다. 레거시 코드를 언급할 땐 "레거시 host 앱"으로 일반화.
3. **테스트 프레임워크**: Swift Testing (`import Testing`, `@Test`, `#expect`). XCTest 금지.
4. **UIKit 의존 테스트**: 반드시 `#if canImport(UIKit)` 가드로 감싼다 (테스트 타깃이 macOS에서도 컴파일됨).
5. **주석**: 코드로 표현 불가한 "왜"만 남긴다. 작업 트랙 번호(P1 등)·문서 참조를 주석에 쓰지 않는다.
6. 작업 후 검증 명령 (전 트랙 공통):

```bash
cd /Users/jimmy/Documents/GitLab/videoplayer-ios-ms
swift test
tuist generate
xcodebuild build -workspace VideoPlayerExample.xcworkspace -scheme VideoPlayerExample \
    -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 15'
```

---

## P1. 제스처 HUD 에셋 4종 추가 + 아이콘 fallback 수정

### 배경

- 레거시 host 앱은 밝기/볼륨/시킹 제스처 시 전용 이미지를 HUD에 표시. 신규 패키지 xcassets에 해당 이미지 4종이 없음.
- `PlayerGestureHUDView.applyIcon(_:)`(`Sources/VideoPlayerSkin/PlayerGestureHUDView.swift:156-168`)은 `UIImage(named:)`만 시도 → 실패 시 **icon 문자열을 텍스트 라벨로 표시**.
- Example은 `"sun.max"`, `"speaker.wave.2"` 같은 **SF Symbol 이름**을 전달 (`Example/Sources/Player/PlayerViewController.swift:242,245`) — `UIImage(named:)`로는 SF Symbol을 못 찾으므로 현재 항상 텍스트 `"sun.max"`가 그대로 화면에 보인다. 버그.

### 작업 1-1. 에셋 복사 (셸 명령)

```bash
SRC="/Users/jimmy/Documents/GitLab/smartlearning-ios-ms/SmartPlayer/SmartPlayer/Resource/Asset/Image.xcassets/Player"
DST="/Users/jimmy/Documents/GitLab/videoplayer-ios-ms/Sources/VideoPlayerSkin/Resources/PlayerSkin.xcassets"

for name in PlayerBrightnessNormal PlayerVolumeNormal PlayerBackwardGestureNormal PlayerForwardGestureNormal; do
  cp -R "${SRC}/${name}.imageset" "${DST}/"
done
```

- 각 imageset은 `Contents.json` + `@1x/@2x/@3x` PNG 3장 구조 (universal idiom). 복사만 하면 됨 — Contents.json 수정 불필요.
- 검증: `ls ${DST} | grep -c "Brightness\|Volume\|GestureNormal"` → imageset 4개 확인. 이후 Example 빌드 성공이면 xcassets 컴파일 통과.

### 작업 1-2. `applyIcon`에 SF Symbol 2차 fallback 추가

파일: `Sources/VideoPlayerSkin/PlayerGestureHUDView.swift`

현재 코드 (156-168행):

```swift
func applyIcon(_ icon: String) {
    if let image = UIImage(named: icon, in: .module, with: nil) ?? UIImage(named: icon) {
        imageView.image = image
        imageView.isHidden = false
        iconLabel.isHidden = true
        iconLabel.text = nil
    } else {
        imageView.image = nil
        imageView.isHidden = true
        iconLabel.isHidden = false
        iconLabel.text = icon
    }
}
```

변경 후:

```swift
func applyIcon(_ icon: String) {
    // 탐색 순서: 패키지 에셋 → host 메인 번들 에셋 → SF Symbol.
    // SF Symbol까지 없을 때만 텍스트로 노출한다(이모지 등 비에셋 아이콘 허용 목적).
    let resolved = UIImage(named: icon, in: .module, with: nil)
        ?? UIImage(named: icon)
        ?? UIImage(systemName: icon)
    if let image = resolved {
        imageView.image = image.withRenderingMode(.alwaysTemplate)
        imageView.tintColor = .white
        imageView.isHidden = false
        iconLabel.isHidden = true
        iconLabel.text = nil
    } else {
        imageView.image = nil
        imageView.isHidden = true
        iconLabel.isHidden = false
        iconLabel.text = icon
    }
}
```

주의: `withRenderingMode(.alwaysTemplate)`는 SF Symbol 흰색 통일 목적. 복사한 레거시 PNG가 원래 흰색이므로 template 적용해도 시각 변화 없음 — 단, 실기기에서 색 확인할 것. 색이 깨지면 `resolved`가 `UIImage(systemName:)`에서 온 경우에만 template 적용하도록 분기:

```swift
    let assetImage = UIImage(named: icon, in: .module, with: nil) ?? UIImage(named: icon)
    let symbolImage = assetImage == nil ? UIImage(systemName: icon) : nil
    if let image = assetImage ?? symbolImage {
        imageView.image = symbolImage == nil ? image : image.withRenderingMode(.alwaysTemplate)
        ...
```

### 작업 1-3. Example HUD 호출부를 레거시 에셋명으로 교체

파일: `Example/Sources/Player/PlayerViewController.swift` (didPan 내부, 242·245행 부근)

```swift
// 변경 전
skin.showGestureHUD(icon: "sun.max", title: "\(Int(value * 100))%")
...
skin.showGestureHUD(icon: "speaker.wave.2", title: "\(Int(value * 100))%")

// 변경 후
skin.showGestureHUD(icon: "PlayerBrightnessNormal", title: "\(Int(value * 100))%")
...
skin.showGestureHUD(icon: "PlayerVolumeNormal", title: "\(Int(value * 100))%")
```

### 엣지케이스

| 케이스 | 기대 동작 |
|---|---|
| 에셋명 오타 / 미존재 아이콘 | SF Symbol 탐색 후 실패 → 텍스트 라벨 (기존 동작 유지) |
| host가 자체 번들 에셋명 전달 | `UIImage(named: icon)` (메인 번들) 경로에서 해결 — 순서 유지 필수 |
| 이모지 아이콘 (`"▶"`) | `UIImage(systemName: "▶")`는 nil → 텍스트 라벨. `presentRate`가 이 경로 사용 중이므로 회귀 없음 |
| 다크/라이트 모드 | 레거시 PNG는 단일(흰색) — appearance variant 없음. 추가 작업 불필요 |

### 완료 기준

- [ ] xcassets에 imageset 4개 존재, Example 빌드 통과
- [ ] 시뮬레이터에서 좌측 팬 → 밝기 이미지 HUD, 우측 팬 → 볼륨 이미지 HUD 표시 (텍스트 fallback 아님)
- [ ] `swift test` 통과

---

## P2. 더블탭 제스처 액션 추가

### 배경

- 레거시: 더블탭 → 재생/일시정지 토글이 기본 ON. 설정 전환 시 화면 좌/우 더블탭 → ∓10초 스킵.
- 신규 `PlayerGestureAction`에 더블탭 케이스 없음. 인식기는 host(Example) 소유가 설계 — enum 케이스와 Example 조립 코드를 추가한다.

### 작업 2-1. enum 케이스 추가

파일: `Sources/VideoPlayerSkin/PlayerGestureAction.swift`

전체 교체본:

```swift
//
//  PlayerGestureAction.swift
//  SmartPlayer
//
//  Created by 모바일팀_정준영 on 2026/05/19.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import CoreGraphics
import Foundation

public enum PlayerGestureAction: Equatable {
    case toggleControlsVisibility
    case skipBackward
    case skipForward
    case seekPreview(TimeInterval, delta: TimeInterval)
    case seekEnded(TimeInterval)
    case brightnessPreview(Float)
    case volumePreview(Float)
    case pinchPreview(scale: CGFloat)
    case longPressBegan
    case longPressEnded
    /// 더블탭 — 재생/일시정지 토글 모드. 모드 선택(토글 vs 스킵)은 host 설정 책임.
    case doubleTapTogglePlayPause
    /// 더블탭 — 좌/우 스킵 모드. forward=true면 화면 우측 탭(앞으로).
    case doubleTapSkip(forward: Bool)
}
```

### 작업 2-2. Example 더블탭 인식기 조립

파일: `Example/Sources/Player/PlayerViewController.swift`

`configureGestures()` 현재 코드:

```swift
private func configureGestures() {
    let tap = UITapGestureRecognizer(target: self, action: #selector(didTapSurface))
    tap.delegate = self
    view.addGestureRecognizer(tap)

    let pinch = UIPinchGestureRecognizer(target: self, action: #selector(didPinch))
    view.addGestureRecognizer(pinch)

    let pan = UIPanGestureRecognizer(target: self, action: #selector(didPan))
    pan.delegate = self
    view.addGestureRecognizer(pan)
}
```

변경 후:

```swift
private func configureGestures() {
    let doubleTap = UITapGestureRecognizer(target: self, action: #selector(didDoubleTapSurface))
    doubleTap.numberOfTapsRequired = 2
    doubleTap.delegate = self
    view.addGestureRecognizer(doubleTap)

    let tap = UITapGestureRecognizer(target: self, action: #selector(didTapSurface))
    tap.delegate = self
    // 더블탭 실패 판정 전까지 단일 탭 보류 — 더블탭 첫 탭에 컨트롤이 토글되는 오인식 방지.
    tap.require(toFail: doubleTap)
    view.addGestureRecognizer(tap)

    let pinch = UIPinchGestureRecognizer(target: self, action: #selector(didPinch))
    view.addGestureRecognizer(pinch)

    let pan = UIPanGestureRecognizer(target: self, action: #selector(didPan))
    pan.delegate = self
    view.addGestureRecognizer(pan)
}
```

핸들러 추가 (`didTapSurface` 바로 아래):

```swift
@objc private func didDoubleTapSurface(_ recognizer: UITapGestureRecognizer) {
    guard PreferenceManager.useGesture else { return }
    guard viewModel.state.isLocked == false else { return }

    if PreferenceManager.useDoubleTapSkip {
        let isForward = recognizer.location(in: view).x >= view.bounds.midX
        let interval = TimeInterval(PreferenceManager.seekRangeSeconds)
        interactor.seekBy(isForward ? interval : -interval)
        skin.showGestureHUD(
            icon: isForward ? "PlayerForwardGestureNormal" : "PlayerBackwardGestureNormal",
            title: "\(isForward ? "+" : "-")\(PreferenceManager.seekRangeSeconds)초"
        )
    } else {
        interactor.togglePlayPause()
    }
}
```

### 작업 2-3. 설정 키 추가

파일: `Example/Sources/...의 PreferenceManager` (기존 `useGesture`, `seekRangeSeconds` 정의 위치와 같은 파일)

기존 프로퍼티들과 동일한 패턴으로 추가 (UserDefaults 백킹이면 동일 백킹 사용):

```swift
/// 더블탭 동작 모드 — false: 재생/일시정지 토글(기본), true: 좌/우 스킵.
static var useDoubleTapSkip: Bool {
    get { UserDefaults.standard.bool(forKey: "player.useDoubleTapSkip") }
    set { UserDefaults.standard.set(newValue, forKey: "player.useDoubleTapSkip") }
}
```

주의: `PreferenceManager`의 실제 구현 패턴을 먼저 열어 확인하고 그 파일의 기존 스타일(프로퍼티 래퍼 등)을 따를 것. 위 코드는 형태 예시.

### 엣지케이스

| 케이스 | 처리 |
|---|---|
| 단일 탭 지연 | `require(toFail:)`로 컨트롤 토글에 ~0.3초 지연 발생. 레거시도 동일 구조(더블탭 활성 시 단일 탭 보류) — 허용 |
| 버튼(UIControl) 위 더블탭 | 기존 `gestureRecognizer(_:shouldReceive:)`가 `touch.view is UIControl`을 제외 — doubleTap에도 `delegate = self` 지정했으므로 자동 적용 |
| 잠금(lock) 상태 | `viewModel.state.isLocked` 가드로 무시 |
| 스킵 모드에서 시작 0초 미만 / 종료 초과 | `interactor.seekBy`가 내부에서 clamp — 기존 `skipBackward`/`skipForward` 라우팅과 동일 경로이므로 추가 처리 불필요. (확인: `seekBy` 구현에 clamp 없으면 코어 reducer가 0..duration으로 자름 — 동작 확인만 할 것) |
| 정확히 midX 탭 | `>=` 기준 — 앞으로 스킵. 레거시(`width/2 이상 = 앞으로`)와 동일 |
| 재생 준비 전(duration=0) 더블탭 스킵 | seek 무의미 — 코어가 무시. 토글 모드는 play 명령으로 전달, 정상 |

### 테스트 (신규 파일)

파일: `Tests/VideoPlayerModuleTests/Skin/PlayerGestureActionTests.swift` (기존 Skin 테스트 위치 다르면 그곳에)

```swift
#if canImport(UIKit)
import Testing
@testable import VideoPlayerSkin

struct PlayerGestureActionTests {
    @Test("더블탭 스킵 케이스는 방향을 보존한다")
    func doubleTapSkipPreservesDirection() {
        #expect(PlayerGestureAction.doubleTapSkip(forward: true) != .doubleTapSkip(forward: false))
        #expect(PlayerGestureAction.doubleTapSkip(forward: true) == .doubleTapSkip(forward: true))
    }
}
#endif
```

(enum Equatable 검증 수준 — 라우팅 로직은 Example 타깃이므로 `VideoPlayerExampleTests`에 좌/우 판정 테스트를 두려면 판정 로직을 `x >= midX` 순수 함수로 추출해서 테스트한다.)

### 완료 기준

- [ ] 더블탭 → 재생/일시정지 토글 (기본 모드)
- [ ] `useDoubleTapSkip=true` 시 좌/우 더블탭 ∓N초 + HUD 표시
- [ ] 단일 탭 컨트롤 토글 여전히 동작 (지연 0.3초 이내)
- [ ] `swift test` + Example 빌드/테스트 통과

---

## P3. 줌 상태 화면 이동(pan move) 추가

### 배경

- 레거시: 핀치 확대 상태에서 팬 → 영상 표시 위치 이동. 비확대 상태 팬은 밝기/볼륨(상하)·시킹(좌우).
- 신규: 엔진 명령은 이미 존재 — `PlayerScrollEngine.scroll(by:)/stopScroll()` (`Sources/VideoPlayerCore/Contract/PlayerEngineAdapter.swift:119` 부근), `KollusPlayerAdapter` 구현 완료. **스킨 제스처 액션과 Example 라우팅만 부재.**
- 줌 상태 조회: `PlayerZoomEngine.isZoomedIn`(async)·`PlayerSynchronousZoomEngine`(동기 적용). Example `PlayerInteractor`는 `zoomEngine: PlayerSynchronousZoomEngine?`만 보유 (`PlayerInteractor.swift:40`).

### 작업 3-1. enum 케이스 추가

파일: `Sources/VideoPlayerSkin/PlayerGestureAction.swift` — P2 교체본에 한 줄 추가:

```swift
    /// 확대 상태에서 팬 — 영상 표시 위치 이동. translation은 직전 이벤트 이후 증분.
    case panMove(translation: CGPoint)
```

### 작업 3-2. Interactor에 scroll 경로 추가

파일: `Example/Sources/Player/PlayerInteractor.swift`

1. 프로퍼티 추가 (40행 `zoomEngine` 아래):

```swift
private var scrollEngine: PlayerScrollEngine?
/// 핀치 종료 시점에 갱신되는 캐시 — 팬 제스처는 매 이벤트 동기 판정이 필요해 async 조회 불가.
private(set) var isZoomedIn = false
```

2. 모듈 연결부 (75행 `zoomEngine = module.engine as? ...` 아래):

```swift
scrollEngine = module.engine as? PlayerScrollEngine
```

3. 해제부 (105행 `zoomEngine = nil` 아래):

```swift
scrollEngine = nil
isZoomedIn = false
```

4. 메서드 추가 (`applyZoom` 아래):

```swift
/// 핀치 종료 후 호출 — 엔진의 줌 상태를 캐시로 끌어온다.
func refreshZoomState() {
    Task { @MainActor [weak self] in
        guard let self, let module = self.playerModule else { return }
        guard let zoom = module.engine as? PlayerZoomEngine else { return }
        self.isZoomedIn = await zoom.isZoomedIn
    }
}

func scroll(by distance: CGPoint) {
    guard let scrollEngine else { return }
    Task { try? await scrollEngine.scroll(by: distance) }
}

func stopScroll() {
    guard let scrollEngine else { return }
    Task { try? await scrollEngine.stopScroll() }
}
```

주의: `playerModule`/`module.engine` 실제 프로퍼티명은 `PlayerInteractor.swift` 상단 확인 후 맞출 것 (위는 `handleSectionRepeat`에서 쓰는 `self.playerModule` 패턴 기준).

### 작업 3-3. Example 팬 라우팅 분기

파일: `Example/Sources/Player/PlayerViewController.swift`

1. `didPinch` 변경 — 종료 시 줌 상태 캐시 갱신:

```swift
@objc private func didPinch(_ recognizer: UIPinchGestureRecognizer) {
    guard PreferenceManager.useGesture else { return }
    interactor.applyZoom(recognizer)
    if recognizer.state == .ended || recognizer.state == .cancelled {
        interactor.refreshZoomState()
    }
}
```

2. `didPan` 변경 — 확대 상태면 화면 이동 우선 (전체 교체본):

```swift
@objc private func didPan(_ recognizer: UIPanGestureRecognizer) {
    guard PreferenceManager.useGesture else { return }
    guard viewModel.state.isLocked == false else { return }
    let translation = recognizer.translation(in: view)
    recognizer.setTranslation(.zero, in: view)

    // 모드는 began 시점에 한 번만 결정 — 제스처 중 확대 상태가 바뀌어도 모드 유지.
    if recognizer.state == .began {
        panIsMoveMode = interactor.isZoomedIn
        panIsLeftSide = recognizer.location(in: view).x < view.bounds.midX
    }

    if panIsMoveMode {
        switch recognizer.state {
        case .changed:
            interactor.scroll(by: translation)
        case .ended, .cancelled, .failed:
            interactor.stopScroll()
            panIsMoveMode = false
        default:
            break
        }
        return
    }

    let delta = -translation.y / view.bounds.height

    switch recognizer.state {
    case .changed:
        if panIsLeftSide {
            let value = deviceControl.adjustBrightness(by: delta)
            skin.showGestureHUD(icon: "PlayerBrightnessNormal", title: "\(Int(value * 100))%")
        } else {
            let value = deviceControl.adjustVolume(by: Float(delta))
            skin.showGestureHUD(icon: "PlayerVolumeNormal", title: "\(Int(value * 100))%")
        }
    case .ended, .cancelled, .failed:
        skin.hideGestureHUD()
    default:
        break
    }
}
```

3. 프로퍼티 추가 (기존 `panIsLeftSide` 선언 옆):

```swift
private var panIsMoveMode = false
```

### 엣지케이스

| 케이스 | 처리 |
|---|---|
| 팬 도중 핀치로 축소 | `panIsMoveMode`는 began에 고정 — 제스처 끝날 때까지 move 유지. 다음 팬부터 일반 모드 |
| 줌 캐시 stale (refreshZoomState Task 미완료 직후 팬 시작) | 한 제스처가 잘못된 모드로 동작할 수 있음 — 빈도 낮고 다음 제스처에서 회복. 허용. 더 엄밀하게 하려면 `applyZoom` 직후 매번 refresh |
| scroll Task 순서 역전 | `.changed` 이벤트마다 Task 생성 — actor 메일박스가 FIFO 보장하므로 단일 actor 호출 순서 유지. 단 stopScroll이 마지막 scroll보다 먼저 도착할 일은 없음(같은 actor) |
| 시뮬레이터 | Kollus 렌더 미동작 — scroll 효과 확인 불가. **실기기 검증 필수**, 결과 별도 기록 |
| 비Kollus 엔진 (AVPlayerAdapter) | `as? PlayerScrollEngine` 캐스팅 실패 → `scrollEngine=nil` → no-op. 크래시 없음 |

### 완료 기준

- [ ] 실기기: 핀치 확대 → 팬 → 영상 이동, 팬 종료 → 이동 정지
- [ ] 비확대 팬: 밝기/볼륨 기존 동작 불변
- [ ] AVPlayer 엔진 소스에서 팬 시 크래시/에러 없음
- [ ] `swift test` + Example 빌드 통과

---

## P4. 자막 폰트 크기 default 정렬

> 선행 조건: §7 결정 1에서 A안(레거시 정렬) 확정 시에만 작업.

### 작업 4-1. default 값 교체

파일: `Sources/VideoPlayerCore/Domain/PlayerFeatureSet.swift` (79-80행)

```swift
// 변경 전
captionFontSizes: [Int] = [14, 16, 18, 20, 22],
initialCaptionFontSize: Int = 16
// 변경 후
captionFontSizes: [Int] = [10, 15, 20, 25, 30, 35, 40],
initialCaptionFontSize: Int = 20
```

검증 로직 주의: init 내부에서 `initialCaptionFontSize`가 목록에 없으면 `resolvedSizes[0]`으로 강제된다 (`PlayerFeatureSet.swift:90`). 20은 목록에 있으므로 통과.

### 작업 4-2. 기존 default 의존 테스트 갱신

영향 테스트 탐색:

```bash
grep -rn "captionFontSize\|14, 16, 18\|fontSize" Tests/ Example/Tests/ 2>/dev/null
```

발견된 테스트 중 default 값을 그대로 단언하는 것(`#expect(... == 16)`, `== [14, 16, 18, 20, 22]` 등)을 새 값으로 교체. **테스트가 default가 아닌 명시 주입 값을 단언하면 건드리지 않는다.**

### 엣지케이스

| 케이스 | 처리 |
|---|---|
| 40pt 자막이 좁은 화면에서 잘림 | `PlayerCaptionView` 멀티라인/폭 제약 확인 — iPhone 세로에서 40pt 두 줄 자막 레이아웃 확인. 깨지면 caption 라벨 `numberOfLines`·폭 제약 조정 별도 이슈로 분리 |
| host가 이미 명시 주입 중 | default 변경 영향 없음 — 주입 값 우선 |
| Example 설정 화면 단계 수 | 5단계 → 7단계로 늘어남. 설정 UI가 개수 하드코딩이면 수정 (grep: `captionFontSizes` Example 내 사용처) |

### 완료 기준

- [ ] `swift test` 통과 (갱신된 단언 포함)
- [ ] Example 자막 크기 설정에서 7단계 선택 가능, 기본 20pt
- [ ] iPhone 세로 + 40pt 자막 레이아웃 확인 (시뮬레이터 캡처)

---

## P5. 제스처 HUD 표시 시간 주입형 전환

> 선행 조건: §7 결정 2 확정. default 값만 결정에 따름 — 주입형 전환 자체는 무조건 수행.

### 작업 5-1. 하드코딩 제거

파일: `Sources/VideoPlayerSkin/PlayerGestureHUDView.swift`

1. 프로퍼티 추가 (18행 `hideWorkItem` 아래):

```swift
/// show() 후 자동 숨김까지의 시간. 0 이하면 자동 숨김 없이 hide() 호출을 기다린다.
public var displayDuration: TimeInterval = 2.0
```

2. `show(...)` 끝부분 (49-53행) 변경:

```swift
// 변경 전
let workItem = DispatchWorkItem { [weak self] in
    self?.hide()
}
hideWorkItem = workItem
DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: workItem)

// 변경 후
guard displayDuration > 0 else { return }
let workItem = DispatchWorkItem { [weak self] in
    self?.hide()
}
hideWorkItem = workItem
DispatchQueue.main.asyncAfter(deadline: .now() + displayDuration, execute: workItem)
```

`presentRate(_:)`는 자동 숨김이 원래 없음(롱프레스 배속 홀드 중 유지 목적) — 건드리지 않는다.

### 엣지케이스

| 케이스 | 처리 |
|---|---|
| show 연타 (팬 .changed 매 이벤트) | 기존 `hideWorkItem?.cancel()`이 직전 예약 취소 — 마지막 show 기준으로 displayDuration 후 숨김. 동작 유지 |
| displayDuration 변경 시점이 show 이후 | 이미 예약된 workItem에는 미적용 — 다음 show부터. 문서화로 충분 |
| 0 이하 설정 | 자동 숨김 없음 — host가 `hideGestureHUD()` 직접 호출 (Example didPan의 `.ended` 경로가 이미 호출 중) |

### 테스트 (신규)

파일: `Tests/VideoPlayerModuleTests/Skin/PlayerGestureHUDViewTests.swift`

```swift
#if canImport(UIKit)
import Testing
import UIKit
@testable import VideoPlayerSkin

@MainActor
struct PlayerGestureHUDViewTests {
    @Test("show 직후 노출 상태가 된다")
    func showMakesVisible() {
        let hud = PlayerGestureHUDView()
        hud.show(icon: "PlayerBrightnessNormal", title: "50%")
        #expect(hud.isHidden == false)
        #expect(hud.alpha == 1)
    }

    @Test("displayDuration 0 이하면 자동 숨김을 예약하지 않는다")
    func nonPositiveDurationSkipsAutoHide() {
        let hud = PlayerGestureHUDView()
        hud.displayDuration = 0
        hud.show(icon: "x", title: "t")
        #expect(hud.isHidden == false)
    }
}
#endif
```

(타이머 경과 검증은 비동기 대기 필요 — 불안정하므로 예약 여부까지만 단언.)

### 완료 기준

- [ ] HUD 표시 후 2.0초(결정값) 뒤 fade-out
- [ ] `swift test` 통과

---

## 6. 커밋 단위

```
feat: 제스처 HUD 레거시 에셋 추가 및 아이콘 탐색 fallback 보강   (P1)
feat: 더블탭 제스처 액션 추가 — 재생/일시정지·좌우 스킵          (P2)
feat: 확대 상태 팬 화면 이동 제스처 추가                          (P3)
fix: 자막 폰트 크기 기본값 레거시 host 앱 기준 정렬               (P4)
refactor: 제스처 HUD 표시 시간 주입형 전환                        (P5)
```

각 커밋 독립. PR base: `main`.

## 7. 결정 필요 사항

| # | 질문 | 선택지 | 권장 |
|---|---|---|---|
| 1 | 자막 크기 default | A) 10~40pt/20pt (레거시) B) 14~22pt/16pt 유지 | A |
| 2 | HUD 표시 시간 default | A) 2.0초 (레거시) B) 1.2초 유지 | A |
| 3 | 배속 컨트롤 위치 (review §4) | A) 우측 사이드 재현 B) 현행 유지 | 보류 — 디자인 확인 후 별도 트랙 |

## 8. 비범위

- 제스처 인식기 패키지 내장 — host 소유 유지 (경계 설계)
- 이어보기 확인 팝업·다음 강의 자동재생 — host 정책
- PiP — 양쪽 미지원, 별도 논의
