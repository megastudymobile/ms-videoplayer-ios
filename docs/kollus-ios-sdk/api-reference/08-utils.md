<!-- source: https://docs.kollus.com/dev-guide/kollus-mobile-app/sdk/ios/api-reference/utils/ -->
<!-- 수집일: 2026-06-10 -->

# Utils

## LogUtil Class

```
#import <LogUtil.h>
```

### Class Methods

- (instancetype) sharedUtil
- (void) utilLog:

### Properties

- id<UtilDelegate> utilDelegate

### Method Details

```
(instancetype) sharedUtil
```

싱글톤 인스턴스를 반환합니다.

```
(void) utilLog: (NSString *) logContent , ...
```

로그 메시지를 출력합니다.

### Property Details

| 속성 | 설명 |
| --- | --- |
| **`(id<UtilDelegate>) utilDelegate`**   `[read, write, nonatomic, weak]` | 로그 수신 델리게이트 |

## UtilDelegate Protocol

```
#import <LogUtil.h>
```

### Instance Methods

- (void) onLogUtil:

### Method Details

```
(void) onLogUtil: (NSString *) logData
```

로그 메시지 수신 시 호출됩니다.

- 파라미터
  - `logData`: 수신된 로그 메시지
