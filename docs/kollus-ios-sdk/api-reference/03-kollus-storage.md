<!-- source: https://docs.kollus.com/dev-guide/kollus-mobile-app/sdk/ios/api-reference/kollus-storage/ -->
<!-- 수집일: 2026-06-10 -->

# KollusStorage

## KollusStorage Class

```
#import <KollusStorage.h>
```

콘텐츠 다운로드·삭제·조회를 관리하는 클래스입니다.

### Instance Methods

- (BOOL) setKollusPath:
- (BOOL) startStorage:
- (BOOL) startStorageWithFirst:error:
- (BOOL) startStorageWithCheck:
- (BOOL) startStorageWithNewPlayerID:
- (NSString *) loadContentURL:error:
- (NSString *) checkContentURL:error:
- (BOOL) downloadContent:error:
- (BOOL) removeContent:error:
- (BOOL) removeCacheWithError:
- (BOOL) downloadCancelContent:error:
- (void) setNetworkTimeOut:retry:
- (void) updateDownloadDRMInfo:
- (void) setCacheSize:
- (void) setBackgroundDownload:
- (NSMutableArray *) contents
- (void) sendStoredLms

### Properties

- id<KollusStorageDelegate> delegate
- NSString * applicationVersion
- NSString * applicationDeviceID
- NSString * applicationKey
- NSString * applicationBundleID
- NSString * keychainGroup
- NSDate * applicationExpireDate
- NSString * storagePath
- long long storageSize
- long long cacheDataSize
- NSInteger serverPort
- NSString * extraDrmParam
- NSString * appUserAgent
- NSString * deviceType

### Method Details

```
(BOOL) setKollusPath: (NSString *) path
```

Kollus SDK가 콘텐츠를 저장할 스토리지 폴더 경로를 설정합니다.

- 주의: 이 메서드는 신규 앱 설치 시에만 사용해야 합니다. 기존 경로를 변경할 경우 이전에 다운로드된 콘텐츠에 접근할 수 없습니다. startStorage 호출 전에 설정되어야 합니다.
- 파라미터
  - `path`: 콘텐츠가 저장될 경로 (기본값: Document)
- 반환값: 처리 결과 (YES: 성공, NO: 실패)

```
(BOOL) startStorage: (NSError **) error
```

`KollusStorage`를 시작합니다.

- 주의: 이 메서드를 호출하지 않으면 콘텐츠 정보 배열(contents)이 nil로 반환되어 다운로드된 콘텐츠에 접근할 수 없습니다.
- 파라미터
  - `error`: 에러 상세
- 반환값: 처리 결과 (YES: 성공, NO: 실패)

```
(BOOL) startStorageWithFirst: (BOOL) first error: (NSError **) error
```

`KollusStorage`를 시작합니다.

- 주의: 이 메서드를 호출하지 않으면 콘텐츠 개수(contentsCount)가 0으로 반환됩니다. 저장된 콘텐츠 목록을 정상적으로 조회하려면 반드시 호출해야 합니다.
- 파라미터
  - `first`: 앱 설치 후 최초 실행 여부
  - `error`: 에러 상세
- 반환값: 처리 결과 (YES: 성공, NO: 실패)

```
(BOOL) startStorageWithCheck: (NSError **) error
```

`KollusStorage`를 시작합니다.

- 주의: 이 메서드를 호출하지 않으면 콘텐츠 개수(contentsCount)가 0으로 반환됩니다. 저장된 콘텐츠 목록을 정상적으로 조회하려면 반드시 호출해야 합니다.
- 플레이어 ID 처리 로직
  - 최초 실행 시: 키체인에 플레이어 ID가 없으면 새 ID를 생성하여 등록합니다.
  - 재실행 시: 키체인에서 ID 획득을 시도하며, 총 3회 연속 실패할 경우 에러를 반환합니다.
- 파라미터
  - `error`: 에러 상세
- 반환값: 처리 결과 (YES: 성공, NO: 실패)

```
(BOOL) startStorageWithNewPlayerID: (NSError **) error
```

`KollusStorage`를 시작합니다.

- 주의: 이 메서드를 호출하지 않으면 콘텐츠 개수(contentsCount)가 0으로 반환됩니다. 저장된 콘텐츠 목록을 정상적으로 조회하려면 반드시 호출해야 합니다. 플레이어 ID를 새로 생성하여 키체인에 등록하므로, 기존 ID에 종속된 데이터 활용 시 주의가 필요합니다.
- 파라미터
  - `error`: 에러 상세
- 반환값: 처리 결과 (YES: 성공, NO: 실패)

```
(NSString *) loadContentURL: (NSString *) URL error: (NSError **) error
```

콘텐츠 다운로드를 초기화합니다.

- 파라미터
  - `URL`: 콘텐츠 URL
  - `error`: 에러 상세
- 반환값: 미디어 콘텐츠 키

```
(NSString*) checkContentURL: (NSString *) URL error: (NSError **) error
```

전달된 URL에 해당하는 콘텐츠의 다운로드 여부와 미디어 콘텐츠 키를 확인합니다.

- 파라미터
  - `URL`: 콘텐츠 URL
  - `error`: 에러 상세
- 반환값: 다운로드된 콘텐츠가 있는 경우 미디어 콘텐츠 키, 없는 경우 nil

```
(BOOL) downloadContent: (NSString *) mediaContentKey error: (NSError **) error
```

미디어 콘텐츠 키를 사용하여 콘텐츠를 다운로드합니다.

- 파라미터
  - `mediaContentKey`: 미디어 콘텐츠 키
  - `error`: 에러 상세
- 반환값: 처리 결과 (YES: 성공, NO: 실패)

```
(BOOL) removeContent: (NSString *) mediaContentKey error: (NSError **) error
```

특정 콘텐츠를 삭제합니다.

- 파라미터
  - `mediaContentKey`: 미디어 콘텐츠 키
  - `error`: 에러 상세
- 반환값: 처리 결과 (YES: 성공, NO: 실패)

```
(BOOL) removeCacheWithError: (NSError **) error
```

스트리밍 콘텐츠의 캐시 데이터를 삭제합니다.

- 파라미터
  - `error`: 에러 상세
- 반환값: 처리 결과 (YES: 성공, NO: 실패)

```
(BOOL) downloadCancelContent: (NSString *) mediaContentKey error: (NSError **) error
```

콘텐츠 다운로드를 중지합니다.

- 파라미터
  - `mediaContentKey`: 미디어 콘텐츠 키
  - `error`: 에러 상세
- 반환값: 처리 결과 (YES: 성공, NO: 실패)

```
(void) setNetworkTimeOut: (NSInteger) timeOut retry: (NSInteger) retryCount
```

스토리지 네트워크 Timeout을 설정합니다.

- 파라미터
  - `timeOut`: Timeout 값 (sec)
  - `retryCount`: 재시도 횟수

```
(void) updateDownloadDRMInfo: (BOOL) bAll
```

DRM 콘텐츠 목록을 업데이트합니다.

- 파라미터
  - `bAll`: 전체 콘텐츠 업데이트 여부 (YES: 전체 콘텐츠 업데이트, NO: 만기된 콘텐츠만 업데이트)

```
(void) setCacheSize: (NSInteger) cacheSizeMB
```

스토리지 캐시 크기를 설정합니다.

- 파라미터
  - `cacheSizeMB`: 스트리밍 콘텐츠 캐시 크기 (MB)

```
(void) setBackgroundDownload: (BOOL) bBackground
```

스토리지 콘텐츠의 백그라운드 다운로드 사용 여부를 설정합니다.

- 파라미터
  - `bBackground`: 백그라운드 다운로드 활성화 여부 (YES: 활성화, NO: 비활성화)

```
(NSMutableArray*) contents
```

다운로드된 콘텐츠 정보 배열을 반환합니다.

```
(void) sendStoredLms
```

미전송된 LMS 데이터를 전송합니다.

### Property Details

| 속성 | 설명 |
| --- | --- |
| **`(id<KollusStorageDelegate>) delegate`**   `[read, write, nonatomic, weak]` | 다운로드 상태정보 델리게이트 |
| **`(NSString*) applicationVersion`**   `[read, nonatomic, copy]` | Kollus SDK 버전 |
| **`(NSString*) applicationDeviceID`**   `[read, nonatomic, copy]` | Kollus 플레이어 디바이스 ID |
| **`(NSString*) applicationKey`**   `[read, write, nonatomic, copy]` | Kollus SDK 인증 키 (카테노이드에서 발급) |
| **`(NSString*) applicationBundleID`**   `[read, write, nonatomic, copy]` | 애플리케이션 Bundle ID (예: `com.yourcompany.applicationname`) |
| **`(NSString*) keychainGroup`**   `[read, write, nonatomic, copy]` | 키체인 그룹 (예: `com.yourcompany.shared`) |
| **`(NSDate*) applicationExpireDate`**   `[read, write, nonatomic, copy]` | Kollus SDK 유효 날짜 (카테노이드에서 발급) |
| **`(NSString*) storagePath`**   `[readonly, nonatomic, copy]` | Kollus SDK 폴더 |
| **`(long long) storageSize`**   `[read, nonatomic, unsafe_unretained]` | 다운로드 콘텐츠의 총 용량 (bytes) |
| **`(long long) cacheDataSize`**   `[read, nonatomic, unsafe_unretained]` | 스트리밍 캐시 데이터의 총 용량 (bytes) |
| **`(NSInteger) serverPort`**   `[read, write, nonatomic, assign]` | 하이브리드 앱에서 사용되는 포트 번호 |
| **`(NSString*) extraDrmParam`**   `[read, write, nonatomic, copy]` | 동적 DRM 파라미터 |
| **`(NSString*) appUserAgent`**   `[read, nonatomic, copy]` | HTTP 요청 시 사용할 User-Agent 문자열 |
| **`(NSString*) deviceType`**   `[read, nonatomic, copy]` | 디바이스 유형 (`kp-mobile`: 모바일, `kp-tablet`: 태블릿) |

## KollusStorageDelegate Protocol

```
#import <KollusStorageDelegate.h>
```

다운로드 진행 상태와 DRM 콜백 이벤트를 수신하는 프로토콜입니다.

### Instance Methods

- (void) kollusStorage:downloadContent:error:
- (void) kollusStorage:request:json:error:
- (void) kollusStorage:cur:count:error:
- (void) kollusStorage:lmsData:resultJson:
- (void) onSendCompleteStoredLms:failCount:

### Method Details

```
(void) kollusStorage: (KollusStorage *) kollusStorage cur: (int) cur count: (int) count error: (NSError *) error
```

DRM 콘텐츠 목록을 일괄 업데이트하는 중 각 콘텐츠 업데이트가 완료될 때 호출됩니다.

- 파라미터
  - `kollusStorage`: KollusStorage ID
  - `cur`: 현재 항목
  - `count`: 전체 콘텐츠 개수
  - `error`: 에러 상세 (nil이 아닌 경우 에러 발생)

```
(void) kollusStorage: (KollusStorage *) kollusStorage downloadContent: (KollusContent *) content error: (NSError *) error
```

콘텐츠 다운로드 중 상태 변화가 있는 경우 호출됩니다.

- 파라미터
  - `kollusStorage`: KollusStorage ID
  - `content`: 상태 변화가 있는 콘텐츠 정보
  - `error`: 에러 상세 (nil이 아닌 경우 에러 발생)

```
(void) kollusStorage: (KollusStorage *) kollusStorage lmsData: (NSString *) lmsData resultJson: (NSDictionary *) resultJsonLMS
```

LMS 콜백 처리 후 호출됩니다.

- 파라미터
  - `kollusStorage`: KollusStorage ID
  - `lmsData`: LMS 데이터
  - `resultJsonLMS`: LMS result 정보

```
(void) kollusStorage: (KollusStorage *) kollusStorage request: (NSDictionary *) request json: (NSDictionary *) json error: (NSError *) error
```

DRM 다운로드 콜백 처리 후 호출됩니다.

- 파라미터
  - `kollusStorage`: KollusStorage ID
  - `request`: 요청 정보
  - `json`: 응답 데이터
  - `error`: 에러 상세 (nil이 아닌 경우 에러 발생)

```
(void) onSendCompleteStoredLms: (int) successCount failCount: (int) failCount
```

미전송 LMS 콜백 완료 후 호출됩니다.

- 파라미터
  - `successCount`: LMS 전송 성공 횟수
  - `failCount`: LMS 전송 실패 횟수
