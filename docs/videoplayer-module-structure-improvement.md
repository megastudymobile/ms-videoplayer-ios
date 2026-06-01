# VideoPlayerModule 폴더 구조 개선안

- 작성자: 모바일팀_정준영
- 작성일: 2026-06-01
- 대상: `Sources/VideoPlayerModule/`, `Package.swift`
- 관점: 유지보수성 (파일 누락 방지 · 머지 충돌 감소 · 구조 직관성)

---

## 1. 현재 구조

물리 폴더 `Sources/VideoPlayerModule/` 1개 안에 SPM 타겟 **4개**가 공존한다.
Package.swift가 `sources:` 명시 배열로 각 파일을 타겟에 수동 분배한다.

```
Sources/VideoPlayerModule/
├── Core/
│   ├── Domain/          (14 파일)   → VideoPlayerCore
│   ├── Internal/
│   │   └── PlayerCore.swift (426줄) → VideoPlayerCore
│   └── UseCase/         (3 파일)    → VideoPlayerCore
├── Engine/
│   ├── PlayerEngineAdapter.swift    → VideoPlayerCore        ⚠ 폴더-타겟 불일치
│   ├── Native/
│   │   └── AVPlayerAdapter.swift    → VideoPlayerEngineNative
│   └── Kollus/          (15 파일)   → VideoPlayerEngineKollus
└── ShellSupport/        (8 파일)    → VideoPlayerShellSupport
```

| 타겟 | 소스 위치 |
|------|-----------|
| VideoPlayerCore | `Core/*` + `Engine/PlayerEngineAdapter.swift` |
| VideoPlayerShellSupport | `ShellSupport/*` |
| VideoPlayerEngineNative | `Engine/Native/*` |
| VideoPlayerEngineKollus | `Engine/Kollus/*` |

`Engine/` 디렉토리 하나가 3개 타겟에 쪼개진다.

> 참고: `VideoPlayerSkin/`, `VideoPlayerModuleExports/`는 이미 폴더=타겟 1:1 이며 정상. 변경 대상 아님.

---

## 2. 문제점

### P1. 물리 폴더 ≠ 타겟 경계 (높음)

- **파일 누락 위험**: 새 `.swift` 추가 시 Package.swift `sources:` 배열에 수동 등록 필수.
  누락하면 SPM이 조용히 무시 → 컴파일에서 빠져도 빌드는 통과 → 발견이 늦다.
- **머지 충돌 상시화**: 파일 추가/삭제마다 Package.swift diff 발생. 브랜치 간 충돌 지점 고정.
- **구조 추론 불가**: 폴더만 보고 타겟 소속을 알 수 없다.
  `Engine/PlayerEngineAdapter.swift`는 `Engine/` 안에 있지만 실제로 `VideoPlayerCore` 소속.

### P2. 거대 파일 (중)

- `Engine/Kollus/KollusPlayerAdapter.swift` **888줄** — 단일 파일 과대.
- `Core/Internal/PlayerCore.swift` **426줄** — 상태머신/커맨드 처리 혼재 가능성.

### P3. 불필요한 폴더 깊이 (낮)

- `Engine/Native/AVPlayerAdapter.swift` — 파일 1개를 위한 2단 중첩.

### P4. Exports 우산 타겟 미사용 (중)

`VideoPlayerModule`(= `Sources/VideoPlayerModuleExports/`) 타겟은 4개 타겟을 `@_exported import`로
재노출하는 우산 타겟이다. 그러나 host 코드(`smartlearning-ios-ms`)는 이를 **0회** import 한다.
host는 개별 타겟(Core/ShellSupport/EngineNative/EngineKollus/Skin)을 직접 import.

→ 우산 타겟이 존재 의미를 못 가진다. 둘 중 하나로 통일 필요.

---

## 2.5 host 코드 호출 지점

host(`smartlearning-ios-ms`)의 import 분포. 전부 `SmartPlayer/Feature/PlayerModule/` 안에 집중.

| 타겟 | import 수 | 주 호출 파일 | 진입 레이어 |
|------|----------|-------------|------------|
| VideoPlayerSkin | 7 | `LecturePlayer{Coordinator,ContainerBuilder,ShellBuilder,SkinTheme}`, `LectureExtraControlFactory`, `LecturePlayerShell{Reactor,ViewController}` | Composition + UI/Shell/Lecture |
| VideoPlayerCore | 6 | `LecturePlayer{Coordinator,LaunchCoordinator,Inputs}`, `PlayerModuleFactory`, `LecturePlayerShell{Reactor,ViewController}` | Composition + UI/Shell/Lecture |
| VideoPlayerShellSupport | 5 | `LecturePlayer{ContainerBuilder,ShellBuilder}`, `PlayerModuleFactory`, `LecturePlayerShell{Reactor,ViewController}` | Composition + UI/Shell/Lecture |
| VideoPlayerEngineKollus | 2 | `KollusEnvironmentProvider`, `PlayerModuleFactory` | Composition |
| VideoPlayerEngineNative | 1 | `PlayerModuleFactory` | Composition |
| VideoPlayerModule (Exports) | **0** | — | 미사용 (P4) |

관찰:
- **진입점 2곳뿐**: `Composition/`(조립·DI·팩토리), `UI/Shell/Lecture/`(reactor·VC).
- **`PlayerModuleFactory`가 엔진 조립 허브**: EngineNative·EngineKollus를 동시 import하는 유일 파일.
  엔진 선택/조립 책임이 여기 집중 → 엔진 추가/교체 시 단일 변경점.
- **구조 개선(§3.1) 영향 = 0**: import는 타겟 이름 기준이고 재배치는 폴더만 옮긴다.
  타겟 이름 불변 → 위 host 파일 전부 무수정.

---

## 3. 개선안

### 3.1 폴더 = 타겟 1:1 재배치 (P1 해결, 핵심)

각 타겟을 자기 디렉토리로 분리하고 `sources:` 배열을 제거 → SPM 자동 디렉토리 수집으로 전환.

#### 목표 구조

```
Sources/
├── VideoPlayerCore/
│   ├── Domain/          (14 파일)
│   ├── Internal/
│   │   └── PlayerCore.swift
│   ├── UseCase/         (3 파일)
│   └── Contract/
│       └── PlayerEngineAdapter.swift   ← Engine/ 에서 이동 (Core 소속 명확화)
├── VideoPlayerShellSupport/            ← 기존 ShellSupport/* 그대로
├── VideoPlayerEngineNative/
│   └── AVPlayerAdapter.swift           ← Engine/Native/ 평탄화 (P3 해결)
└── VideoPlayerEngineKollus/
    ├── (Kollus 루트 12 파일)
    └── Downloads/       (3 파일)
```

#### Package.swift 변경 (before → after)

before — 파일을 일일이 나열:

```swift
.target(
    name: "VideoPlayerCore",
    path: "Sources/VideoPlayerModule",
    sources: [
        "Core/Domain/Bookmark.swift",
        "Core/Domain/NextEpisodeInfo.swift",
        // ... 18개 파일 수동 나열 ...
        "Engine/PlayerEngineAdapter.swift"
    ]
),
```

after — 디렉토리만 지정, 파일 자동 수집:

```swift
.target(
    name: "VideoPlayerCore",
    path: "Sources/VideoPlayerCore"
),
.target(
    name: "VideoPlayerShellSupport",
    dependencies: ["VideoPlayerCore"],
    path: "Sources/VideoPlayerShellSupport",
    linkerSettings: [
        .linkedFramework("AVFoundation", .when(platforms: [.iOS])),
        .linkedFramework("UIKit", .when(platforms: [.iOS]))
    ]
),
.target(
    name: "VideoPlayerEngineNative",
    dependencies: ["VideoPlayerShellSupport"],
    path: "Sources/VideoPlayerEngineNative",
    linkerSettings: [
        .linkedFramework("AVFoundation", .when(platforms: [.iOS])),
        .linkedFramework("UIKit", .when(platforms: [.iOS]))
    ]
),
.target(
    name: "VideoPlayerEngineKollus",
    dependencies: [
        "VideoPlayerShellSupport",
        "VideoPlayerKollusBinary",
        "VideoPlayerPallyConBinary"
    ],
    path: "Sources/VideoPlayerEngineKollus",
    linkerSettings: [ /* 기존 linker 설정 그대로 유지 */ ]
),
```

`sources:` 배열 전부 삭제. 이후 파일 추가 시 Package.swift 무수정.

#### 이행 절차 (git 이력 보존)

```bash
cd /Users/jimmy/Documents/GitLab/videoplayer-ios-ms/Sources

# 1. 타겟별 디렉토리로 이동
git mv VideoPlayerModule/Core              VideoPlayerCore
git mv VideoPlayerModule/ShellSupport      VideoPlayerShellSupport
git mv VideoPlayerModule/Engine/Native/AVPlayerAdapter.swift \
       VideoPlayerEngineNative/AVPlayerAdapter.swift
git mv VideoPlayerModule/Engine/Kollus     VideoPlayerEngineKollus

# 2. Core 소속 어댑터 계약을 Core 하위로
mkdir -p VideoPlayerCore/Contract
git mv VideoPlayerModule/Engine/PlayerEngineAdapter.swift \
       VideoPlayerCore/Contract/PlayerEngineAdapter.swift

# 3. 빈 VideoPlayerModule 폴더 제거
rmdir VideoPlayerModule/Engine/Native VideoPlayerModule/Engine VideoPlayerModule

# 4. Package.swift 위 after 형태로 수정 (sources: 삭제, path: 갱신)
# 5. 빌드 검증
cd .. && swift build
```

검증 포인트:
- `swift build` 성공 (타겟 4개 + Skin + Exports + 테스트).
- 파일 개수 동일(.swift 45개) — 누락 0건 확인.
- import 경로 무변경 (타겟 이름 동일 → host 코드 영향 없음).

리스크: **낮음**. 타겟 이름·의존성·public API 불변. 물리 위치만 변경.

### 3.2 KollusPlayerAdapter 888줄 분할 (P2)

`KollusObserver`, `KollusDelegateBridge`는 이미 분리됨. 어댑터에서 추가로 책임 추출:

| 추출 후보 | 책임 |
|-----------|------|
| `KollusPlaybackController` | play/pause/seek/rate 등 재생 제어 |
| `KollusPlayerErrorMapper` | KollusEngineSignal → PlayerError 변환 |
| `KollusPlayerAdapter` (잔여) | 생명주기 · 조립 · 위 컴포넌트 위임 |

3.1 완료 후 별도 작업으로 진행. 정확한 분할선은 파일 내부 의존 그래프 확인 후 확정.

### 3.3 PlayerCore 426줄 검토 (P2, 선택)

상태 전이 로직과 커맨드 디스패치가 한 파일에 있으면 분리 검토.
도메인 핵심이라 변경 영향 크므로 테스트 보강 선행 후 판단.

### 3.4 Exports 우산 타겟 정리 (P4)

host가 개별 타겟을 직접 import하므로 우산 타겟은 현재 무의미. 둘 중 택1:

- **(A) 제거** — `VideoPlayerModule` 타겟 + product + `Sources/VideoPlayerModuleExports/` 삭제.
  host import 무영향(이미 0회). 가장 단순. **권장.**
- **(B) 통일** — host가 개별 import 대신 `import VideoPlayerModule` 하나로 수렴.
  host 측 import 7파일 수정 필요. 엔진 선택권(Native만/Kollus만 import)을 잃으므로
  엔진 분리 컴파일 이점 감소. 비권장.

§2.5의 `PlayerModuleFactory`가 EngineNative·EngineKollus를 명시적으로 골라 import하는
구조이므로 (B)는 엔진 격리를 해친다. (A) 권장.

---

## 4. 우선순위 · 적용 순서

| 순위 | 작업 | 난이도 | 효과 |
|------|------|--------|------|
| 1 | 3.1 폴더=타겟 1:1 재배치 | 낮음 | 누락·충돌 위험 제거, 구조 직관화 |
| 2 | 3.4 Exports 우산 타겟 제거 (A안) | 낮음 | 죽은 타겟 제거 |
| 3 | 3.2 KollusPlayerAdapter 분할 | 중 | 가독성·테스트성 |
| 4 | 3.3 PlayerCore 검토 | 중 | 선택 |

1·2번은 독립적·저위험이라 즉시 적용 권장. 3·4번은 후속 분리 작업.

---

## 5. 유지할 강점 (변경 금지)

- 레이어 단방향 의존: Core → ShellSupport → Engine → Skin.
- `VideoPlayerSkin` 무의존(Rx/ReactorKit/SnapKit 없음) → 재사용성.
- `VideoPlayerModuleExports` 우산 타겟 → host import 단순화.
- Domain 타입당 1파일 분리.
