# VideoPlayerModule

`videoplayer-ios-ms`는 공용 플레이어 코어 레포지토리다.

현재 범위:

- `PlayerCore`, `PlayerEngineAdapter`, `AVPlayerAdapter`, `KollusPlayerAdapter`
- `PlayerModuleWiring`
- `KollusPlayerModuleFactory`
- Shell이 소비하는 보조 타입 (`PlayerRenderSurface`, `PlayerStateBinder`, `PlayerLifecycleCoordinator`, `PlayerAudioSessionManager`)

의도적으로 제외한 범위:

- SmartLearning 고등 전용 UI Shell
- 앱 composition / bridge 계층

Kollus SDK 원본 소스는 수정하지 않는다. 공용 모듈은 복사된 vendor 자산과 파생 바이너리 산출물만 소비한다.

## Package 분리

이 패키지는 엔진 선택에 따라 의존성을 나눌 수 있도록 product를 분리한다.

- `VideoPlayerCore`
  - 공통 도메인, 상태, 이벤트, `PlayerEngineAdapter`, `PlayerCore`, `PlayerModuleWiring`
- `VideoPlayerShellSupport`
  - UI shell이 쓰는 보조 타입
- `VideoPlayerEngineNative`
  - `AVPlayerAdapter`
- `VideoPlayerEngineKollus`
  - `KollusPlayerAdapter`
- `VideoPlayerModule`
  - 기존 호환용 umbrella product

권장 사용:

- 네이티브 엔진만 필요하면 `VideoPlayerCore`, `VideoPlayerShellSupport`, `VideoPlayerEngineNative`만 연결
- Kollus가 필요할 때만 `VideoPlayerEngineKollus` 추가
- 기존처럼 한 번에 쓰려면 `VideoPlayerModule` 사용

이 구조는 Kollus 외 다른 외부 SDK가 추가될 때도 같은 패턴으로 확장한다.
예:

- `VideoPlayerEngineVendorX`
- `VideoPlayerEngineVendorY`

## Kollus SDK 운영 규칙

- 이 레포에서 관리하는 source-of-truth는 `Vendor/KollusSDK`다.
- `Vendor/KollusSDK`는 이 레포에서 유지하는 현재 source-of-truth다.
- `Vendor/PallyConFPSSDK.framework`는 이 레포에서 유지하는 현재 source-of-truth다.
- `Binaries/KollusSDK.xcframework`는 파생 산출물이다.
- `Binaries/PallyConFPSSDK.xcframework`는 파생 산출물이다.
- `Packaging/Kollus/Stub/`는 simulator slice를 만드는 로컬 stub 패키지다.
- `Packaging/Kollus/Stub/Sources/KollusSDK/include/KollusSDK`는 `Vendor/KollusSDK/include/KollusSDK`를 가리키는 shared symlink다.
- `Binaries`나 `Vendor` 아래 원본 mirror를 직접 수정하지 않는다.
- SmartLearning 같은 소비자는 `KollusSDKBinary`나 `PallyConFPSSDK`를 직접 import하지 않고 `KollusPlayerModuleFactory` 같은 public API만 사용한다.

재생성 순서:

```bash
./scripts/rebuild_kollus_xcframework.sh
./scripts/rebuild_pallycon_xcframework.sh
./scripts/verify_kollus_packaging.sh
```

새 vendor drop을 가져올 때만:

```bash
./scripts/sync_kollus_vendor.sh /path/to/KollusSDK
./scripts/sync_pallycon_vendor.sh /path/to/PallyConFPSSDK.framework
```

기본 표준 상태로 되돌릴 때는:

```bash
./scripts/rebuild_kollus_xcframework.sh
./scripts/rebuild_pallycon_xcframework.sh
```
