<!-- source: https://docs.kollus.com/dev-guide/kollus-mobile-app/sdk/ios/api-reference/chapter-subtitle/ -->
<!-- 수집일: 2026-06-10 -->

# Chapter & Subtitle

## Chapter Class

```
#import <Chapter.h>
```

챕터 정보를 담는 클래스입니다.

### Properties

- NSTimeInterval position
- NSString * value

### Property Details

| 속성 | 설명 |
| --- | --- |
| **`(NSTimeInterval) position`**   `[nonatomic, unsafe_unretained]` | 챕터 위치 |
| **`(NSString*) value`**   `[nonatomic, retain]` | 챕터 제목 |

## ChapterDict Class

```
#import <Chapter.h>
```

언어별 챕터 목록을 담는 클래스입니다.

### Properties

- NSString * strLanguage
- NSMutableArray * listChapter

### Property Details

| 속성 | 설명 |
| --- | --- |
| **`(NSString*) strLanguage`**   `[nonatomic, retain]` | 챕터 언어 |
| **`(NSMutableArray*) listChapter`**   `[nonatomic, retain]` | 챕터 목록 |

## KPSection Class

```
#import <KPSection.h>
```

미리보기(Preview) 구간의 시작/종료 시각을 담는 클래스입니다.

### Properties

- NSInteger startTime
- NSInteger endTime

### Property Details

| 속성 | 설명 |
| --- | --- |
| **`(NSInteger) startTime`**   `[read, write, nonatomic, unsafe_unretained]` | 재생 구간 시작 시각 (sec) |
| **`(NSInteger) endTime`**   `[read, write, nonatomic, unsafe_unretained]` | 재생 구간 종료 시각 (sec) |

## SubTitleInfo Class

```
#import <SubTitleInfo.h>
```

자막 이름, 경로, 언어 등 자막 파일 정보를 담는 클래스입니다.

### Properties

- NSString * strName
- NSString * strUrl
- NSString * strLanguage
- BOOL isAISubtitles

### Property Details

| 속성 | 설명 |
| --- | --- |
| **`(NSString*) strName`**   `[read, nonatomic, retain]` | 자막 이름 |
| **`(NSString*) strUrl`**   `[read, nonatomic, retain]` | 자막 경로 |
| **`(NSString*) strLanguage`**   `[read, nonatomic, retain]` | 자막 언어 |
| **`(BOOL) isAISubtitles`**   `[read, nonatomic, unsafe_unretained]` | AI 생성 자막 여부 |
