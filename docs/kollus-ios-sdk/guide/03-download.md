<!-- source: https://docs.kollus.com/dev-guide/kollus-mobile-app/sdk/ios/guide/download/ -->
<!-- 수집일: 2026-06-10 -->

# 3. 콘텐츠 다운로드

Kollus SDK를 통한 콘텐츠 다운로드는 항상 **두 단계**를 거쳐 진행됩니다. 먼저 URL에서 콘텐츠 메타 정보를 로드하여 디바이스 검증용 미디어 콘텐츠 키(`mediaContentKey`, `mck`)를 확보한 뒤, 해당 키를 기반으로 실제 파일 다운로드를 시작합니다.

이 문서의 모든 예제 코드는 공식 샘플 앱인 `kollus_player_ios`를 바탕으로 작성되었습니다.

## 다운로드 흐름

```swift
extension StorageManager {    // Step 1: 콘텐츠 메타 정보 로드 (동기)    public func loadContentURL(URL urlString: String,                               completion: @escaping (Error?, String) -> Void) {        do {            let mck = try storage.loadContentURL(urlString)            completion(nil, mck)        } catch {            completion(error, error.localizedDescription)        }    }    // Step 2: 미디어 콘텐츠 키 기반 실제 다운로드 시작    func startDownloadContent(mediaContentKey: String) {        do {            try storage.downloadContent(mediaContentKey)        } catch {            print(error.localizedDescription)        }    }}
```

`loadContentURL` 메서드는 콘텐츠 메타 정보를 SDK의 영속 저장소에 등록하고 `mediaContentKey`를 반환합니다. 동일한 URL을 여러 번 호출하더라도 반환되는 `mediaContentKey`는 동일하게 유지됩니다.

## 중복 다운로드 체크

신규 다운로드 실행 전에 동일한 URL이 이미 다운로드 목록에 등록되어 있는지 확인하려면 `checkContentURL` 메서드를 사용합니다.

```swift
func checkIsDownloadContent(url: String,                            completion: @escaping (Bool, KollusContent?) -> Void) {    DispatchQueue.global().async { [unowned self] in        do {            let mck = try storage.checkContentURL(url)            let list = storage.contents() as! [KollusContent]            if let match = list.first(where: { $0.mediaContentKey == mck }) {                DispatchQueue.main.async { completion(true, match) }            } else {                DispatchQueue.main.async { completion(false, nil) }            }        } catch {            DispatchQueue.main.async { completion(false, nil) }        }    }}
```

### `loadContentURL`과 `checkContentURL` 구분

- `loadContentURL`: 신규 다운로드 진입 (콘텐츠 정보 신규 등록)
- `checkContentURL`: 기존 다운로드 내역 매칭 (등록되지 않은 URL 전달 시 에러 반환)

## 다운로드 취소/일시 중단/재시작 제어 정책

```swift
func cancelDownloadContent(mediaContentKey: String) {    do {        try storage.downloadCancelContent(mediaContentKey)    } catch {        print(error.localizedDescription)    }}
```

| 동작 | API | 설명 |
| --- | --- | --- |
| **다운로드 시작** | `try storage.downloadContent(mck)` | 다운로드를 시작합니다. |
| **다운로드 취소** | `try storage.downloadCancelContent(mck)` | 다운로드 세션을 중단합니다. |
| **다운로드 일시 중단** | 전용 API 없음 | 명시적인 일시정지 API를 제공하지 않으므로 `downloadCancelContent`로 취소 후 재시작합니다. SDK가 내부적으로 일부 데이터를 보존할 수 있으나 일반적으로는 처음부터 다시 받는 것을 가정해야 합니다. |
| **다운로드 재시작** | 다시 `try storage.downloadContent(mck)` 호출 | - |

> **INFO**
>
> 샘플 애플리케이션의 제어 모델
>
> 공식 샘플 앱은 별도의 일시 중단 및 재시작 UI 컴포넌트를 구성하지 않고, **취소 후 재시작** 구조를 채택합니다.

## 다운로드 진행률 추적

실시간 다운로드 진행 상태는 델리게이트 콜백인 `kollusStorage(_:downloadContent:error:)` 내부로 주입되는 `KollusContent` 인스턴스의 속성을 참조하여 추적합니다. 자세한 내용은 [8. 다운로드 이벤트/콜백](/dev-guide/kollus-mobile-app/sdk/ios/guide/event/) 문서를 참고하세요.

| 속성 | 타입 | 의미 |
| --- | --- | --- |
| **`fileSize`** | `long long` | 콘텐츠 파일 크기 |
| **`downloadSize`** | `long long` | 받은 크기 |
| **`downloadProgress`** | `NSUInteger` | 다운로드 진행률 (0~100) |
| **`downloadStopSize`** | `long long` | 다운로드 일시 중단 시점에 보존된 크기 |
| **`downloaded`** | `BOOL` | 다운로드 완료 여부 |
| **`downloadStatus`** | `NSInteger` | 다운로드 진행 상태 코드 |
