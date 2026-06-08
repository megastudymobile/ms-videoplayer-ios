# KollusSDK Vendoring 가이드

videoplayer-ios-ms 가 사용하는 KollusSDK 의 버전·출처·갱신 절차를 기록한다.

## 현재 버전

- **KollusSDK: v2.3.36** (release `KollusSDK_iOS_v2.3.36_260611`, device lib build 2024-05-29, md5 `c8e7a52e…`)
- **PallyConFPSSDK: 2.3.0** (동적 framework, 위 release 동봉)

## 위치

| 자산 | 경로 |
|---|---|
| 원본 static lib | `Vendor/KollusSDK/lib/libKollusSDK.a`, `libKollusSDK_debug.a` |
| 원본 헤더 | `Vendor/KollusSDK/include/KollusSDK/*.h` (`Chapter.h` 포함) |
| 패키징 산출물(소비) | `Binaries/KollusSDK.xcframework` |
| 시뮬 stub | `Packaging/Kollus/Stub` |
| 개인정보 매니페스트 | `Sources/VideoPlayerEngineKollus/Resources/PrivacyInfo.xcprivacy` |

## ⚠️ 결함 빌드 주의 (2026-06 사고 기록)

vendoring 됐던 build (`libKollusSDK.a`, 2024-05-18, md5 `3f14…`)는 **챕터 구현이
누락된 결함본**이었다 — `Chapter.h` 헤더가 빠져 있었고 `chapterInfo` 프로퍼티도 없었다.
이 빌드는 콘텐츠에 챕터 아웃라인이 없을 때(catenoid `/outlines/chapters` 가 `error:1`
반환) `BlockStorage.doDownloadChapter` 에서 `std::out_of_range` 로 **크래시**했다.

→ 같은 시기 정식 release(프로덕션 smartlearning 의 `ab87`, 이후 v2.3.36 `c8e7`)는
`Chapter.h` + `chapterInfo` 를 갖춘 완전본이라 정상 동작한다.

**교훈: 새 lib 적용 시 반드시 `Chapter.h` 존재 + 헤더 심볼이 기존 대비 누락 없는지
(reverse-diff) 확인할 것.** 부분/베타 빌드를 그대로 vendoring 하지 말 것.

## 갱신 절차

1. 새 SDK 의 `lib/*.a` 와 `include/KollusSDK/*.h` 를 `Vendor/KollusSDK/` 에 복사.
2. **검증**: `Chapter.h` 존재 확인 + 기존 헤더 대비 제거된 심볼이 없는지 diff.
3. xcframework 재빌드:
   ```bash
   bash scripts/rebuild_kollus_xcframework.sh
   ```
4. 개인정보 매니페스트가 갱신됐으면
   `Sources/VideoPlayerEngineKollus/Resources/PrivacyInfo.xcprivacy` 교체
   (정적 lib 라 xcframework 가 못 실어 타겟 리소스로 동봉 — `Package.swift` 참고).
5. PallyCon 은 동적 framework 라 `PrivacyInfo.xcprivacy` 가 framework 번들 안에 있다
   (`Binaries/PallyConFPSSDK.xcframework/*/PallyConFPSSDK.framework/`). 교체 시 device·
   simulator 두 슬라이스 모두 갱신.
6. Example(`VideoPlayerExample`) 실기기에서 챕터 유/무 콘텐츠 모두 재생 확인.

## 관련 참고

- Kollus 개인정보 매니페스트 안내: `docs/kollus/kollus-privacy-manifest-참고.txt`
