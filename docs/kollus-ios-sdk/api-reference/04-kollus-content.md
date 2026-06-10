<!-- source: https://docs.kollus.com/dev-guide/kollus-mobile-app/sdk/ios/api-reference/kollus-content/ -->
<!-- 수집일: 2026-06-10 -->

# KollusContent

## KollusContent Class

```
#import <KollusContent.h>
```

재생할 콘텐츠의 URL, DRM 정보, 다운로드 상태 등 콘텐츠 메타데이터를 담는 클래스입니다.

### Properties

- NSString * company
- NSString * title
- NSString * course
- NSString * teacher
- NSString * snapshot
- NSString * thumbnail
- NSString * mediaContentKey
- NSString * synopsis
- NSString * descriptionURL
- CGSize naturalSize
- NSString * iosPlayerType
- KollusContentType contentType
- NSDate * DRMCheckDate
- NSDate * DRMExpireDate
- long DRMExpireCountMax
- long DRMExpireCount
- NSTimeInterval DRMTotalExpirePlayTime
- NSTimeInterval DRMExpirePlayTime
- BOOL DRMExpired
- BOOL DRMExpireRefreshPopup
- NSTimeInterval duration
- NSTimeInterval position
- NSUInteger contentIndex
- long long fileSize
- long long downloadSize
- NSUInteger downloadProgress
- BOOL downloaded
- long long downloadStopSize
- int downloadedTime

### Property Details

| 속성 | 설명 |
| --- | --- |
| **`(NSString*) company`**   `[read, nonatomic, copy]` | 회사명 |
| **`(NSString*) title`**   `[read, nonatomic, copy]` | 콘텐츠 제목 |
| **`(NSString*) course`**   `[read, nonatomic, copy]` | 교육 과정명 |
| **`(NSString*) teacher`**   `[read, nonatomic, copy]` | 강사명 |
| **`(NSString*) snapshot`**   `[read, nonatomic, copy]` | 스냅샷 파일 경로 |
| **`(NSString*) thumbnail`**   `[read, nonatomic, copy]` | 섬네일 파일 경로 |
| **`(NSString*) mediaContentKey`**   `[read, nonatomic, copy]` | 미디어 콘텐츠 키 |
| **`(NSString*) synopsis`**   `[read, nonatomic, copy]` | 시놉시스 |
| **`(NSString*) descriptionURL`**   `[read, nonatomic, copy]` | 상세 정보 URL |
| **`(CGSize) naturalSize`**   `[read, nonatomic, unsafe_unretained]` | 영상 원본 해상도 |
| **`(NSString*) iosPlayerType`**   `[read, nonatomic, copy]` | iOS 플레이어 타입 (`hw`, `sw`, `native`) |
| **`(KollusContentType) contentType`**   `[read, nonatomic, unsafe_unretained]` | 콘텐츠 타입 |
| **`(NSDate*) DRMCheckDate`**   `[read, nonatomic, strong]` | DRM 인증 확인 일시 |
| **`(NSDate*) DRMExpireDate`**   `[read, nonatomic, strong]` | DRM 만료 일시 |
| **`(long) DRMExpireCountMax`**   `[read, nonatomic, unsafe_unretained]` | DRM 최대 재생 횟수 |
| **`(long) DRMExpireCount`**   `[read, nonatomic, unsafe_unretained]` | DRM 재생 횟수 |
| **`(NSTimeInterval) DRMTotalExpirePlayTime`**   `[read, nonatomic, unsafe_unretained]` | DRM 총 재생 가능 시간 |
| **`(NSTimeInterval) DRMExpirePlayTime`**   `[read, nonatomic, unsafe_unretained]` | DRM 남은 재생 가능 시간 |
| **`(BOOL) DRMExpired`**   `[read, nonatomic, unsafe_unretained]` | DRM 만료 여부 |
| **`(BOOL) DRMExpireRefreshPopup`**   `[read, nonatomic, unsafe_unretained]` | DRM 갱신(Renewal) 알림 팝업 표시 여부 |
| **`(NSTimeInterval) duration`**   `[read, nonatomic, unsafe_unretained]` | 콘텐츠 전체 길이 |
| **`(NSTimeInterval) position`**   `[read, nonatomic, unsafe_unretained]` | 마지막 재생 시점 |
| **`(NSUInteger) contentIndex`**   `[read, nonatomic, unsafe_unretained]` | 콘텐츠 인덱스 (다운로드 콘텐츠 재생 시 사용) |
| **`(long long) fileSize`**   `[read, nonatomic, unsafe_unretained]` | 콘텐츠 파일 크기 |
| **`(long long) downloadSize`**   `[read, nonatomic, unsafe_unretained]` | 다운로드 완료된 파일 크기 |
| **`(NSUInteger) downloadProgress`**   `[read, nonatomic, unsafe_unretained]` | 다운로드 진행률 (%) |
| **`(BOOL) downloaded`**   `[read, nonatomic, unsafe_unretained]` | 다운로드 완료 여부 |
| **`(long long) downloadStopSize`**   `[read, nonatomic, unsafe_unretained]` | 다운로드가 중지된 파일 크기 |
| **`(int) downloadedTime`**   `[read, nonatomic, unsafe_unretained]` | 다운로드 완료 일시 |
