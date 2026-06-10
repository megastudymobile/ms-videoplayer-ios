<!-- source: https://docs.kollus.com/dev-guide/kollus-mobile-app/sdk/ios/guide/event/ -->
<!-- 수집일: 2026-06-10 -->

# 8. 다운로드 이벤트/콜백

다운로드 파이프라인 실행 중에 발생하는 트래픽 상태 변화와 DRM 검증 이벤트를 애플리케이션 레이어로 통지하는 콜백 인터페이스 연동 방법을 설명합니다. iOS SDK는 `KollusStorageDelegate` 프로토콜 하나로 다운로드 진행 상태, DRM 인증 응답, LMS 통계 전송 결과를 통합 처리합니다.

## `KollusStorageDelegate` 프로토콜

스토리지 및 보안 이벤트를 수집하기 위해 반드시 구현해야 하는 단일 통합 델리게이트 인터페이스 규격입니다.

```swift
@objc protocol KollusStorageDelegate: NSObjectProtocol {    // 다운로드 진행 중 상태 변화 (진행률/완료/에러 통지)    func kollusStorage(_ storage: KollusStorage,                       downloadContent content: KollusContent,                       error: Error?)    // DRM 콜백 응답    func kollusStorage(_ storage: KollusStorage,                       request: [AnyHashable: Any],                       json: [AnyHashable: Any]?,                       error: Error?)    // DRM 일괄 갱신 진행률 통지    func kollusStorage(_ storage: KollusStorage,                       cur: Int32, count: Int32,                       error: Error?)    // LMS(학습 통계) 콜백 응답    func kollusStorage(_ storage: KollusStorage,                       lmsData: String,                       resultJson: [AnyHashable: Any])    // 미전송 LMS 일괄 송신 완료    func onSendCompleteStoredLms(_ successCount: Int32,                                 failCount: Int32)}
```

## 다운로드 진행/완료/에러 분기

iOS SDK는 `downloadContent:error:` 메서드 하나로 진행률 변경, 다운로드 최종 완료, 작업 실패 이벤트를 모두 결합하여 호출합니다. 아래와 같은 조건문 분기 패턴을 사용하여 구현합니다.

```swift
func kollusStorage(_ storage: KollusStorage,                   downloadContent content: KollusContent,                   error: Error?) {    if let error = error {        // 에러        let code = (error as NSError).code        return    }    if content.downloaded {        // 다운로드 완료    } else {        // 다운로드 진행 중 (content.downloadProgress 및 content.downloadSize으로 진행률 계산)    }}
```

## 이벤트-콜백 대응표

| 표준 이벤트 | 콜백 위치 |
| --- | --- |
| **다운로드 시작** | `try storage.downloadContent(mck)` 메서드 호출 성공 직후 |
| **진행률 변경** | `downloadContent:error:` (`error == nil`, `downloaded == false`) |
| **다운로드 일시 중단** | 전용 콜백 없음 (취소와 동일) |
| **다운로드 재개** | 전용 콜백 없음 (시작과 동일) |
| **다운로드 완료** | `downloadContent:error:` (`error == nil`, `downloaded == true`) |
| **다운로드 실패** | `downloadContent:error:` (`error != nil`) |
| **라이선스 만료** | `content.DRMExpired = true` (다음 재생 시도 시 노출) |
| **라이선스 갱신 결과** | `kollusStorage(_:cur:count:error:)` |

## LMS(학습 통계) 콜백

진도율 및 학습 관리 시스템(LMS) 연동 기능이 활성화된 콘텐츠는 SDK가 플레이어 재생 로그를 수집하여 자동으로 통계 서버에 전송합니다. 전송 처리가 수행되면 델리게이트의 `lmsData:resultJson:` 메서드를 거쳐 결과가 앱 레이어로 통지됩니다.

네트워크 오류로 인해 통계 데이터 송신이 실패하는 경우, SDK가 누락된 데이터를 디바이스 저장소에 안전하게 임시 보관해 두었다가 다음 네트워크 통신 기회에 일괄 재전송합니다.

```swift
// (선택 사항) 필요한 시점에 로컬 보관 중인 LMS 데이터 일괄 송신 트리거storage.sendStoredLms()// 일괄 재전송 완료 통지func onSendCompleteStoredLms(_ successCount: Int32, failCount: Int32) {    // 성공 또는 실패 카운트}
```
