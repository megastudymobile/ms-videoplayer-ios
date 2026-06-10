# 시킹 프리뷰 썸네일 모달 + 토글 — 구현 명세

- 작성: JunyoungJung, 2026-06-10
- 상태: 설계 확정, 구현 전
- 이 문서는 **그대로 따라 치면 동작하는 수준**의 실행 명세다. 각 Step은 순서대로 수행하고, Step마다 명시된 검증 명령을 통과한 뒤 다음 Step으로 넘어간다.

---

## 0. 목표와 완료 기준

**목표**: 재생바(UISlider) 드래그 중 thumb 위에 프리뷰 모달(썸네일 이미지 + 시간 라벨)을 띄운다. 플레이어 내부 버튼으로 켜고 끌 수 있다.

**완료 기준 (전부 만족해야 완료)**:

1. Kollus 엔진: SDK 스프라이트 시트(`content.thumbnail`)에서 crop한 썸네일이 모달에 표시된다.
2. AVPlayer 엔진: `AVAssetImageGenerator`로 추출한 프레임이 모달에 표시된다.
3. 썸네일을 얻을 수 없으면(스프라이트 없음/추출 실패) **시간 라벨만 있는 작은 모달**이 표시된다 — 모달을 숨기지 않는다.
4. 드래그 중 실제 엔진 seek은 발생하지 않는다(현행 유지). 손을 떼면(`seekEnded`) seek된다(현행 유지).
5. 플레이어 상단 메뉴의 토글 버튼으로 on/off. 설정은 `UserDefaults`(`useSeekPreview`, 기본 `true`)에 영구 저장.
6. `swift test` 통과 + Example 앱 시뮬레이터 빌드/테스트 통과.

**하지 말 것**:

- `PlayerSkin` 프로토콜, `PlayerSkinAction` enum, `PlaybackCommand`를 변경하지 않는다.
- `Example/Sources/Player/PlayerViewController.swift`의 `route(_:)` 안 `.seekBegan`/`.seekPreviewChanged`/`.seekEnded` 케이스를 변경하지 않는다.
- `Sources/VideoPlayerCore`에 Kollus/AVFoundation import를 추가하지 않는다.
- `KollusSignalMapper.swift`를 변경하지 않는다.
- 새 파일 주석에 서비스 앱 용어(예: "MegaStudy")를 쓰지 않는다 — `PlayerModuleBoundaryTests`가 빌드에서 잡는다.

**검증 명령 (Step마다 사용)**:

```bash
# 패키지 테스트 (macOS — Kollus/Native/Skin 테스트는 iOS 조건이라 자동 제외됨)
swift test

# Example 앱 빌드/테스트
tuist generate
xcodebuild build -workspace VideoPlayerExample.xcworkspace -scheme VideoPlayerExample \
    -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 15'
xcodebuild test -workspace VideoPlayerExample.xcworkspace -scheme VideoPlayerExample \
    -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 15'
```

---

## 1. 아키텍처 요약 (왜 이 모양인가)

```
[드래그]                    [이미지 공급]
ProgressBarBlock            PlayerSeekPreviewEngine (capability protocol, Core)
  │ onScrubTick(매 틱)        ▲ 채택              ▲ 채택
  │ .seekPreviewChanged       │                   │
  │  (0.12s throttle)     KollusPlayerAdapter  AVPlayerAdapter
  ▼                           (스프라이트 crop)   (AVAssetImageGenerator)
AssembledPlayerSkin ──────────┐
  │ 액션 가로채기              │ seekPreviewImageProvider (async closure,
  ▼                           │  Example PlayerViewController가 주입)
PlayerSeekPreviewPresenter ◄──┘
  ▼
PlayerSeekPreviewView (모달)
```

- **Skin은 엔진을 모른다** (Package.swift 의존 그래프). 그래서 이미지 공급은 host(Example)가 `async closure`로 주입한다.
- **켜기/끄기 가용성**은 기존 capability 협상 패턴 그대로: 엔진이 `PlayerSeekPreviewEngine`을 채택하면 `PlayerFeatureAvailability.probe`가 `.seekPreview`를 켠다. Example은 `.seekPreview` 가용 시에만 토글 버튼을 노출한다.
- **모달 위치 추적은 매 틱**(`onScrubTick`), **이미지 요청은 0.12초 throttle**(기존 `.seekPreviewChanged` 재사용). 위치가 8Hz로 끊기면 안 되고, 이미지 디코드가 매 틱 돌면 안 되기 때문.

---

## 2. Step 1 — Core 계약 (capability protocol + availability)

### 2-1. `Sources/VideoPlayerCore/Contract/PlayerEngineAdapter.swift`

**찾기** (100~116행, 기존 `#if canImport(UIKit)` 블록의 끝):

```swift
public protocol PlayerSynchronousZoomEngine {
    func applyZoomGesture(_ recognizer: UIPinchGestureRecognizer)
}
#endif
```

**변경** — `#endif` 직전에 프로토콜 추가:

```swift
public protocol PlayerSynchronousZoomEngine {
    func applyZoomGesture(_ recognizer: UIPinchGestureRecognizer)
}

/// 시킹 스크럽 중 특정 시각의 프리뷰 프레임을 제공한다.
/// 실패 원인(스프라이트 없음/추출 실패/취소)은 UI에서 전부 동일한 라벨-only 폴백으로
/// 수렴하므로 throws 대신 nil로 통일한다.
public protocol PlayerSeekPreviewEngine: Actor {
    func seekPreviewImage(at time: TimeInterval) async -> UIImage?
}
#endif
```

### 2-2. `Sources/VideoPlayerCore/Domain/PlayerFeatureAvailability.swift`

**변경 1** — 상수 목록 끝(31행 `displayLock` 다음 줄)에 추가:

```swift
    public static let displayLock       = PlayerFeatureAvailability(rawValue: 1 << 10)
    public static let seekPreview       = PlayerFeatureAvailability(rawValue: 1 << 11)
```

**변경 2** — `probe(_:)`의 기존 `#if canImport(UIKit)` 블록(48~50행)에 한 줄 추가:

```swift
        #if canImport(UIKit)
        if engine is any PlayerZoomEngine { features.insert(.zoom) }
        if engine is any PlayerSeekPreviewEngine { features.insert(.seekPreview) }
        #endif
```

**검증**: `swift build` 성공.

---

## 3. Step 2 — Kollus 엔진 (스프라이트 crop)

### 3-1. 신규 파일 `Sources/VideoPlayerEngineKollus/Playback/KollusSeekPreviewSource.swift`

전문 그대로 생성:

```swift
//
//  KollusSeekPreviewSource.swift
//  VideoPlayerModule
//
//  Created by JunyoungJung on 2026/06/10.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

import CoreGraphics
import Foundation
import UIKit

/// 스프라이트 썸네일 파일명 `{이름}.{tileW}x{tileH}x{count}.{확장자}`의 그리드 메타.
/// UIKit 이미지 로드와 분리된 순수 타입 — 파싱/인덱스 계산을 단독 테스트한다.
struct KollusThumbnailSpriteLayout: Equatable, Sendable {
    let tileWidth: Int
    let tileHeight: Int
    let tileCount: Int

    /// 파일명에서 메타를 파싱한다. 콘텐츠 이름에 `.`이 포함될 수 있으므로
    /// "확장자 바로 앞 컴포넌트"만 본다. 형식이 아니면 nil.
    init?(fileName: String) {
        let withoutExtension = (fileName as NSString).deletingPathExtension
        guard let token = withoutExtension.components(separatedBy: ".").last else { return nil }
        let parts = token.components(separatedBy: "x")
        guard parts.count == 3,
              let width = Int(parts[0]), width > 0,
              let height = Int(parts[1]), height > 0,
              let count = Int(parts[2]), count > 0 else { return nil }
        self.tileWidth = width
        self.tileHeight = height
        self.tileCount = count
    }

    /// 재생 시각 → 타일 인덱스. 항상 `0..<tileCount`로 클램프.
    func tileIndex(at time: TimeInterval, duration: TimeInterval) -> Int {
        guard duration > 0 else { return 0 }
        let raw = Int((time / duration) * Double(tileCount))
        return min(max(raw, 0), tileCount - 1)
    }

    /// 타일 인덱스 → 스프라이트 안 crop 영역(픽셀 좌표).
    func tileRect(at index: Int, columns: Int) -> CGRect {
        let safeColumns = max(1, columns)
        return CGRect(
            x: (index % safeColumns) * tileWidth,
            y: (index / safeColumns) * tileHeight,
            width: tileWidth,
            height: tileHeight
        )
    }
}

/// 스프라이트 시트를 1회 로드해 캐시하고, 시각에 해당하는 타일을 crop해 돌려준다.
/// KollusPlayerAdapter actor가 소유한다 — 디코드/crop이 actor executor(비-메인)에서 수행된다.
final class KollusSeekPreviewSource {
    let path: String
    private let layout: KollusThumbnailSpriteLayout
    private var spriteCGImage: CGImage?
    /// 파일이 아직 다운로드 중이면 로드가 실패할 수 있다. 실패도 캐시해 스크럽 틱마다
    /// 디스크를 두드리지 않는다 — `.thumbnailReady` 신호가 source 자체를 무효화해 재시도시킨다.
    private var didAttemptLoad = false

    init?(thumbnailPath: String) {
        guard thumbnailPath.isEmpty == false,
              let layout = KollusThumbnailSpriteLayout(
                  fileName: (thumbnailPath as NSString).lastPathComponent
              ) else { return nil }
        self.path = thumbnailPath
        self.layout = layout
    }

    func previewImage(at time: TimeInterval, duration: TimeInterval) -> UIImage? {
        guard duration > 0, let sprite = loadSpriteIfNeeded() else { return nil }
        // 열 수는 파일명이 아니라 실제 스프라이트 폭으로 산출한다 — "10열"은 레퍼런스 앱
        // 관례일 뿐 SDK 계약이 아니다.
        let columns = max(1, sprite.width / max(1, layout.tileWidth))
        let index = layout.tileIndex(at: time, duration: duration)
        let rect = layout.tileRect(at: index, columns: columns)
        guard let cropped = sprite.cropping(to: rect) else { return nil }
        return UIImage(cgImage: cropped)
    }

    private func loadSpriteIfNeeded() -> CGImage? {
        if didAttemptLoad { return spriteCGImage }
        didAttemptLoad = true
        spriteCGImage = UIImage(contentsOfFile: path)?.cgImage
        return spriteCGImage
    }
}
```

### 3-2. `Sources/VideoPlayerEngineKollus/KollusPlayerAdapter.swift` — 4곳 수정

**(a) conformance 추가** — **찾기** (26~37행):

```swift
    PlayerAdaptiveStreamingEngine,
    PlayerEngineOutputProducing {
```

**변경**:

```swift
    PlayerAdaptiveStreamingEngine,
    PlayerSeekPreviewEngine,
    PlayerEngineOutputProducing {
```

**(b) actor 상태 추가** — **찾기** (`private var bookmarkStore = KollusBookmarkStore()` 근처):

```swift
    private var bookmarkStore = KollusBookmarkStore()
```

**변경** (아래 줄 추가):

```swift
    private var bookmarkStore = KollusBookmarkStore()
    private var seekPreviewSource: KollusSeekPreviewSource?
```

**(c) `.thumbnailReady` 신호를 캐시 무효화로 소비** — **찾기** (`handleSignal` switch 끝부분, ~868행):

```swift
        case .scrollChanged,
             .zoomChanged,
             .contentModeChanged,
             .playbackRateChanged,
             .repeatChanged,
             .thumbnailReady,
             .mediaContentKeyResolved:
            // 도메인 중립 PlayerEvent로 표현되지 않는 vendor-specific 신호.
            // diagnostics sink는 KollusDelegateBridge에서 이미 forward됨.
            break
```

**변경** — `.thumbnailReady`를 ignore 목록에서 빼고 전용 case로:

```swift
        case .thumbnailReady:
            // 스프라이트가 비동기 다운로드로 뒤늦게 도착할 수 있다 — 캐시를 무효화해
            // 다음 프리뷰 요청이 파일을 다시 해석하게 한다.
            seekPreviewSource = nil

        case .scrollChanged,
             .zoomChanged,
             .contentModeChanged,
             .playbackRateChanged,
             .repeatChanged,
             .mediaContentKeyResolved:
            // 도메인 중립 PlayerEvent로 표현되지 않는 vendor-specific 신호.
            // diagnostics sink는 KollusDelegateBridge에서 이미 forward됨.
            break
```

**(d) 프로토콜 구현 추가** — `seek(to:)` 메서드(212~225행) 아래에 새 MARK 섹션으로 추가:

```swift
    // MARK: - PlayerSeekPreviewEngine

    public func seekPreviewImage(at time: TimeInterval) async -> UIImage? {
        // SDK 상태 조회는 메인, 스프라이트 디코드/crop은 actor — seek(to:)와 같은 경계.
        let snapshot = await MainActor.run { () -> (path: String, duration: TimeInterval)? in
            guard let view = playerView, view.isThumbnailEnable,
                  let path = view.content?.thumbnail as String?, path.isEmpty == false else {
                return nil
            }
            return (path, view.content?.duration ?? 0)
        }
        guard let snapshot, snapshot.duration > 0 else { return nil }
        if seekPreviewSource?.path != snapshot.path {
            seekPreviewSource = KollusSeekPreviewSource(thumbnailPath: snapshot.path)
        }
        return seekPreviewSource?.previewImage(at: time, duration: snapshot.duration)
    }
```

> 주의: `KollusContent.thumbnail`은 nullability 미표기 ObjC 프로퍼티다. `as String?` 캐스트로 옵셔널 취급할 것 — 직접 unwrap 금지.

**(e) 콘텐츠 교체 시 캐시 리셋** — `prepare(source:)` 본문 첫 줄(actor 컨텍스트)에 추가:

```swift
        seekPreviewSource = nil
```

(콘텐츠가 바뀌면 path 비교로도 재생성되지만, 같은 path 재진입 시 실패 캐시가 남는 것을 막는다.)

**검증**: `swift build` 성공 (macOS에서 Kollus 타깃은 빌드 제외 — Example 빌드 단계에서 최종 확인).

---

## 4. Step 3 — Native 엔진 (AVAssetImageGenerator)

### `Sources/VideoPlayerEngineNative/AVPlayerAdapter.swift` — 4곳 수정

**(a) conformance** — **찾기** (14행):

```swift
public actor AVPlayerAdapter: PlayerEngineAdapter, PlayerEngineOutputProducing, PlayerPlaybackRateEngine, PlayerDisplayScalingEngine {
```

**변경**:

```swift
public actor AVPlayerAdapter: PlayerEngineAdapter, PlayerEngineOutputProducing, PlayerPlaybackRateEngine, PlayerDisplayScalingEngine, PlayerSeekPreviewEngine {
```

**(b) actor 상태** — **찾기** (43행):

```swift
    private var displayScaleMode: PlayerDisplayScaleMode = .aspectFit
```

**변경** (아래 줄 추가):

```swift
    private var displayScaleMode: PlayerDisplayScaleMode = .aspectFit
    private var imageGenerator: AVAssetImageGenerator?
    /// generator가 어떤 asset용인지 추적 — 콘텐츠 교체 시 재생성.
    private var imageGeneratorAsset: AVAsset?
```

**(c) 프로토콜 구현** — `seek(to:)` 메서드(179~202행) 아래에 추가:

```swift
    // MARK: - PlayerSeekPreviewEngine

    public func seekPreviewImage(at time: TimeInterval) async -> UIImage? {
        guard let item = player.currentItem else { return nil }
        let duration = Self.duration(for: item)
        // 라이브/indefinite(duration 0)은 프리뷰 대상이 아니다.
        guard duration > 0 else { return nil }

        let asset = item.asset
        let generator: AVAssetImageGenerator
        if let existing = imageGenerator, imageGeneratorAsset === asset {
            generator = existing
        } else {
            let created = AVAssetImageGenerator(asset: asset)
            created.appliesPreferredTrackTransform = true
            // 모달 표시 크기(@3x) 상한 — 디코드 비용 제한. tolerance는 기본(느슨) 유지:
            // 스크럽 프리뷰는 프레임 정확도보다 응답성이 중요하다.
            created.maximumSize = CGSize(width: 480, height: 270)
            imageGenerator = created
            imageGeneratorAsset = asset
            generator = created
        }

        // 직전 스크럽 틱의 미완료 요청을 먼저 취소 — 요청이 쌓여 밀리는 것을 방지.
        generator.cancelAllCGImageGeneration()

        let clamped = min(max(0, time), duration)
        let target = CMTime(seconds: clamped, preferredTimescale: 600)
        return await withCheckedContinuation { continuation in
            // requestedTimes가 1건이므로 handler는 정확히 1회 호출된다
            // (.succeeded/.failed/.cancelled 중 하나) — continuation 1회 resume 보장.
            generator.generateCGImagesAsynchronously(forTimes: [NSValue(time: target)]) { _, cgImage, _, result, _ in
                guard result == .succeeded, let cgImage else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: UIImage(cgImage: cgImage))
            }
        }
    }
```

**(d) 정리 경로** — `stop(reason:)` 본문 첫 줄(`cleanupCurrentItemObservers()` 호출 직전)에 추가:

```swift
        imageGenerator?.cancelAllCGImageGeneration()
        imageGenerator = nil
        imageGeneratorAsset = nil
```

같은 3줄을 `prepare(source:)`의 `cleanupCurrentItemObservers()` 호출 직전에도 추가 (콘텐츠 교체 대비 — asset identity 비교가 있어 없어도 동작하지만 명시 해제가 안전).

**검증**: `swift build` 성공.

---

## 5. Step 4 — Skin (모달 뷰 + presenter + 배선)

### 5-1. 신규 파일 `Sources/VideoPlayerSkin/PlayerSeekPreviewView.swift`

전문 그대로 생성:

```swift
//
//  PlayerSeekPreviewView.swift
//  SmartPlayer
//
//  Created by JunyoungJung on 2026/06/10.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import UIKit

/// 시킹 스크럽 프리뷰 모달 — 썸네일 이미지(16:9) + 시간 라벨.
/// 이미지가 없으면 시간 라벨만 있는 컴팩트 모드로 동작한다.
/// 위치/크기는 presenter가 frame으로 직접 제어한다(120Hz 추적) — Auto Layout 금지.
final class PlayerSeekPreviewView: UIView {
    private let imageView = UIImageView()
    private let timeLabel = UILabel()
    private(set) var hasImage = false

    private enum Metric {
        static let imageSize = CGSize(width: 142, height: 80)   // 16:9
        static let labelHeight: CGFloat = 24
        static let compactSize = CGSize(width: 88, height: 32)
    }

    /// presenter가 frame 계산에 사용하는 현재 모드의 콘텐츠 크기.
    var contentSize: CGSize {
        hasImage
            ? CGSize(width: Metric.imageSize.width,
                     height: Metric.imageSize.height + Metric.labelHeight)
            : Metric.compactSize
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.black.withAlphaComponent(0.85)
        layer.borderColor = UIColor.white.cgColor
        layer.borderWidth = 1
        layer.cornerRadius = 4
        clipsToBounds = true
        isUserInteractionEnabled = false

        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = .black
        timeLabel.textColor = .white
        timeLabel.font = .systemFont(ofSize: 13, weight: .bold)
        timeLabel.textAlignment = .center
        addSubview(imageView)
        addSubview(timeLabel)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    func setTime(_ text: String) {
        timeLabel.text = text
    }

    /// nil은 무시한다 — 스크럽 중 단발 실패로 직전 프레임이 사라지며 깜빡이는 것을 방지.
    /// 라벨-only 복귀는 스크럽 세션 시작(`resetForSession`)에서만 일어난다.
    func setImage(_ image: UIImage?) {
        guard let image else { return }
        hasImage = true
        imageView.image = image
        setNeedsLayout()
    }

    /// 스크럽 세션 시작 시 호출 — 직전 세션의 이미지를 비우고 컴팩트 모드로 시작.
    func resetForSession() {
        hasImage = false
        imageView.image = nil
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if hasImage {
            imageView.isHidden = false
            imageView.frame = CGRect(x: 0, y: 0,
                                     width: bounds.width,
                                     height: bounds.height - Metric.labelHeight)
            timeLabel.frame = CGRect(x: 0, y: bounds.height - Metric.labelHeight,
                                     width: bounds.width, height: Metric.labelHeight)
        } else {
            imageView.isHidden = true
            timeLabel.frame = bounds
        }
    }
}
```

### 5-2. 신규 파일 `Sources/VideoPlayerSkin/PlayerSeekPreviewPresenter.swift`

전문 그대로 생성:

```swift
//
//  PlayerSeekPreviewPresenter.swift
//  SmartPlayer
//
//  Created by JunyoungJung on 2026/06/10.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import UIKit

/// 스크럽 프리뷰 모달의 표시/이동/이미지 로드 상태머신.
/// AssembledPlayerSkin 내부 협력자 — 액션 가로채기(begin/move/request/end)로만 구동된다.
@MainActor
final class PlayerSeekPreviewPresenter {
    let view = PlayerSeekPreviewView()

    /// host가 주입하는 썸네일 공급자. nil이면 라벨-only 모달로 동작.
    var imageProvider: ((TimeInterval) async -> UIImage?)?
    /// false면 begin()이 무시된다(모달 자체가 뜨지 않음).
    var isEnabled = true

    private(set) var isActive = false
    private var inflightTask: Task<Void, Never>?
    /// 이미지 도착으로 모달 크기가 바뀔 때 같은 anchor로 재배치하기 위한 마지막 위치.
    private var lastAnchor: CGPoint?
    private var lastBounds: CGRect = .zero

    private enum Metric {
        static let edgeMargin: CGFloat = 8
        static let anchorGap: CGFloat = 8
        static let fadeDuration: TimeInterval = 0.15
    }

    init() {
        view.alpha = 0
        view.isHidden = true
    }

    func begin() {
        guard isEnabled else { return }
        isActive = true
        view.resetForSession()
        view.isHidden = false
        UIView.animate(withDuration: Metric.fadeDuration) { self.view.alpha = 1 }
    }

    /// 매 스크럽 틱 호출 — 시간 라벨 갱신 + 모달 frame 재배치.
    func move(time: TimeInterval, anchor: CGPoint, in bounds: CGRect) {
        guard isActive else { return }
        view.setTime(PlayerSkinState.formatTime(time))
        lastAnchor = anchor
        lastBounds = bounds
        reposition()
    }

    /// throttle된 틱에서 호출 — 직전 미완료 요청은 취소하고 최신 시각만 요청.
    func requestImage(at time: TimeInterval) {
        guard isActive, let imageProvider else { return }
        inflightTask?.cancel()
        inflightTask = Task { [weak self] in
            let image = await imageProvider(time)
            guard Task.isCancelled == false, let self, self.isActive else { return }
            self.view.setImage(image)
            // 라벨-only → 이미지 모드 전환 시 크기가 커진다 — 같은 anchor로 재배치.
            self.reposition()
        }
    }

    func end() {
        isActive = false
        inflightTask?.cancel()
        inflightTask = nil
        lastAnchor = nil
        UIView.animate(
            withDuration: Metric.fadeDuration,
            animations: { self.view.alpha = 0 },
            completion: { _ in
                if self.isActive == false { self.view.isHidden = true }
            }
        )
    }

    private func reposition() {
        guard let anchor = lastAnchor else { return }
        let size = view.contentSize
        let halfWidth = size.width / 2
        let minX = halfWidth + Metric.edgeMargin
        let maxX = lastBounds.width - halfWidth - Metric.edgeMargin
        // 화면이 모달보다 좁으면 중앙 고정.
        let centerX = maxX < minX ? lastBounds.midX : min(max(anchor.x, minX), maxX)
        let centerY = max(anchor.y - size.height / 2 - Metric.anchorGap,
                          size.height / 2 + Metric.edgeMargin)
        view.bounds = CGRect(origin: .zero, size: size)
        view.center = CGPoint(x: centerX, y: centerY)
    }
}
```

### 5-3. `Sources/VideoPlayerSkin/Blocks/ProgressBarBlock.swift` — 3곳 수정

**(a) 프로퍼티 추가** — **찾기** (11행):

```swift
    public var onAction: ((PlayerSkinAction) -> Void)?
```

**변경**:

```swift
    public var onAction: ((PlayerSkinAction) -> Void)?
    /// 스크럽 매 틱 콜백 — `.seekPreviewChanged`는 throttle되므로 모달 위치 추적용으로 분리.
    /// AssembledPlayerSkin이 배선한다.
    var onScrubTick: ((TimeInterval) -> Void)?

    /// 현재 슬라이더 값이 가리키는 프리뷰 시각.
    var currentPreviewTime: TimeInterval {
        PlayerSkinState.previewTime(for: slider.value, duration: latestDuration)
    }

    /// thumb 상단 중심점을 대상 좌표계로 변환 — 프리뷰 모달 anchor.
    func seekPreviewAnchor(in coordinateSpace: UICoordinateSpace) -> CGPoint {
        let trackRect = slider.trackRect(forBounds: slider.bounds)
        let thumbRect = slider.thumbRect(forBounds: slider.bounds,
                                         trackRect: trackRect,
                                         value: slider.value)
        return slider.convert(CGPoint(x: thumbRect.midX, y: thumbRect.minY), to: coordinateSpace)
    }
```

**(b) `seekBegan()` 끝에 첫 틱 발행** — **찾기** (89~96행):

```swift
    @objc private func seekBegan() {
        isSeeking = true
        // 드래그 시작 순간엔 첫 프리뷰 seek을 한 interval 미룬다 — touch-down의 pause(Kollus 메인)와
        // 첫 엔진 seek이 겹쳐 시작이 버벅이던 문제 방지. 0으로 리셋하면 첫 seekChanged가 즉시 seek한다.
        lastPreviewEmit = CACurrentMediaTime()
        // 스크러버를 잡는 순간 host 가 재생을 멈춘다(pause).
        onAction?(.seekBegan)
    }
```

**변경** — 마지막에 한 줄 추가:

```swift
    @objc private func seekBegan() {
        isSeeking = true
        // 드래그 시작 순간엔 첫 프리뷰 seek을 한 interval 미룬다 — touch-down의 pause(Kollus 메인)와
        // 첫 엔진 seek이 겹쳐 시작이 버벅이던 문제 방지. 0으로 리셋하면 첫 seekChanged가 즉시 seek한다.
        lastPreviewEmit = CACurrentMediaTime()
        // 스크러버를 잡는 순간 host 가 재생을 멈춘다(pause).
        onAction?(.seekBegan)
        // .seekBegan 가로채기(begin)가 끝난 뒤 첫 위치를 잡도록 액션 다음에 발행한다.
        onScrubTick?(currentPreviewTime)
    }
```

**(c) `seekChanged()`에 매 틱 발행** — **찾기** (97~106행):

```swift
    @objc private func seekChanged() {
        let time = PlayerSkinState.previewTime(for: slider.value, duration: latestDuration)
        // thumb은 UISlider가 네이티브로 추적하고, 시간 라벨은 매 틱 갱신(가벼움).
        currentTimeLabel.text = PlayerSkinState.formatTime(time)
```

**변경** — 라벨 갱신 다음 줄에 추가:

```swift
    @objc private func seekChanged() {
        let time = PlayerSkinState.previewTime(for: slider.value, duration: latestDuration)
        // thumb은 UISlider가 네이티브로 추적하고, 시간 라벨은 매 틱 갱신(가벼움).
        currentTimeLabel.text = PlayerSkinState.formatTime(time)
        onScrubTick?(time)
```

(이후의 throttle 가드와 `onAction?(.seekPreviewChanged(time))`는 그대로 둔다.)

### 5-4. `Sources/VideoPlayerSkin/Assembly/AssembledPlayerSkin.swift` — 5곳 수정

**(a) presenter 프로퍼티** — **찾기** (21행):

```swift
    private let gestureHUDOverlay: PlayerSkinGestureHUDOverlay
```

**변경**:

```swift
    private let gestureHUDOverlay: PlayerSkinGestureHUDOverlay
    private let seekPreviewPresenter = PlayerSeekPreviewPresenter()
```

**(b) 뷰 계층 삽입** — `buildSkeleton()`에서 **찾기** (142행, gestureHUD 추가 직전):

```swift
        let gestureHUDView = gestureHUDOverlay.view
```

**변경** — 그 직전에 추가 (슬롯 스택 위, gestureHUD 아래 z-order. frame 기반이라 constraint 없음):

```swift
        addSubview(seekPreviewPresenter.view)

        let gestureHUDView = gestureHUDOverlay.view
```

**(c) 액션 가로채기 + onScrubTick 배선** — **찾기** (`assembleBlocks()`, 208~218행):

```swift
    private func assembleBlocks() {
        for slot in PlayerSkinSlot.allCases {
            guard let container = slotContainers[slot], let makers = blueprint.blocks[slot] else { continue }
            for make in makers {
                let block = make()
                block.onAction = { [weak self] action in self?.onAction?(action) }
                container.addArrangedSubview(block.view)
                blocks.append(block)
            }
        }
    }
```

**변경**:

```swift
    private func assembleBlocks() {
        for slot in PlayerSkinSlot.allCases {
            guard let container = slotContainers[slot], let makers = blueprint.blocks[slot] else { continue }
            for make in makers {
                let block = make()
                block.onAction = { [weak self] action in
                    self?.interceptForSeekPreview(action)
                    self?.onAction?(action)
                }
                container.addArrangedSubview(block.view)
                blocks.append(block)
            }
        }
        for bar in blocks.compactMap({ $0 as? ProgressBarBlock }) {
            bar.onScrubTick = { [weak self, weak bar] time in
                guard let self, let bar else { return }
                self.seekPreviewPresenter.move(
                    time: time,
                    anchor: bar.seekPreviewAnchor(in: self),
                    in: self.bounds
                )
            }
        }
    }

    /// 시킹 프리뷰 모달은 skin이 자체 처리한다 — host 라우팅과 무관하게 액션을 관찰만 한다.
    private func interceptForSeekPreview(_ action: PlayerSkinAction) {
        switch action {
        case .seekBegan:
            guard latestState.isSeekEnabled, latestState.duration > 0 else { return }
            seekPreviewPresenter.begin()
            if let bar = blocks.compactMap({ $0 as? ProgressBarBlock }).first {
                seekPreviewPresenter.requestImage(at: bar.currentPreviewTime)
            }
        case .seekPreviewChanged(let time):
            seekPreviewPresenter.requestImage(at: time)
        case .seekEnded:
            seekPreviewPresenter.end()
        default:
            break
        }
    }
```

**(d) 잠금 시 강제 종료** — `render(_:)`에서 **찾기** (56~58행):

```swift
    public func render(_ state: PlayerSkinState) {
        latestState = state
        applyLegacyMetrics(state)
```

**변경**:

```swift
    public func render(_ state: PlayerSkinState) {
        latestState = state
        // 드래그 도중 잠금되면 touchCancel을 기다리지 않고 모달을 닫는다.
        if state.isLocked { seekPreviewPresenter.end() }
        applyLegacyMetrics(state)
```

**(e) 공개 API** — `hideGestureHUD()`(78~80행) 아래에 추가:

```swift
    /// host가 주입하는 시킹 프리뷰 썸네일 공급자. nil이면 시간 라벨만 표시된다.
    public var seekPreviewImageProvider: ((TimeInterval) async -> UIImage?)? {
        get { seekPreviewPresenter.imageProvider }
        set { seekPreviewPresenter.imageProvider = newValue }
    }

    /// 시킹 프리뷰 모달 on/off. off 전환 시 표시 중이면 즉시 닫는다.
    public func setSeekPreviewEnabled(_ enabled: Bool) {
        seekPreviewPresenter.isEnabled = enabled
        if enabled == false { seekPreviewPresenter.end() }
    }
```

**검증**: `swift build` 성공.

---

## 6. Step 5 — Example 앱 (토글 + 공급자 배선)

### 6-1. `Example/Sources/Settings/PreferenceManager.swift`

**찾기** (174~176행):

```swift
    /// 화면 제스처 사용 — 실연동(PlayerViewController 핀치줌/팬 밝기·음량 게이트).
    @UserDefault("useGesture", defaultValue: true)
    static var useGesture: Bool
```

**변경** — 아래에 추가:

```swift
    /// 화면 제스처 사용 — 실연동(PlayerViewController 핀치줌/팬 밝기·음량 게이트).
    @UserDefault("useGesture", defaultValue: true)
    static var useGesture: Bool

    /// 시킹 프리뷰 썸네일 — 실연동(플레이어 상단 메뉴 토글 버튼).
    @UserDefault("useSeekPreview", defaultValue: true)
    static var useSeekPreview: Bool
```

### 6-2. `Example/Sources/Player/PlayerInteractor.swift` — 3곳 수정

**(a) 프로퍼티** — **찾기** (~41행):

```swift
    // capability protocol 캐스트 — 시뮬레이터(UnsupportedEnvironmentEngine)에서는 nil.
    private var zoomEngine: PlayerSynchronousZoomEngine?
```

**변경**:

```swift
    // capability protocol 캐스트 — 시뮬레이터(UnsupportedEnvironmentEngine)에서는 nil.
    private var zoomEngine: PlayerSynchronousZoomEngine?
    private var seekPreviewEngine: (any PlayerSeekPreviewEngine)?
```

**(b) setUp에서 캐스트** — **찾기**:

```swift
        zoomEngine = module.engine as? PlayerSynchronousZoomEngine
```

**변경**:

```swift
        zoomEngine = module.engine as? PlayerSynchronousZoomEngine
        seekPreviewEngine = module.engine as? any PlayerSeekPreviewEngine
```

**(c) tearDown 해제 + 조회 메서드** — `tearDown()`에서 **찾기**:

```swift
        zoomEngine = nil
```

**변경**:

```swift
        zoomEngine = nil
        seekPreviewEngine = nil
```

그리고 `seekBy(_:)` 메서드 아래에 추가:

```swift
    /// 시킹 프리뷰 썸네일 조회 — 실패/미지원은 nil (skin이 라벨-only로 폴백).
    func seekPreviewImage(at time: TimeInterval) async -> UIImage? {
        guard isDisposed == false else { return nil }
        return await seekPreviewEngine?.seekPreviewImage(at: time)
    }
```

### 6-3. `Example/Sources/Player/PlayerViewController.swift` — 3곳 수정

**(a) ExtraControl 보관 프로퍼티 + ID** — **찾기** (345~347행):

```swift
    private enum ExtraControlID {
        static let bookmark = "bookmark"
    }
```

**변경**:

```swift
    private enum ExtraControlID {
        static let bookmark = "bookmark"
        static let seekPreview = "seekPreview"
    }

    /// 토글 시 isSelected를 갱신해 재주입해야 하므로 보관한다.
    private var extraControls: [ExtraControl] = []
```

**(b) `applyFeatureGating(_:)` 교체** — **찾기** (150~158행):

```swift
    private func applyFeatureGating(_ features: PlayerFeatureAvailability) {
        var extraControls: [ExtraControl] = []
        if features.contains(.bookmarks) {
            extraControls.append(
                ExtraControl(id: ExtraControlID.bookmark, iconName: "bookmark", title: "북마크", placement: .topMenu)
            )
        }
        skin.setExtraControls(extraControls)
    }
```

**변경** — 전체 교체:

```swift
    private func applyFeatureGating(_ features: PlayerFeatureAvailability) {
        var controls: [ExtraControl] = []
        if features.contains(.bookmarks) {
            controls.append(
                ExtraControl(id: ExtraControlID.bookmark, iconName: "bookmark", title: "북마크", placement: .topMenu)
            )
        }
        if features.contains(.seekPreview) {
            controls.append(
                ExtraControl(
                    id: ExtraControlID.seekPreview,
                    iconName: "photo.on.rectangle",
                    selectedIconName: "photo.on.rectangle.fill",
                    title: "시킹 미리보기",
                    placement: .topMenu,
                    isSelected: PreferenceManager.useSeekPreview
                )
            )
            skin.seekPreviewImageProvider = { [weak self] time in
                await self?.interactor.seekPreviewImage(at: time)
            }
            skin.setSeekPreviewEnabled(PreferenceManager.useSeekPreview)
        }
        extraControls = controls
        skin.setExtraControls(controls)
    }
```

**(c) `handleExtraControl(_:)` 교체** — **찾기** (349~352행):

```swift
    private func handleExtraControl(_ id: String) {
        guard id == ExtraControlID.bookmark else { return }
        presentBookmarkSheet()
    }
```

**변경** — 전체 교체 + 토글 메서드 추가:

```swift
    private func handleExtraControl(_ id: String) {
        switch id {
        case ExtraControlID.bookmark:
            presentBookmarkSheet()
        case ExtraControlID.seekPreview:
            toggleSeekPreview()
        default:
            break
        }
    }

    private func toggleSeekPreview() {
        let enabled = PreferenceManager.useSeekPreview == false
        PreferenceManager.useSeekPreview = enabled
        skin.setSeekPreviewEnabled(enabled)
        if let index = extraControls.firstIndex(where: { $0.id == ExtraControlID.seekPreview }) {
            extraControls[index].isSelected = enabled
            skin.setExtraControls(extraControls)
        }
        showToast(enabled ? "시킹 미리보기 사용" : "시킹 미리보기 사용 안함")
    }
```

> 참고: `.topMenu` ExtraControl은 가로(fullScreen) 모드에서만 노출된다 — 북마크 버튼과 동일한 기존 동작이므로 수용한다.

**검증**: `tuist generate` + Example 빌드 성공.

---

## 7. Step 6 — 테스트

### 7-1. 신규 파일 `Tests/VideoPlayerModuleTests/Kollus/KollusThumbnailSpriteLayoutTests.swift`

전문 그대로 생성:

```swift
//
//  KollusThumbnailSpriteLayoutTests.swift
//  VideoPlayerModuleTests
//
//  Created by JunyoungJung on 2026/06/10.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

#if canImport(UIKit)
import Foundation
import Testing
@testable import VideoPlayerEngineKollus

@Suite("Kollus 스프라이트 썸네일 레이아웃 — 파일명 파싱/인덱스/crop 영역")
struct KollusThumbnailSpriteLayoutTests {

    @Test("표준 파일명 파싱")
    func parsesStandardFileName() throws {
        let layout = try #require(KollusThumbnailSpriteLayout(fileName: "thumbnail.160x90x100.jpg"))
        #expect(layout.tileWidth == 160)
        #expect(layout.tileHeight == 90)
        #expect(layout.tileCount == 100)
    }

    @Test("콘텐츠 이름에 점이 있어도 확장자 직전 토큰만 본다")
    func parsesFileNameContainingDots() throws {
        let layout = try #require(KollusThumbnailSpriteLayout(fileName: "강의.1강.오리엔테이션.320x180x60.png"))
        #expect(layout.tileWidth == 320)
        #expect(layout.tileCount == 60)
    }

    @Test("형식이 아니면 nil", arguments: [
        "lec.jpg",            // 메타 토큰 없음
        "lec.axbxc.jpg",      // 숫자가 아님
        "lec.160x90.jpg",     // 컴포넌트 2개
        "lec.0x90x100.jpg",   // 0 크기
        "lec.160x90x0.jpg"    // 타일 0개
    ])
    func rejectsInvalidFileName(_ fileName: String) {
        #expect(KollusThumbnailSpriteLayout(fileName: fileName) == nil)
    }

    @Test("타일 인덱스 — 경계 클램프")
    func tileIndexClampsToBounds() throws {
        let layout = try #require(KollusThumbnailSpriteLayout(fileName: "t.160x90x100.jpg"))
        #expect(layout.tileIndex(at: -5, duration: 100) == 0)
        #expect(layout.tileIndex(at: 0, duration: 100) == 0)
        #expect(layout.tileIndex(at: 50, duration: 100) == 50)
        #expect(layout.tileIndex(at: 100, duration: 100) == 99)   // time == duration → 마지막 타일
        #expect(layout.tileIndex(at: 999, duration: 100) == 99)
        #expect(layout.tileIndex(at: 10, duration: 0) == 0)       // duration 0 방어
    }

    @Test("crop 영역 — 10열 그리드 wrap")
    func tileRectWrapsByColumns() throws {
        let layout = try #require(KollusThumbnailSpriteLayout(fileName: "t.160x90x100.jpg"))
        #expect(layout.tileRect(at: 0, columns: 10) == CGRect(x: 0, y: 0, width: 160, height: 90))
        #expect(layout.tileRect(at: 9, columns: 10) == CGRect(x: 1440, y: 0, width: 160, height: 90))
        #expect(layout.tileRect(at: 10, columns: 10) == CGRect(x: 0, y: 90, width: 160, height: 90))
        #expect(layout.tileRect(at: 99, columns: 10) == CGRect(x: 1440, y: 810, width: 160, height: 90))
    }

    @Test("columns 0 방어 — 1열로 처리")
    func tileRectGuardsZeroColumns() throws {
        let layout = try #require(KollusThumbnailSpriteLayout(fileName: "t.160x90x4.jpg"))
        #expect(layout.tileRect(at: 2, columns: 0) == CGRect(x: 0, y: 180, width: 160, height: 90))
    }
}
#endif
```

### 7-2. `Tests/VideoPlayerModuleTests/Core/PlayerFeatureAvailabilityTests.swift` 추가

파일 끝(기존 Fakes 아래)에 추가:

```swift
#if canImport(UIKit)
import UIKit

extension PlayerFeatureAvailabilityTests {
    @Test("PlayerSeekPreviewEngine 채택 → .seekPreview 가용")
    func seekPreviewEngine_reportsSeekPreview() {
        #expect(PlayerFeatureAvailability.probe(SeekPreviewEngine()).contains(.seekPreview))
        #expect(PlayerFeatureAvailability.probe(BareEngine()).contains(.seekPreview) == false)
    }
}

private actor SeekPreviewEngine: PlayerPlaybackEngine, PlayerSeekPreviewEngine {
    nonisolated static let capabilities: EngineCapabilities = []
    var currentState: PlaybackState { .idle }
    let eventStream: AsyncStream<PlayerEvent> = AsyncStream { $0.finish() }

    func prepare(source: PlaybackSource) async throws {}
    func play() async throws {}
    func pause() async throws {}
    func seek(to time: TimeInterval) async throws {}
    func stop(reason: PlayerStopReason) async throws {}
    func seekPreviewImage(at time: TimeInterval) async -> UIImage? { nil }
}
#endif
```

> 주의: 기존 `BareEngine`이 `private`이므로 extension이 **같은 파일 안**에 있어야 접근 가능하다. 별도 파일로 만들지 말 것.

### 7-3. `Example/Tests/PreferenceManagerTests.swift` 추가

기존 `@Suite` 안에 테스트 추가:

```swift
    @Test("시킹 프리뷰 토글 — 기본 true, 라운드트립")
    func useSeekPreview_defaultsTrueAndRoundTrips() {
        let original = PreferenceManager.useSeekPreview
        defer { PreferenceManager.useSeekPreview = original }

        UserDefaults.standard.removeObject(forKey: "useSeekPreview")
        #expect(PreferenceManager.useSeekPreview == true)

        PreferenceManager.useSeekPreview = false
        #expect(PreferenceManager.useSeekPreview == false)
    }
```

### 7-4. `Tests/VideoPlayerModuleTests/PlayerSkinSmokeTests.swift` 추가

기존 파일의 `#if canImport(UIKit)` 구역 안에 테스트 추가 (파일 구조에 맞춰 기존 @Suite 안 또는 새 @Suite):

```swift
@Suite("시킹 프리뷰 모달 — 모드/게이트")
@MainActor
struct PlayerSeekPreviewSmokeTests {

    @Test("이미지 없으면 라벨-only 컴팩트, 이미지 도착 시 확장")
    func previewView_switchesContentMode() {
        let view = PlayerSeekPreviewView()
        view.resetForSession()
        let compact = view.contentSize

        UIGraphicsBeginImageContext(CGSize(width: 16, height: 9))
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        view.setImage(image)
        let expanded = view.contentSize

        #expect(compact.height < expanded.height)
        #expect(view.hasImage)

        // nil은 무시 — 직전 프레임 유지(깜빡임 방지).
        view.setImage(nil)
        #expect(view.hasImage)
    }

    @Test("비활성화 상태에서는 begin이 무시된다")
    func presenter_ignoresBeginWhenDisabled() {
        let presenter = PlayerSeekPreviewPresenter()
        presenter.isEnabled = false
        presenter.begin()
        #expect(presenter.isActive == false)

        presenter.isEnabled = true
        presenter.begin()
        #expect(presenter.isActive)
        presenter.end()
        #expect(presenter.isActive == false)
    }
}
```

> `PlayerSeekPreviewView`/`PlayerSeekPreviewPresenter`는 internal이므로 이 테스트 파일에 `@testable import VideoPlayerSkin`이 필요하다. 기존 파일이 `import VideoPlayerSkin`(non-testable)이면 `@testable`로 바꾸지 말고 **새 파일** `Tests/VideoPlayerModuleTests/PlayerSeekPreviewSmokeTests.swift`로 분리해 `#if canImport(UIKit)` + `@testable import VideoPlayerSkin`으로 작성한다.

**검증**: §0의 검증 명령 4종 전부 통과.

---

## 8. 엣지 케이스 명세 (구현이 반드시 만족해야 하는 동작)

| # | 상황 | 기대 동작 | 보장 지점 |
|---|---|---|---|
| 1 | 라이브 스트림 / duration 0 | 모달이 아예 뜨지 않음 | skin `interceptForSeekPreview`의 `isSeekEnabled && duration > 0` 가드 + 양 엔진의 `duration > 0` 가드 (이중 방어) |
| 2 | `time == duration` (끝까지 드래그) | 마지막 타일 표시, crash 없음 | `tileIndex` 클램프 `min(raw, tileCount - 1)` |
| 3 | 음수 time | 첫 타일 | `tileIndex` `max(raw, 0)`, Native `min(max(0, time), duration)` |
| 4 | thumb이 화면 좌/우 끝 | 모달이 화면 안에 머묾 | presenter `reposition()`의 centerX 클램프 (margin 8pt) |
| 5 | 화면 폭 < 모달 폭 | 중앙 고정 | `reposition()`의 `maxX < minX → midX` 분기 |
| 6 | 썸네일 단발 실패(추출 실패 프레임) | 직전 프레임 유지, 깜빡임 없음 | `PlayerSeekPreviewView.setImage(nil)`이 무시 |
| 7 | 스프라이트 자체가 없는 콘텐츠 | 시간 라벨만 있는 컴팩트 모달 | `resetForSession()` 시작 + 이미지가 영영 안 옴 |
| 8 | 스프라이트 비동기 다운로드 중 드래그 | 처음 라벨-only → `.thumbnailReady` 후 다음 드래그부터 이미지 | adapter `.thumbnailReady` → `seekPreviewSource = nil` 캐시 무효화 |
| 9 | 드래그 중 잠금(lock) | 모달 즉시 닫힘 | `render(_:)`의 `state.isLocked → end()` |
| 10 | 드래그 중 회전 | touchCancel → `.seekEnded` → 모달 닫힘 | ProgressBarBlock이 touchCancel을 seekEnded에 이미 묶어둠 (기존 동작) |
| 11 | 드래그 중 토글 off | 모달 즉시 닫힘 | `setSeekPreviewEnabled(false) → end()` |
| 12 | 빠른 연속 드래그(요청 적체) | 마지막 요청만 살아남음 | presenter `inflightTask?.cancel()` + Native `cancelAllCGImageGeneration()` |
| 13 | 콘텐츠 교체(이어 재생) | 이전 콘텐츠 썸네일이 안 나옴 | Kollus path 비교 + `prepare`에서 리셋, Native asset identity 비교 |
| 14 | 모달 위 터치 | 아래 컨트롤 동작 방해 없음 | `isUserInteractionEnabled = false` |
| 15 | `seekEnded` 후 늦게 도착한 이미지 | 무시됨(닫힌 모달 부활 금지) | presenter Task의 `isActive` 재확인 |
| 16 | provider 미주입(다른 host) | 라벨-only 모달 | `requestImage`의 `guard let imageProvider` |
| 17 | FairPlay/HLS에서 ImageGenerator 실패 | nil → 라벨-only | Native `result == .succeeded` 가드 |
| 18 | `cropping` 범위 밖(메타와 실제 이미지 불일치) | nil → 라벨-only | `guard let cropped` |

---

## 9. 동시성 규칙 (위반 시 데이터 레이스)

1. `KollusPlayerView`/`AVPlayer` 등 SDK 객체 접근은 **반드시 `await MainActor.run` 또는 @MainActor 프로퍼티 경유** — `KollusPlayerAdapter.seek(to:)`(212행)와 동일한 패턴을 따른다.
2. 스프라이트 디코드/crop은 adapter actor 격리 상태에서 수행 — 별도 `DispatchQueue.global()` 만들지 말 것.
3. `PlayerSeekPreviewPresenter`는 `@MainActor` — UIView 조작 전부 메인에서.
4. presenter의 `requestImage` Task 안에서 결과 적용 전 `Task.isCancelled == false && self.isActive` 둘 다 확인.
5. `withCheckedContinuation`은 **정확히 1회 resume** — Native 구현은 requestedTimes 1건이라 handler 1회 호출이 보장된다. 배열에 2개 이상 넣지 말 것.

---

## 10. 최종 검증 체크리스트

- [ ] `swift test` 통과 (macOS)
- [ ] `tuist generate` 후 Example 빌드 통과 (iPhone 15 시뮬레이터)
- [ ] Example 단위 테스트(xcodebuild test) 통과 — PreferenceManagerTests 포함
- [ ] `PlayerModuleBoundaryTests` 통과 (새 파일 주석 금지어 검사)
- [ ] 시뮬레이터(AVPlayer 엔진, 일반 URL 영상): 가로 모드에서 재생바 드래그 → 썸네일 모달 표시·thumb 추적, 토글 버튼 off → 모달 안 뜸, 앱 재시작 후 off 유지
- [ ] 실기기 QA (Kollus — 시뮬레이터로 닫기 어려움, CLAUDE.md):
  - [ ] 스트리밍 콘텐츠: 모달 표시·추적 (스프라이트 async 다운로드 직후 라벨-only → 이미지 전환 포함)
  - [ ] 다운로드 콘텐츠: 모달 표시·추적
  - [ ] 썸네일 미제공 콘텐츠: 라벨-only 모달
  - [ ] 드래그 중 회전/잠금/토글 off
- [ ] `docs/example-app-rebuild-plan.md` 실기기 QA 체크리스트에 위 항목 반영

---

## 11. 리스크 (구현자가 알아야 할 미확정 사실)

1. **Kollus thumbnail 파일 가용 시점이 최대 미지수.** `KollusContent.thumbnail`은 SDK가 받아둔 스프라이트 파일 경로이고 `isThumbnailSync`가 다운로드 방식을 구분하지만, 스트리밍 재생에서 실제로 언제/어떤 조건에 파일이 생기는지는 **헤더만으로 확정 불가**(콘텐츠 인코딩 설정에 따라 아예 없을 수 있음). 없으면 라벨-only로 동작하므로 기능은 깨지지 않는다. 실기기에서 확인하고 결과를 이 문서에 기록할 것.
2. **그리드 열 수는 SDK 계약이 아님** — 실제 스프라이트 폭/타일 폭으로 산출해 방어하지만, 파일명 메타와 실제 타일 크기가 다르면 crop이 어긋날 수 있다(가능성 낮음, 발생 시 라벨-only 아닌 "엉뚱한 프레임"으로 나타남).
3. **AVAssetImageGenerator는 원격 HLS에서 느리거나 실패**할 수 있다 — throttle + cancel로 메인스레드는 안전하고, 실패는 라벨-only로 강등된다.
4. **스프라이트 메모리** — 160×90×100타일 기준 디코드 후 약 5~7MB. 콘텐츠당 1장 캐시는 수용 범위. 비정상적으로 큰 N이 관측되면 `end()` 후 지연 해제를 후속 작업으로.
