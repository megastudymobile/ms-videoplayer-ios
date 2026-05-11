# Kollus Stub — K2 simulator slice source

Author: 모바일개발팀_정준영
Date: 2026-04-20
Related: `docs/kollus-sdk-symbol-audit.md`, `player-module-technical-spec.md §ADR-06`, `player-module-14`

---

## 1. 목적

`libKollusSDK.a`(arm64 device slice만 제공됨)에 대응하는 **simulator arm64 slice**를 자체 제작하여 `KollusSDK.xcframework`로 결합한다. 스펙 ADR-06 EUREKA에서 K2가 영구 전략으로 확정되었다.

- Layer A: public header 14개, @interface 선언 11개 → `Vendor/KollusSDK/include/KollusSDK`를 공유하고 `.m` 생성 (자동)
- Layer B: NSError out-param + nil/NO/0 규칙으로 body 구현 (자동)
- Layer C: internal 심볼은 stub 대상 아님 (앱 직접 참조 없음 가정)

---

## 2. 현재 디렉터리 구성

```
Packaging/Kollus/Stub/
├── README.md                              이 문서
└── Sources/
    └── KollusSDK/
        ├── include/KollusSDK -> ../../../../Vendor/KollusSDK/include/KollusSDK
        │   ├── KPSection.h
        │   ├── KollusBookmark.h
        │   ├── KollusChat.h
        │   ├── KollusContent.h
        │   ├── KollusPlayerBookmarkDelegate.h
        │   ├── KollusPlayerDRMDelegate.h
        │   ├── KollusPlayerDelegate.h
        │   ├── KollusPlayerLMSDelegate.h
        │   ├── KollusPlayerView.h
        │   ├── KollusSDK.h
        │   ├── KollusStorage.h
        │   ├── KollusStorageDelegate.h
        │   ├── LogUtil.h
        │   └── SubTitleInfo.h
        ├── KPSection.m                     자동 생성
        ├── KollusBookmark.m                자동 생성
        ├── KollusChat.m                    자동 생성
        ├── KollusContent.m                 자동 생성
        ├── KollusPlayerView.m              자동 생성
        ├── KollusStorage.m                 자동 생성
        ├── LogUtil.m                       자동 생성
        └── SubTitleInfo.m                  자동 생성
```

Delegate protocol 5개(`KollusPlayerDelegate`, `KollusPlayerDRMDelegate`, `KollusPlayerLMSDelegate`, `KollusPlayerBookmarkDelegate`, `KollusStorageDelegate`)는 `@protocol` 선언만 있어 `.m` 불필요. `KollusSDK.h`는 umbrella 헤더로 `@interface` 없음.

---

## 3. 자동 생성 스크립트

```bash
python3 scripts/generate_kollus_k2_stub.py \
    --headers Vendor/KollusSDK/include/KollusSDK \
    --out Packaging/Kollus/Stub/Sources/KollusSDK
```

스크립트는 각 `.h`를 파싱해 `@interface ClassName ... @end` 블록에서 method 선언을 추출하고, `.m`을 다음 규칙으로 생성한다 (ADR-06):

| 반환 타입 | body |
|---|---|
| `void` | `os_log_debug(...)` no-op |
| `BOOL` + NSError out-param | NSError 세팅 + `return NO` |
| `BOOL` | `return NO` |
| `pointer`(`NSString*`, `id` 등) + NSError out-param | NSError 세팅 + `return nil` |
| `pointer` | `return nil` |
| `NSInteger` / `int` / `long` / `float` / `double` | `return 0` |
| struct/enum (best-effort) | `return (T){0}` |

**NSException 사용 금지** — Swift catch 불가로 런타임 크래시 유발 (ADR-06 Swift 경계 동작).

---

## 4. 다음 단계 (수동)

### 4.1 Xcode 프로젝트 생성

SPM만으로 `.a` 산출물을 얻기 어려우므로 Xcode 프로젝트를 쓴다. 두 가지 방법:

**방법 A — Xcode GUI**:
1. File → New → Project → iOS → Framework & Library → Static Library
2. Product Name: `KollusSDK_stub`
3. Language: Objective-C
4. 생성 후 `Sources/KollusSDK/` 하위의 모든 `.m`과 `include/KollusSDK/*.h`를 프로젝트에 add (Create folder references)
5. Build Settings:
   - `Header Search Paths` += `$(SRCROOT)/include/KollusSDK`
   - `Public Headers Folder Path` = `include/KollusSDK`
   - `Skip Install` = `NO`
   - `Strip Style` = `Non-Global Symbols`
6. Scheme 편집 → Archive → Build Configuration: Release
7. Simulator arm64 destination으로 `xcodebuild build -sdk iphonesimulator -arch arm64`

**방법 B — xcodegen (팀 합의 시)**:
```yaml
# Packaging/Kollus/Stub/project.yml
name: KollusSDK_stub
targets:
  KollusSDK_stub:
    type: library.static
    platform: iOS
    sources:
      - Sources/KollusSDK
    settings:
      HEADER_SEARCH_PATHS: $(SRCROOT)/Sources/KollusSDK/include/KollusSDK
      PUBLIC_HEADERS_FOLDER_PATH: include/KollusSDK
```
`xcodegen generate` → `xcodebuild build -sdk iphonesimulator -arch arm64`

### 4.2 산출물 확인

```bash
# 결과물 경로 (Xcode DerivedData)
find ~/Library/Developer/Xcode/DerivedData/KollusSDK_stub-* -name "libKollusSDK_stub.a"
lipo -info libKollusSDK_stub.a
# 기대: "Non-fat file: ... is architecture: arm64" (simulator slice)
```

### 4.3 XCFramework 결합

```bash
DEVICE_LIB=Vendor/KollusSDK/lib/libKollusSDK.a
STUB_LIB=<위 4.2에서 확인한 libKollusSDK_stub.a 경로>
HEADERS=Packaging/Kollus/Stub/Sources/KollusSDK/include/KollusSDK

xcodebuild -create-xcframework \
    -library "$DEVICE_LIB" -headers "$HEADERS" \
    -library "$STUB_LIB"   -headers "$HEADERS" \
    -output Binaries/KollusSDK.xcframework
```

`Info.plist`의 `AvailableLibraries`에 `ios-arm64`와 `ios-arm64-simulator` 둘 다 있어야 통과.

### 4.4 Package.swift 통합

```swift
// videoplayer-ios-ms/Package.swift
targets: [
    .target(
        name: "VideoPlayerEngineKollus",
        dependencies: ["KollusSDKBinary"],
        ...
    ),
    .binaryTarget(
        name: "KollusSDKBinary",
        path: "Binaries/KollusSDK.xcframework"
    ),
]
```

### 4.5 검증

- `swift build` 시뮬레이터 녹색
- `xcodebuild -scheme videoplayer-ios-ms-Package -destination 'generic/platform=iOS Simulator' build` → simulator slice 링크 통과
- 기존 앱 테스트 타깃(`SmartPlayerTests` 내 `LegacyPlayerEntryAdapterTests`) 자동화 실행 가능

---

## 5. 수동 검증 필요 포인트

자동 생성은 best-effort 1차 pass다. 실제 빌드 전에 다음 항목을 리뷰한다:

1. **Struct 반환 타입 best-effort `(T){0}` 매핑** — `CGRect`, `CGSize` 등은 OK. 커스텀 struct는 0 초기화가 맞는지 재확인.
2. **`instancetype` 반환**인 `init*` 메서드 — nil 반환 금지. 최소한 `self = [super initWithFrame:CGRectZero]` 후 입력값(`contentURL`, `mediaContentKey`)만 보존해 호출자가 nil 체크를 강제당하지 않도록 유지.
3. **Property getter/setter**는 자동 synthesize로 해결되지만, readonly property의 backing ivar가 초기화되지 않으면 nil/0 반환됨 — 현재 앱 경로는 ObjC nil-safe read 위주라 즉시 크래시 블로커는 아니지만, collection/identifier를 nonnull 전제로 쓰는 새 호출이 생기면 수동 초기화 필요.
4. **Category (`@interface Class (Name)`)**는 파서가 스킵한다. 만약 실제 헤더에 category가 있고 그 메서드가 앱에서 쓰인다면 수동 추가 필요. 현재 14개 헤더에는 category 없음 확인됨.

---

## 6. 재배포 루틴 (Phase 3 이후)

Kollus SDK 벤더가 새 버전을 배포하면 (스펙 R-06):

```bash
# 1. 새 libKollusSDK.a로 교체
cp <new_libKollusSDK.a> Vendor/KollusSDK/lib/
cp <new_headers>/* Vendor/KollusSDK/include/KollusSDK/

# 2. stub .m 재생성
rm Packaging/Kollus/Stub/Sources/KollusSDK/*.m
python3 scripts/generate_kollus_k2_stub.py \
    --headers Vendor/KollusSDK/include/KollusSDK \
    --out Packaging/Kollus/Stub/Sources/KollusSDK

# 3. 수동 리뷰 (§5)

# 4. 4.1~4.4 단계 반복 (Xcode 빌드 + xcframework 결합 + Package.swift)
```

---

## 7. 이어질 작업 (player-module-14 서브태스크)

- `player-module-14-2`: **§4 수동 단계 실행 + xcframework 생성** — 별도 세션
- `player-module-14-3`: **KollusPlayerAdapter(actor) 구현** — §4 완료 + OQ-10~13 POC 결과 반영
