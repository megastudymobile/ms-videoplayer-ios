<!-- source: https://docs.kollus.com/dev-guide/kollus-mobile-app/sdk/ios/api-reference/player-delegates/ -->
<!-- 수집일: 2026-06-10 -->

# Player Delegates

## KollusPlayerBookmarkDelegate Protocol

```
#import <KollusPlayerBookmarkDelegate.h>
```

재생 콘텐츠의 북마크 정보를 수신하는 프로토콜입니다.

### Instance Methods

- (void) kollusPlayerView:bookmark:enabled:error:

### Method Details

```
(void) kollusPlayerView: (KollusPlayerView *) kollusPlayerView bookmark: (NSArray *) bookmarks enabled: (BOOL) enabled error: (NSError *) error
```

재생 중인 콘텐츠의 북마크 정보가 로드될 때 호출됩니다.

- 파라미터
  - `kollusPlayerView`: KollusPlayerView ID
  - `bookmarks`: KollusBookmark 객체 배열
  - `enabled`: 북마크 유무 (YES: 북마크 있음, NO: 북마크 없음)
  - `error`: 에러 상세

## KollusPlayerDelegate Protocol

```
#import <KollusPlayerDelegate.h>
```

재생·일시정지·정지·버퍼링 등 플레이어 재생 라이프사이클 이벤트를 수신하는 프로토콜입니다.

### Instance Methods

- (void) kollusPlayerView:prepareToPlayWithError:
- (void) kollusPlayerView:play:error:
- (void) kollusPlayerView:pause:error:
- (void) kollusPlayerView:buffering:prepared:error:
- (void) kollusPlayerView:stop:error:
- (void) kollusPlayerView:position:error:
- (void) kollusPlayerView:scroll:error:
- (void) kollusPlayerView:zoom:error:
- (void) kollusPlayerView:naturalSize:
- (void) kollusPlayerView:playerContentMode:error:
- (void) kollusPlayerView:playerContentFrame:error:
- (void) kollusPlayerView:playbackRate:error:
- (void) kollusPlayerView:repeat:error:
- (void) kollusPlayerView:enabledOutput:error:
- (void) kollusPlayerView:unknownError:
- (void) kollusPlayerView:framerate:
- (void) kollusPlayerView:lockedPlayer:
- (void) kollusPlayerView:charset:caption:
- (void) kollusPlayerView:charsetSub:captionSub:
- (void) kollusPlayerView:thumbnail:error:
- (void) kollusPlayerView:mck:
- (void) kollusPlayerView:height:
- (void) kollusPlayerView:bitrate:

### Method Details

```
(void) kollusPlayerView: (KollusPlayerView *) kollusPlayerView prepareToPlayWithError: (NSError *) error
```

`prepareToPlayWithMode:error:` 메서드 호출 이후, 재생 준비가 최종적으로 완료되었거나 실패했을 때 호출됩니다.

- 파라미터
  - `kollusPlayerView`: KollusPlayerView ID
  - `error`: 에러 상세 (nil이 아닌 경우 재생 준비 실패)

```
(void) kollusPlayerView: (KollusPlayerView *) kollusPlayerView play: (BOOL) userInteraction error: (NSError *) error
```

콘텐츠의 재생이 실제로 시작되었을 때 호출됩니다.

- 파라미터
  - `kollusPlayerView`: KollusPlayerView ID
  - `userInteraction`: 재생 시작의 주체 (YES: 사용자가 재생, NO: 시스템이 시작)
  - `error`: 에러 상세

```
(void) kollusPlayerView: (KollusPlayerView *) kollusPlayerView pause: (BOOL) userInteraction error: (NSError *) error
```

재생 중인 콘텐츠가 일시정지 상태로 전환될 때 호출됩니다.

- 파라미터
  - `kollusPlayerView`: KollusPlayerView ID
  - `userInteraction`: 일시정지의 주체 (YES: 사용자가 일시정지, NO: 시스템이 일시정지)
  - `error`: 에러 상세

```
(void) kollusPlayerView: (KollusPlayerView *) kollusPlayerView buffering: (BOOL) buffering prepared: (BOOL) prepared error: (NSError *) error
```

네트워크 환경 등으로 인해 데이터 버퍼링이 발생하거나 상태가 해소되었을 때 호출됩니다.

- 주의: 시스템에 의해 일시정지된 후 buffering 값이 YES로 변경된 경우, 버퍼링이 완료(buffering 값이 NO)되는 시점에 수동으로 playWithError: 메서드를 호출하여 재생을 재개해야 합니다.
- 파라미터
  - `kollusPlayerView`: KollusPlayerView ID
  - `buffering`: 버퍼링 상태 (YES: 버퍼링 중, NO: 버퍼링 해제)
  - `prepared`: 재생 준비 상태 (YES: 재생 준비 완료, NO: 준비 전)
  - `error`: 에러 상세

```
(void) kollusPlayerView: (KollusPlayerView *) kollusPlayerView stop: (BOOL) userInteraction error: (NSError *) error
```

콘텐츠 재생이 완전히 정지되었을 때 호출됩니다.

- 파라미터
  - `kollusPlayerView`: KollusPlayerView ID
  - `userInteraction`: 정지의 주체 (YES: 사용자가 종료, NO: 콘텐츠 재생 완료 또는 시스템 강제 종료)
  - `error`: 에러 상세

```
(void) kollusPlayerView: (KollusPlayerView *) kollusPlayerView position: (NSTimeInterval) position error: (NSError *) error
```

사용자의 탐색(Seek) 동작이나 내부 로직에 의해 재생 위치가 변경될 때 호출됩니다.

- 파라미터
  - `kollusPlayerView`: KollusPlayerView ID
  - `position`: 변경된 후의 재생 시점
  - `error`: 에러 상세

```
(void) kollusPlayerView: (KollusPlayerView *) kollusPlayerView scroll: (CGPoint) distance error: (NSError *) error
```

사용자의 드래그 동작 등으로 인해 영상 화면이 이동(Scroll)할 때 호출됩니다.

- 파라미터
  - `kollusPlayerView`: KollusPlayerView ID
  - `distance`: 화면이 이동한 거리 값
  - `error`: 에러 상세

```
(void) kollusPlayerView: (KollusPlayerView *) kollusPlayerView zoom: (UIPinchGestureRecognizer *) recognizer error: (NSError **) error
```

핀치 제스처(Pinch Gesture)를 통해 영상 화면이 확대 또는 축소될 때 호출됩니다.

- 파라미터
  - `kollusPlayerView`: KollusPlayerView ID
  - `recognizer`: 줌 이벤트를 전달하는 제스처 인식기 객체
  - `error`: 에러 상세

```
(void) kollusPlayerView: (KollusPlayerView *) kollusPlayerView naturalSize: (CGSize) naturalSize
```

재생하려는 콘텐츠의 원본 해상도 정보가 확인되는 시점에 호출됩니다.

- 파라미터
  - `kollusPlayerView`: KollusPlayerView ID
  - `naturalSize`: 원본 영상 해상도

```
(void) kollusPlayerView: (KollusPlayerView *) kollusPlayerView playerContentMode: (KollusPlayerContentMode) playerContentMode error: (NSError *) error
```

재생 화면 모드가 변경되었을 때 호출됩니다.

- 파라미터
  - `kollusPlayerView`: KollusPlayerView ID
  - `playerContentMode`: 새롭게 적용된 화면 모드
  - `error`: 에러 상세

```
(void) kollusPlayerView: (KollusPlayerView *) kollusPlayerView playerContentFrame: (CGRect) contentFrame error: (NSError *) error
```

뷰의 레이아웃이나 프레임 크기가 실제로 변경되었을 때 호출됩니다.

- 파라미터
  - `kollusPlayerView`: KollusPlayerView ID
  - `contentFrame`: 변경된 화면 크기와 위치 정보
  - `error`: 에러 상세

```
(void) kollusPlayerView: (KollusPlayerView *) kollusPlayerView playbackRate: (float) playbackRate error: (NSError *) error
```

배속 재생 설정이 변경되어 영상의 재생속도가 변경되었을 때 호출됩니다.

- 파라미터
  - `kollusPlayerView`: KollusPlayerView ID
  - `playbackRate`: 변경된 재생속도
  - `error`: 에러 상세

```
(void) kollusPlayerView: (KollusPlayerView *) kollusPlayerView repeat: (BOOL) repeat error: (NSError *) error
```

콘텐츠의 구간 반복 또는 전체 반복 재생 설정이 변경되었을 때 호출됩니다.

- 파라미터
  - `kollusPlayerView`: KollusPlayerView ID
  - `repeat`: 반복 재생 모드 활성화 여부 (YES: 반복 설정, NO: 반복 해제)
  - `error`: 에러 상세

```
(void) kollusPlayerView: (KollusPlayerView *) kollusPlayerView enabledOutput: (BOOL) enabledOutput error: (NSError *) error
```

HDMI 연결, AirPlay 등 외부 기기를 통한 TV 출력 허용 여부가 결정될 때 호출됩니다.

- 파라미터
  - `kollusPlayerView`: KollusPlayerView ID
  - `enabledOutput`: 외부 기기 출력 허용 상태 (YES: 출력 허용, NO: 출력 차단)
  - `error`: 에러 상세

```
(void) kollusPlayerView: (KollusPlayerView *) kollusPlayerView unknownError: (NSError *) error
```

기타 정의되지 않은 예외 상황이나 알 수 없는 오류가 발생했을 때 호출됩니다.

- 파라미터
  - `kollusPlayerView`: KollusPlayerView ID
  - `error`: 에러 상세

```
(void) kollusPlayerView: (KollusPlayerView *) kollusPlayerView framerate: (int) framerate
```

현재 재생 중인 콘텐츠의 초당 프레임 수(FPS) 정보가 확인되는 시점에 호출됩니다.

- 파라미터
  - `kollusPlayerView`: KollusPlayerView ID
  - `framerate`: 영상의 프레임레이트

```
(void) kollusPlayerView: (KollusPlayerView *) kollusPlayerView lockedPlayer: (KollusPlayerType) playerType
```

디바이스의 시스템 잠금(Lock)이 발생하거나 플레이어 화면이 잠길 때 호출됩니다.

- 파라미터
  - `kollusPlayerView`: KollusPlayerView ID
  - `playerType`: 플레이어 타입

```
(void) kollusPlayerView: (KollusPlayerView *) kollusPlayerView charset: (char *) charset caption: (char *) caption
```

메인 자막 데이터가 갱신되어 화면에 새로운 자막을 출력해야 할 때 호출됩니다.

- 파라미터
  - `kollusPlayerView`: KollusPlayerView ID
  - `charset`: 자막 데이터의 문자 인코딩 세트(Character Set)
  - `caption`: 실제 화면에 렌더링될 자막 텍스트 데이터

```
(void) kollusPlayerView: (KollusPlayerView *) kollusPlayerView charsetSub: (char *) charsetSub captionSub: (char *) captionSub
```

서브 자막 데이터가 갱신될 때 호출됩니다.

- 파라미터
  - `kollusPlayerView`: KollusPlayerView ID
  - `charsetSub`: 서브 자막 데이터의 문자 인코딩 세트(Character Set)
  - `captionSub`: 실제 화면에 렌더링될 서브 자막 텍스트 데이터

```
(void) kollusPlayerView: (KollusPlayerView *) kollusPlayerView thumbnail: (BOOL) isThumbnail error: (NSError *) error
```

요청한 섬네일 이미지의 비동기 다운로드가 완료되었을 때 호출됩니다.

- 파라미터
  - `kollusPlayerView`: KollusPlayerView ID
  - `isThumbnail`: 섬네일 유무
  - `error`: 에러 상세

```
(void) kollusPlayerView: (KollusPlayerView *) kollusPlayerView mck: (NSString *) mck
```

재생 중인 콘텐츠의 미디어 콘텐츠 키가 확인될 때 호출됩니다.

- 파라미터
  - `kollusPlayerView`: KollusPlayerView ID
  - `mck`: 미디어 콘텐츠 키

```
(void) kollusPlayerView: (KollusPlayerView *) view height: (int) height
```

HLS 콘텐츠 재생 중 네트워크 상태에 따라 현재 출력되는 영상의 해상도(세로 높이)가 변경될 때 호출됩니다.

- 파라미터
  - `kollusPlayerView`: KollusPlayerView ID
  - `height`: 현재 재생 중인 영상의 세로 해상도 값 (px)

```
(void) kollusPlayerView: (KollusPlayerView *) view bitrate: (int) bitrate
```

HLS 스트리밍 중 대역폭 변화에 따라 비트레이트(Bitrate) 정보가 갱신될 때 호출됩니다.

- 파라미터
  - `kollusPlayerView`: KollusPlayerView ID
  - `bitrate`: 현재 비트레이트 값 (kbps)

## KollusPlayerDRMDelegate Protocol

```
#import <KollusPlayerDRMDelegate.h>
```

DRM 콜백 전송 결과를 수신하는 프로토콜입니다.

### Instance Methods

- (void) kollusPlayerView:request:json:error:

### Method Details

```
(void) kollusPlayerView: (KollusPlayerView *) kollusPlayerView request: (NSDictionary *) request json: (NSDictionary *) json error: (NSError *) error
```

DRM 라이선스 검증을 위한 서버 통신(콜백)이 완료된 후 호출됩니다.

- 파라미터
  - `kollusPlayerView`: KollusPlayerView ID
  - `request`: 서버로 전송했던 DRM 요청 데이터
  - `json`: 서버로부터 수신한 DRM 응답 결과 데이터
  - `error`: 에러 상세

## KollusPlayerLMSDelegate Protocol

```
#import <KollusPlayerLMSDelegate.h>
```

LMS 정보 전송 결과를 수신하는 프로토콜입니다.

### Instance Methods

- (void) kollusPlayerView:lmsData:resultJson:

### Method Details

```
(void) kollusPlayerView: (KollusPlayerView *) kollusPlayerView lmsData:(NSString *)lmsData resultJson:(NSDictionary *)resultJson
```

LMS 데이터 전송 완료 후 호출됩니다.

- 파라미터
  - `kollusPlayerView`: KollusPlayerView ID
  - `lmsData`: 서버로 전송된 LMS 데이터 문자열
  - `resultJson`: LMS 서버로부터 수신한 처리 결과 데이터
