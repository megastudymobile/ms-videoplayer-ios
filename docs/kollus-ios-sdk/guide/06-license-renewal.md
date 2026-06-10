<!-- source: https://docs.kollus.com/dev-guide/kollus-mobile-app/sdk/ios/guide/license-renewal/ -->
<!-- 수집일: 2026-06-10 -->

# 6. DRM 라이선스 갱신

오프라인 저장소에 보관된 다운로드 콘텐츠의 DRM 만료 여부를 판별하고, 만료된 권한을 실시간 또는 일괄로 안전하게 갱신하는 방법을 설명합니다.

이 문서의 모든 예제 코드는 공식 샘플 앱인 `kollus_player_ios`를 바탕으로 작성되었습니다.

## 라이선스 만료 확인

콘텐츠 객체의 DRM 만료 상태를 사전에 체크하여 갱신 프로세스 진입 여부를 판단하는 기준 코드입니다.

```swift
func isExpired(_ c: KollusContent) -> Bool {    return c.DRMExpired        || (c.drmTotalExpirePlayTime > 0 && c.DRMExpirePlayTime <= 0)        || (c.drmExpireCountMax > 0 && c.drmExpireCount <= 0)}
```

## 라이선스 일괄 갱신 API

`updateDownloadDRMInfo` 메서드를 사용하면 스토리지에 등록된 콘텐츠들의 DRM 라이선스를 한 번에 일괄 갱신할 수 있습니다.

```swift
func renewDRMContents(isAll: Bool) {    storage.updateDownloadDRMInfo(isAll)}
```

#### 파라미터 명세

| 파라미터 | 설명 |
| --- | --- |
| **`isAll = true`** | SDK에 등록된 모든 다운로드 콘텐츠의 라이선스 갱신을 시도합니다. |
| **`isAll = false`** | 만료되었거나 곧 만료될 예정인 콘텐츠만 선택하여 갱신을 시도합니다. |

메서드가 호출되면 주입된 델리게이트 콜백 루프(`kollusStorage(_:cur:count:error:)`)를 통해 현재 몇 번째 항목이 처리 중인지 전체 진행률 상태가 애플리케이션 레이어로 통지됩니다.

## 백그라운드 갱신 제약 사항

iOS는 백그라운드 실행 시간에 엄격한 제약(Background Execution Limits)이 있어, 앱이 화면에서 벗어난 상태에서 라이선스 갱신을 완벽히 수행하도록 보장할 수 없습니다. 안정적인 연동을 위해 아래와 같은 패턴을 권장합니다.

- 포그라운드 전환 시점 활용: 사용자가 앱을 다시 실행하거나 활성화하는 타이밍인 applicationDidBecomeActive 진입 시점에 맞추어 호출합니다.
- 재생 직전 타이밍 활용: 사용자가 다운로드된 콘텐츠를 재생 직전에 동기(Sync) 방식으로 API를 호출하는 구조가 가장 확실하고 안정적입니다.

> **INFO**
>
> 연동 주의사항
>
> `BGTaskScheduler` 컴포넌트를 활용하여 주기적 백그라운드 작업으로 등록하는 것도 기술적으로는 가능하나, iOS 운영체제 특성상 정확한 실행 시점이 보장되지 않습니다. 또한 `storage.setBackgroundDownload(true)` 설정은 순수 파일 다운로드 태스크를 백그라운드에서 지속시키는 옵션일 뿐이며, 라이선스 교환 및 갱신 프로세스까지 백그라운드 실행을 보장하는 것은 아니라는 점에 유의해야 합니다.

## 네트워크 복구 후 자동 갱신

공식 샘플 앱은 네트워크 복구 시점의 라이선스 자동 갱신 로직을 별도로 내장하고 있지 않습니다. 상용 서비스 개발 시에는 아래와 같은 흐름으로 예외 처리 코드를 구현하는 것을 권장합니다.

1. Apple 시스템 프레임워크인 NWPathMonitor를 활용하여 디바이스의 네트워크 복구 타이밍을 실시간으로 감지합니다.
2. 사용자가 오프라인 보관함에서 재생 버튼을 누르는 시점에 대상 콘텐츠의 만료 체크 함수를 실행합니다.
3. 만료가 확인되면 즉시 updateDownloadDRMInfo(false) 메서드를 동기 호출하여 라이선스 갱신을 완료한 뒤 재생합니다.

## 라이선스 갱신 실패 예외 처리

서버 장애나 네트워크 순단으로 인해 라이선스 갱신이 최종 실패하는 경우, SDK는 주입된 델리게이트 프로토콜의 아래 두 메서드 중 하나를 통해 예외를 통지합니다.

```swift
func kollusStorage(_ storage: KollusStorage,                   request: [AnyHashable: Any],                   json: [AnyHashable: Any]?,                   error: Error?) {    if let error = error {        // 갱신 실패 또는 강제 만료    }}func kollusStorage(_ storage: KollusStorage,                   cur: Int32, count: Int32,                   error: Error?) {    // 일괄 갱신 진행 중 에러(error) 발생 시 해당 항목 실패}
```

> **TIP**
>
> 갱신 실패 UX 권장 사항
>
> 라이선스 갱신 실패 신호가 감지되면 화면에 "라이선스 갱신에 실패했습니다. 네트워크 상태를 확인하거나 콘텐츠를 다시 다운로드해 주세요."라는 예외 메시지를 표시하고, 사용자 선택에 맞추어 **재시도 / 재다운로드 / 고객 지원** UI 분기로 연결해 주는 것이 가장 좋습니다. 세부 콜백 종류에 대한 정보는 [8. 다운로드 이벤트/콜백](/dev-guide/kollus-mobile-app/sdk/ios/guide/event/) 문서를 참고하세요.
