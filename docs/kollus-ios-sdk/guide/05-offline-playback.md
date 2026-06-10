<!-- source: https://docs.kollus.com/dev-guide/kollus-mobile-app/sdk/ios/guide/offline-playback/ -->
<!-- 수집일: 2026-06-10 -->

# 5. 오프라인 재생

로컬 디스크에 다운로드가 완료된 콘텐츠를 재생하는 방법을 설명합니다. 오프라인 상태에서는 온라인 스트리밍 재생 시 사용하는 원격 URL 대신, 다운로드가 완료된 `KollusContent` 인스턴스를 플레이어에 그대로 전달하여 재생을 시작합니다.

이 문서의 모든 예제 코드는 공식 샘플 앱인 `kollus_player_ios`를 바탕으로 작성되었습니다.

## 오프라인 재생

스토리지 매니저를 통해 안전하게 다운로드 완료된 콘텐츠 객체를 확보한 뒤, 플레이어 뷰의 데이터 소스로 주입하여 오프라인 재생을 시작합니다.

#### 1. 다운로드 완료 콘텐츠 탐색

```swift
let downloaded = StorageManager.shared.contents()    .first { $0.mediaContentKey == targetMck && $0.downloaded }
```

#### 2. 플레이어 연결(Attach)

```swift
// 방법 1: KollusPlayerView 인스턴스 속성에 직접 주입playerView.kollusContent = downloaded// 방법 2: PlayerViewController 초기화 시점에 생성자 파라미터로 전달let vc = PlayerViewController(content: downloaded)present(vc, animated: true)
```

### 전체 연동 흐름

1. StorageManager.shared.contents() 목록에서 찾고자 하는 미디어 콘텐츠 키 및 다운로드 완료 조건을 만족하는 객체를 획득합니다.
2. 위의 예시 코드와 같이 KollusPlayerView 객체에 확보한 KollusContent 인스턴스를 연결합니다.
3. 재생 준비 과정에서 SDK가 로컬 DRM 검증을 자동으로 수행합니다. 만약 라이선스가 만료되었거나 권한이 없다면 플레이어가 정지되며 델리게이트 콜백 또는 플레이어 에러로 상태를 통지합니다. (참고 문서: 8. 다운로드 이벤트/콜백)

## 오프라인 DRM 검증 조건

네트워크가 연결되지 않은 오프라인 환경에서도 DRM 검증을 통과하려면, 다운로드 파일 내부에 주입된 아래 4가지 DRM 보안 제한 조건을 모두 만족해야 합니다.

| 속성 | 정상 조건 |
| --- | --- |
| **`DRMExpired`** | `false` 상태를 유지해야 합니다. |
| **`DRMExpireDate`** | 디바이스의 현재 시각이 라이선스에 지정된 만료 일시 이전이어야 합니다. |
| **`drmTotalExpirePlayTime` / `DRMExpirePlayTime`** | 제한 없음(`== 0`) 또는 잔여 재생 허용 시간이 `> 0`이어야 합니다. |
| **`drmExpireCountMax` / `drmExpireCount`** | 제한 없음(`== 0`) 또는 잔여 재생 허용 횟수가 `> 0`이어야 합니다. |

위 4가지 조건 중 단 하나라도 위반될 경우 로컬 재생이 실패하며, 정상 작동을 위해서는 다시 네트워크를 연결하여 라이선스를 갱신해야 합니다. (참고 문서: [6. DRM 라이선스 갱신](/dev-guide/kollus-mobile-app/sdk/ios/guide/license-renewal/))

## DRM 만료 콘텐츠 처리

콘텐츠의 만료 여부를 사전에 판별하기 위해 샘플 애플리케이션이 채택하여 사용하는 비즈니스 유틸 로직 구현 패턴입니다.

```swift
func isExpired(_ content: KollusContent) -> Bool {    // 1. 강제 만료 플래그 상태 검증    if content.DRMExpired { return true }    // 2. 만료 일시 검증    if let expire = content.DRMExpireDate, expire < Date() { return true }    // 3. 누적 재생 시간 제한이 설정된 경우에만 검증 (drmTotalExpirePlayTime == 0 이면 제한 없음)    if content.drmTotalExpirePlayTime > 0 && content.DRMExpirePlayTime <= 0 { return true }    // 4. 재생 횟수 제한이 설정된 경우에만 검증 (drmExpireCountMax == 0 이면 제한 없음)    if content.drmExpireCountMax > 0 && content.drmExpireCount <= 0 { return true }    return false}
```

> **TIP**
>
> 만료 콘텐츠 UX 권장 사항
>
> 위 검증 로직에 의해 만료 상태로 판별되면 아래 흐름 중 하나를 선택하여 UX를 설계합니다.
>
> - 동적 갱신 프로세스 실행: 백그라운드 갱신 API를 즉시 시도하고, 성공 시 재생을 실행합니다.
> - 갱신 실패 시 예외 안내: 갱신 프로세스가 최종 실패하면 사용자에게 라이선스 만료 팝업을 표시하고 재다운로드를 유도합니다.

## DRM 만료 갱신 알림 표시

DRMExpireRefreshPopup 속성은 SDK가 콘솔 서버와 응답 통신을 주고받는 과정에서 갱신 팝업 노출 여부를 동적으로 판별하여 설정하는 제어 플래그입니다. 이 값이 `true`로 수신된다면 가이드에 맞춰 명시적인 알림을 띄워 주는 것이 좋습니다.

```swift
if content.DRMExpireRefreshPopup {    // 사용자 화면에 "라이선스를 갱신하시겠습니까?" 다이얼로그 표시를 권장합니다.}
```

## 파일 삭제 및 손상된 파일 예외 처리

사용자가 로컬 미디어 파일을 임의로 변형하거나 강제로 지웠을 때의 안전한 방어 코드 구현 패턴입니다.

| 상황 | SDK 판단 및 권장 처리 방식 |
| --- | --- |
| **목록에는 존재하지만 실제 파일이 없는 경우** | SDK가 자동으로 정리하므로 호출자(앱 레이어)가 별도 처리할 필요가 없습니다. |
| **파일이 손상된 경우** | 재생 준비 과정에서 플레이어 에러가 발생하여 이벤트를 통지합니다. 사용자에게 파일 결함을 안내하고 재다운로드를 권유하는 메시지를 표시합니다. |
| **`mediaContentKey`가 `nil`인 `KollusContent` 객체가 확인되는 경우** | 실제 파일이 아닌 가상의 폴더(디렉터리) 노드일 수 있습니다. `fileType == 1`인 경우 UI 상에서 폴더 뷰 형태로 예외 분기 처리합니다. |
