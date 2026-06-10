<!-- source: https://docs.kollus.com/dev-guide/kollus-mobile-app/sdk/ios/guide/error-code/ -->
<!-- 수집일: 2026-06-10 -->

# 9. 다운로드 에러 코드

iOS SDK는 발생한 예외 상황을 `NSError` 인스턴스의 `code` 속성 및 `localizedDescription` 메시지로 조합하여 애플리케이션 레이어에 통지합니다.

## SDK 에러 코드

`(error as NSError).code`를 기준으로 분류되는 주요 에러 코드와 트리거 시점입니다.

| 에러 구분 | 설명 | 트리거 |
| --- | --- | --- |
| **인증 오류** | SDK 키 만료 또는 잘못된 키 | `start()` 또는 `startWithCheck()` 시점 |
| **디바이스 미지원** | SDK 또는 DRM을 지원하지 않는 디바이스 | `start()` 또는 DRM 호환성 검증 실패 시 |
| **저장소 용량 부족** | 디스크 공간 부족 | 메타 정보 로드(`load`) 및 파일 다운로드(`download`) 시작 시점 |
| **파일 쓰기 실패** | 파일 쓰기 오류 | 다운로드 진행 중 디스크 입출력 에러 발생 시 |
| **다운로드 중복** | 중복 다운로드 요청 | 동일한 콘텐츠에 대해 `downloadContent(mck)` 호출 시 |
| **다운로드 이미 완료** | 이미 다운로드 완료된 콘텐츠 | 이미 다운로드 완료된 콘텐츠에 대해 `downloadContent(mck)` 호출 시 |
| **콘텐츠 없음** | 대상 파일 없음 | 콘텐츠 제거(`removeContent`) 또는 유효성 검사(`checkContentURL`) 시점 |
| **만료일 초과** | DRM 만료일 초과 | 오프라인 재생 시도 시 |
| **재생 시간 초과** | DRM 잔여 재생 시간 초과 (잔여 시간 0) | 오프라인 재생 시도 시 |
| **재생 횟수 초과** | DRM 잔여 재생 횟수 초과 (잔여 횟수 0) | 오프라인 재생 시도 시 |
| **DRM 강제 삭제** | DRM 콜백 `kind2` 또는 `kind3` 응답으로 콘텐츠 강제 삭제 | 델리게이트 콜백(`request:json:error:`) 파라미터 내 응답 감지 |

> **INFO**
>
> 개발 가이드라인
>
> SDK가 내보내는 정수형 코드값(`code`)의 세부 유형은 Android SDK의 `ErrorCodes` 구조와 매칭됩니다. 다만 iOS 개발 환경에서는 `NSError.code` 분기 처리로 예외 상황을 파악하고, 구체적인 텍스트 노출은 `localizedDescription` 속성을 활용해 화면에 매핑하는 패턴을 권장합니다.

### 에러 처리 예시

```swift
do {    try storage.start()} catch {    let nsError = error as NSError    UIApplication.presentErrorViewController(        title: "Error Code: \(nsError.code)",        errorDescription: nil,        errorReason: error.localizedDescription    )}
```

## SDK 외부 에러

SDK 내부 로직 외에 모바일 운영체제 정책이나 네트워크 오류로 인해 발생할 수 있는 에러 상황 대응 패턴입니다.

- 디스크 공간 부족: 다운로드 실행 전에 DiskStatus.freeDiskSpaceInBytes을 호출하여 가용 용량을 확인하는 것을 권장합니다.
- 네트워크 연결 실패: SDK가 자동으로 재시도를 수행합니다. 자동 재시도 임계치는 storage.setNetworkTimeOut(timeOut:retry:)로 조정할 수 있으며, storage.setNetworkTimeOut(timeOut: 30, retry: 3) 설정을 권장합니다.
- 백그라운드 강제 종료: 앱이 백그라운드로 전환될 때 운영체제에 의해 전송이 취소되는 현상을 방어하기 위해 setBackgroundDownload(true) 설정을 활성화하고, Info.plist 내부의 UIBackgroundModes 스펙을 함께 검토하는 것을 권장합니다.

## 에러 상황별 추천 사용자 메시지

| 에러 구분 | 사용자 메시지 예시 |
| --- | --- |
| **인증 오류** | "앱 인증에 문제가 발생했습니다. 앱을 최신 버전으로 업데이트해 주세요." |
| **저장소 부족** | "기기의 저장 공간이 부족합니다. 시청을 완료한 다운로드 파일을 삭제하거나 저장 공간을 확보해 주세요." |
| **파일 쓰기 실패** | "파일 저장에 실패했습니다. 잠시 후 다시 시도해 주세요." |
| **만료 에러** | "콘텐츠 시청 기간이 만료되었습니다. 네트워크를 연결하여 라이선스를 갱신해 주세요." |
| **디바이스 미지원** | "이 기기에서는 콘텐츠를 다운로드하거나 재생할 수 없습니다." |
