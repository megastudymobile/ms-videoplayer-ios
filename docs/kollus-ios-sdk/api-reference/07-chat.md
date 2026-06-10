<!-- source: https://docs.kollus.com/dev-guide/kollus-mobile-app/sdk/ios/api-reference/chat/ -->
<!-- 수집일: 2026-06-10 -->

# KollusChat

## KollusChat Class

```
#import <KollusChat.h>
```

라이브 채팅 연결에 필요한 서버 URL, 사용자 정보 등을 설정하는 클래스입니다.

### Properties

- BOOL isChatVisible
- BOOL isChatInfo
- NSString * chatUrl
- BOOL isAdmin
- BOOL isAnonymous
- NSString * roomId
- NSString * chattingServer
- NSString * userId
- NSString * nickName
- NSString * photoUrl

### Property Details

| 속성 | 설명 |
| --- | --- |
| **`(BOOL) isChatVisible`**   `[read, write, nonatomic, unsafe_unretained]` | 채팅창 노출 여부 |
| **`(BOOL) isChatInfo`**   `[read, write, nonatomic, unsafe_unretained]` | 채팅 정보 존재 여부 |
| **`(NSString*) chatUrl`**   `[read, write, nonatomic, copy]` | 채팅 URL |
| **`(BOOL) isAdmin`**   `[read, write, nonatomic, unsafe_unretained]` | 관리자 여부 |
| **`(BOOL) isAnonymous`**   `[read, write, nonatomic, unsafe_unretained]` | 익명 여부 |
| **`(NSString*) roomId`**   `[read, write, nonatomic, copy]` | 채팅방 ID |
| **`(NSString*) chattingServer`**   `[read, write, nonatomic, copy]` | 채팅 서버 |
| **`(NSString*) userId`**   `[read, write, nonatomic, copy]` | 사용자 ID |
| **`(NSString*) nickName`**   `[read, write, nonatomic, copy]` | 닉네임 |
| **`(NSString*) photoUrl`**   `[read, write, nonatomic, copy]` | 프로필 사진 URL |
