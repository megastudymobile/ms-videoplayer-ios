# Kollus SDK Packaging

Author: 모바일팀_정준영
Date: 2026-05-11

## 원칙

- 현재 SDK source-of-truth:
  - `Vendor/KollusSDK`
- 현재 DRM framework source-of-truth:
  - `Vendor/PallyConFPSSDK.framework`
- 이 경로들은 이 레포 안에서 유지한다.
- `VideoPlayerEngineKollus`를 선택한 소비자만 이 문서의 흐름이 직접 관련된다.
- `Packaging/Kollus/Stub/`는 simulator arm64 slice를 만드는 로컬 stub 패키지다.
- `Packaging/Kollus/Stub/Sources/KollusSDK/include/KollusSDK`는 `Vendor/KollusSDK/include/KollusSDK`를 공유하는 symlink다.
- `Binaries/KollusSDK.xcframework`는 복사본과 simulator stub에서 만든 파생 산출물이다.
- `Binaries/PallyConFPSSDK.xcframework`는 vendor framework에서 만든 파생 산출물이다.
- `Vendor/KollusSDK`, `Vendor/PallyConFPSSDK.framework`, `Binaries/KollusSDK.xcframework`, `Binaries/PallyConFPSSDK.xcframework`는 직접 수정하지 않는다.
- SmartLearning 같은 소비자는 vendor SDK를 직접 import하지 않고 `KollusPlayerModuleFactory`를 통해 모듈을 만든다.
- 변경이 필요하면 항상 `scripts/sync_kollus_vendor.sh`, `scripts/sync_pallycon_vendor.sh`, `scripts/rebuild_kollus_xcframework.sh`, `scripts/rebuild_pallycon_xcframework.sh`를 통해 다시 만든다.

## 디렉토리 역할

- `Vendor/KollusSDK`
  - 원본 SDK 복사본
  - `include/`, `lib/` 구조 유지
  - 직접 수정 금지
- `Vendor/PallyConFPSSDK.framework`
  - 원본 DRM framework 복사본
  - framework 구조 그대로 유지
  - 직접 수정 금지
- `.build/kollus-xcframework`
  - 임시 포장 작업 디렉토리
  - `module.modulemap`과 import 보조 patch는 여기서만 적용
- `Packaging/Kollus/Stub`
  - simulator용 `libKollusSDK.a`를 빌드하는 로컬 stub 패키지
  - `scripts/generate_kollus_k2_stub.py`의 출력 대상
  - 헤더는 `Vendor/KollusSDK/include/KollusSDK`를 symlink로 공유
- `Binaries/KollusSDK.xcframework`
  - 재생성된 canonical 산출물
  - SwiftPM binary target이 직접 소비하는 최종 산출물
- `Binaries/PallyConFPSSDK.xcframework`
  - 재생성된 canonical 산출물
  - SwiftPM binary target이 직접 소비하는 최종 산출물

## 실행

XCFramework 재생성:

```bash
./scripts/rebuild_kollus_xcframework.sh
./scripts/rebuild_pallycon_xcframework.sh
```

검증:

```bash
./scripts/verify_kollus_packaging.sh
```

권장 운영:

- canonical `xcframework` 하나만 유지
- 필요 시 `./scripts/rebuild_kollus_xcframework.sh`로 다시 생성

환경 변수로 입력 경로를 덮어쓸 수 있다.

```bash
SOURCE_SDK=/path/to/KollusSDK \
STUB_PACKAGE=/path/to/Packaging/Kollus/Stub \
./scripts/rebuild_kollus_xcframework.sh
```

새 SDK drop을 import할 때만:

```bash
./scripts/sync_kollus_vendor.sh /path/to/KollusSDK
./scripts/sync_pallycon_vendor.sh /path/to/PallyConFPSSDK.framework
```

## 왜 임시 patch가 필요한가

- `Vendor/KollusSDK`는 `include + static library` 구조이지 `xcframework`가 아니다.
- SwiftPM binary target import를 위해 `module.modulemap`이 필요하다.
- 일부 delegate header는 포워드 선언이 부족해, 포장 시점에만 보정이 필요하다.
- 이 보정은 원본이나 vendor 복사본을 수정하지 않고 임시 헤더 디렉토리에서만 수행한다.
- PallyCon도 동일하게 vendor framework를 직접 링크하지 않고 canonical `xcframework`로 다시 묶는다.
- 그래서 중간 artifact 캐시를 두지 않고, canonical `xcframework`만 다시 만든다.

## 금지 사항

- `Binaries/KollusSDK.xcframework/.../Headers` 직접 수정
- `Binaries/PallyConFPSSDK.xcframework/.../Headers` 직접 수정
- `Vendor/KollusSDK` 직접 수정
- `Vendor/PallyConFPSSDK.framework` 직접 수정
- source SDK 업데이트 없이 `Binaries`만 hand patch
