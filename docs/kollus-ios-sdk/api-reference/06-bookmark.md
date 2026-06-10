<!-- source: https://docs.kollus.com/dev-guide/kollus-mobile-app/sdk/ios/api-reference/bookmark/ -->
<!-- 수집일: 2026-06-10 -->

# KollusBookmark

## KollusBookmark Class

```
#import <KollusBookmark.h>
```

북마크 정보를 담는 클래스입니다.

### Properties

- NSTimeInterval position
- NSDate * time
- NSString * title
- NSString * value
- KollusBookmarkKind kind

### Property Details

| 속성 | 설명 |
| --- | --- |
| **`(NSTimeInterval) position`**   `[read, nonatomic, unsafe_unretained]` | 북마크 위치 |
| **`(NSDate*) time`**   `[read, nonatomic, unsafe_unretained]` | 북마크가 추가된 시각 |
| **`(NSString*) title`**   `[read, nonatomic, copy]` | 북마크 제목 (고객사 설정 북마크) |
| **`(NSString*) value`**   `[read, nonatomic, copy]` | 북마크 제목 (시청자 설정 북마크) |
| **`(KollusBookmarkKind) kind`**   `[read, nonatomic, assign]` | 북마크 종류 |
