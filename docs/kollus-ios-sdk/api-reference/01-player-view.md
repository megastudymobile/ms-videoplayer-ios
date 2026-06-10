<!-- source: https://docs.kollus.com/dev-guide/kollus-mobile-app/sdk/ios/api-reference/player-view/ -->
<!-- 수집일: 2026-06-10 -->

# KollusPlayerView

## KollusPlayerView Class

```
#import <KollusPlayerView.h>
```

콘텐츠 재생, 화면 출력 제어, 이벤트 델리게이트 설정 등 플레이어의 모든 기능을 제어하는 핵심 클래스입니다.

### Instance Methods

- (id) initWithContentURL:
- (id) initWithMediaContentKey:
- (BOOL) prepareToPlayWithMode:error:
- (BOOL) playWithError:
- (BOOL) pauseWithError:
- (BOOL) stopWithError:
- (BOOL) scroll:error:
- (BOOL) scrollStopWithError:
- (BOOL) zoom:error:
- (BOOL) addBookmark:value:error:
- (BOOL) removeBookmark:error:
- (void) setNetworkTimeOut:
- (void) setBufferingRatio:
- (BOOL) isOpened
- (BOOL) setSkipPlay
- (void) changeBandWidth:
- (bool) setSubTitlePath:
- (bool) setSubTitleSubPath:
- (CGRect) getVideoPosition
- (CGFloat) getZoomValue
- (void) setPauseOnForeground:
- (void) setDisableZoomOut:
- (void) setDecoder:
- (void) setAIRate:

### Properties

- id<KollusPlayerDelegate> delegate
- id<KollusPlayerDRMDelegate> DRMDelegate
- id<KollusPlayerLMSDelegate> LMSDelegate
- id<KollusPlayerBookmarkDelegate> bookmarkDelegate
- KollusStorage * storage
- NSString * contentURL
- NSString * mediaContentKey
- KollusContent * content
- BOOL AIRateEnable
- NSTimeInterval currentPlaybackTime
- NSTimeInterval liveDuration
- float currentPlaybackRate
- NSArray * bookmarks
- KollusPlayerContentMode scalingMode
- CGRect playerContentFrame
- KollusPlayerRepeatMode repeatMode
- BOOL screenConnectEnabled
- BOOL bookmarkModifyEnabled
- BOOL debug
- BOOL isPreparedToPlay
- BOOL isPlaying
- BOOL isBuffering
- BOOL isSeeking
- BOOL isScrolling
- BOOL isAudioOnly
- BOOL muteOnStart
- CGSize naturalSize
- BOOL isZoomedIn
- KollusPlayerType playerType
- NSString * customSkin
- KPSection * playSection
- NSInteger nRepeatStartTime
- NSInteger nRepeatEndTime
- NSInteger nPlaybackLimitDuration
- NSString * strPlaybackLimitMessage
- BOOL audioBackgroundPlay
- BOOL lmsOffDownloadContent
- NSUInteger proxyPort
- BOOL intro
- BOOL seekable
- NSInteger nSecSkip
- BOOL isLive
- BOOL disablePlayRate
- NSInteger nSeekableEnd
- NSString * strCaptionStyle
- BOOL forceNScreen
- BOOL ignoreZero
- BOOL isThumbnailEnable
- BOOL isThumbnailSync
- NSString * fpsCertURL
- NSString * fpsDrmURL
- NSInteger nOfflineBookmarkUse
- NSInteger nOfflineBookmarkDownload
- NSInteger nOfflineBookmarkReadOnly
- NSMutableDictionary * chapterInfo
- NSString * strVideoWaterMark
- NSInteger nVideoWaterMarkAlpha
- NSInteger nVideoWaterMarkFontSize
- NSString * strVideoWaterMarkFontColor
- NSInteger nVideoWaterMarkShowTime
- NSInteger nVideoWaterMarkHideTime
- NSString * extraDrmParam
- NSMutableArray * streamInfoList
- KollusChat * kollusChat
- NSInteger nextEpisodeShowTime
- NSString * nextEpisodeCallbackURL
- NSMutableDictionary * nextEpisodeCallbackParams
- BOOL nextEpisodeShowButton
- NSString *contentProviderKey
- NSString *contentProviderName
- BOOL disableBackgroundAudio
- NSInteger maxPlaybackRate
- NSMutableArray * listSubTitle
- NSMutableArray * listSubTitleSub

### Method Details

```
(id) initWithContentURL: (NSString *) url
```

콘텐츠 URL을 기반으로 플레이어를 초기화합니다.

- 파라미터
  - `url`: 콘텐츠 URL
- 반환값: 생성된 플레이어 ID

```
(id) initWithMediaContentKey: (NSString *) mck
```

미디어 콘텐츠 키를 기반으로 플레이어를 초기화합니다. 오프라인(다운로드) 콘텐츠 재생 시 사용합니다.

- 파라미터
  - `mck`: 미디어 콘텐츠 키
- 반환값: 생성된 플레이어 ID

```
(BOOL) prepareToPlayWithMode: (KollusPlayerType) type error: (NSError **) error
```

플레이어 타입(Kollus 또는 Native)으로 콘텐츠 재생을 준비합니다.

- 파라미터
  - `type`: 플레이어 타입
  - `error`: 에러 상세
- 반환값: 처리 결과 (YES: 성공, NO: 실패)

```
(BOOL) playWithError: (NSError **) error
```

`prepareToPlayWithMode:error:` 호출이 성공한 경우 재생을 시작합니다.

- 파라미터
  - `error`: 에러 상세
- 반환값: 처리 결과 (YES: 성공, NO: 실패)

```
(BOOL) pauseWithError: (NSError **) error
```

`prepareToPlayWithMode:error:` 호출이 성공한 경우 재생을 일시정지합니다.

- 파라미터
  - `error`: 에러 상세
- 반환값: 처리 결과 (YES: 성공, NO: 실패)

```
(BOOL) stopWithError: (NSError **) error
```

`prepareToPlayWithMode:error:` 호출이 성공한 경우 재생을 중지합니다. 플레이어 타입이 `PlayerTypeKollus`인 경우에만 적용됩니다.

- 파라미터
  - `error`: 에러 상세
- 반환값: 처리 결과 (YES: 성공, NO: 실패)

```
(BOOL) scroll: (CGPoint) distance error: (NSError **) error
```

비디오가 출력되는 화면 영역의 좌표를 이동시킵니다.

- 파라미터
  - `distance`: 이동할 거리
  - `error`: 에러 상세
- 반환값: 처리 결과 (YES: 성공, NO: 실패)

```
(BOOL) scrollStopWithError: (NSError **) error
```

비디오 화면의 이동을 중단하고 현재 위치에 화면을 고정합니다.

- 파라미터
  - `error`: 에러 상세
- 반환값: 처리 결과 (YES: 성공, NO: 실패)

```
(BOOL) zoom: (UIPinchGestureRecognizer *) recognizer error: (NSError **) error
```

사용자의 핀치 제스처를 기반으로 비디오 화면을 동적으로 확대하거나 축소합니다.

- 파라미터
  - `recognizer`: 확대를 위한 핀치 제스처 정보를 담고 있는 객체 포인터
  - `error`: 에러 상세
- 반환값: 처리 결과 (YES: 성공, NO: 실패)

```
(BOOL) addBookmark: (NSTimeInterval) position value: (NSString *) value error: (NSError **) error
```

북마크를 추가합니다. 북마크가 이미 존재하는 경우 덮어씁니다.

- 파라미터
  - `position`: 북마크를 추가할 위치
  - `value`: 북마크 내용
  - `error`: 에러 상세
- 반환값: 처리 결과 (YES: 성공, NO: 실패)

```
(BOOL) removeBookmark: (NSTimeInterval) position error: (NSError **) error
```

북마크를 삭제합니다. `KollusBookmarkKindIndex` 타입의 북마크는 삭제되지 않습니다.

- 파라미터
  - `position`: 삭제할 북마크 위치
  - `error`: 에러 상세
- 반환값: 처리 결과 (YES: 성공, NO: 실패)

```
(void) setNetworkTimeOut: (NSInteger) timeOut
```

플레이어 네트워크 Timeout을 설정합니다.

- 파라미터
  - `timeOut`: Timeout 값 (sec)

```
(void) setBufferingRatio: (NSInteger) bufferingRatio
```

`prepareToPlayWithMode:error:` 호출이 성공한 경우 버퍼링 배수를 설정합니다. `PlayerTypeKollus`인 경우에만 적용됩니다.

- 파라미터
  - `bufferingRatio`: 설정할 버퍼링 배수

```
(BOOL) isOpened
```

플레이어 생성 여부를 확인합니다.

- 반환값: 생성 여부 (YES: 생성됨, NO: 생성 안 됨)

```
(BOOL) setSkipPlay
```

재생 목록에서 현재 재생 중인 동영상을 건너뜁니다.

- 반환값: 처리 결과 (YES: 성공, NO: 실패)

```
(void) changeBandWidth: (int) bandWidth
```

HLS 재생 중 대역폭(bandwidth)을 변경합니다.

- 파라미터
  - `bandWidth`: 설정할 대역폭 값

```
(bool) setSubTitlePath: (char *) path
```

사용할 자막 파일을 선택합니다.

- 파라미터
  - `path`: 사용할 자막 파일 경로
- 반환값: 처리 결과 (YES: 성공, NO: 실패)

```
(bool) setSubTitleSubPath: (char *) path
```

사용할 서브 자막 파일을 선택합니다.

- 파라미터
  - `path`: 사용할 자막 파일 경로
- 반환값: 처리 결과 (YES: 성공, NO: 실패)

```
(CGRect) getVideoPosition
```

현재 비디오의 재생 영역 좌표를 반환합니다.

- 반환값: 비디오 재생 영역

```
(CGFloat) getZoomValue
```

비디오 출력화면의 확대/축소 비율을 반환합니다.

- 반환값: 출력화면 확대/축소 비율 값

```
(void) setPauseOnForeground: (BOOL) bPause
```

앱이 포그라운드 상태로 전환될 때 플레이어를 일시정지 상태로 유지할지 설정합니다.

- 파라미터
  - `bPause`
    - YES: 포그라운드 전환 시 일시정지 상태 유지 (앱에서 직접 playWithError: 호출 필요)
    - NO (기본값): 포그라운드 전환 시 자동 재생

```
(void) setDisableZoomOut: (BOOL) bDisable
```

줌 기능에서 축소(zoom out) 동작을 비활성화합니다.

- 파라미터
  - `bDisable`: 축소 동작 활성화 여부 (YES: 비활성화, NO (기본값): 활성화)

```
(void) setDecoder: (bool) bHW
```

사용할 코덱을 설정합니다.

- 파라미터
  - `bHW`: 코덱 유형 (YES (기본값): 하드웨어 코덱, NO: 소프트웨어 코덱)

```
(void) setAIRate: (bool) bAIRate
```

AI배속 사용 여부를 설정합니다.

- 파라미터
  - `bAIRate`: AI배속 사용 여부 (YES (기본값): AI배속, NO: 일반 배속)

### Property Details

| 속성 | 설명 |
| --- | --- |
| **`(id<KollusPlayerDelegate>) delegate`**   `[read, write, nonatomic, weak]` | 플레이어 관련 델리게이트 |
| **`(id<KollusPlayerDRMDelegate>) DRMDelegate`**   `[read, write, nonatomic, weak]` | DRM 정보 관련 델리게이트 |
| **`(id<KollusPlayerLMSDelegate>) LMSDelegate`**   `[read, write, nonatomic, weak]` | LMS 정보 관련 델리게이트 |
| **`(id<KollusPlayerBookmarkDelegate>) bookmarkDelegate`**   `[read, write, nonatomic, weak]` | 북마크 관련 델리게이트 |
| **`(KollusStorage*) storage`**   `[read, write, nonatomic, weak]` | KollusStorage 포인터 |
| **`(NSString*) contentURL`**   `[read, write, nonatomic, copy]` | 재생할 콘텐츠 URL (Stream Play) |
| **`(NSString*) mediaContentKey`**   `[read, write, nonatomic, assign]` | 재생할 콘텐츠의 미디어 콘텐츠 키 (Local Play) |
| **`(KollusContent*) content`**   `[read, nonatomic, weak]` | 사용 중인 콘텐츠 정보 |
| **`(BOOL) AIRateEnable`**   `[read, write, nonatomic, unsafe_unretained]` | AI배속 지원 여부 |
| **`(NSTimeInterval) currentPlaybackTime`**   `[read, write, nonatomic, unsafe_unretained]` | 콘텐츠 현재 시간 |
| **`(NSTimeInterval) liveDuration`**   `[read, nonatomic, unsafe_unretained]` | 라이브 타임쉬프트 재생 길이 |
| **`(float) currentPlaybackRate`**   `[read, write, nonatomic, unsafe_unretained]` | 콘텐츠 재생속도. 10배속까지 지원. 2배속 초과 시 품질 저하 및 오디오/비디오 싱크 문제가 발생할 수 있음. |
| **`(NSArray*) bookmarks`**   `[read, write, nonatomic, strong]` | 북마크 정보 배열 |
| **`(KollusPlayerContentMode) scalingMode`**   `[read, write, nonatomic, unsafe_unretained]` | 콘텐츠 출력 모드 |
| **`(CGRect) playerContentFrame`**   `[read, write, nonatomic, unsafe_unretained]` | 플레이어 화면 영역 |
| **`(KollusPlayerRepeatMode) repeatMode`**   `[read, write, nonatomic, unsafe_unretained]` | 전체 반복 모드 |
| **`(BOOL) screenConnectEnabled`**   `[read, nonatomic, unsafe_unretained]` | 화면 출력 허용 여부 |
| **`(BOOL) bookmarkModifyEnabled`**   `[read, nonatomic, unsafe_unretained]` | 북마크 수정 권한 여부 |
| **`(BOOL) debug`**   `[read, write, nonatomic, unsafe_unretained]` | 디버그 로그 출력 여부 |
| **`(BOOL) isPreparedToPlay`**   `[read, nonatomic, unsafe_unretained]` | 재생 준비 완료 여부 |
| **`(BOOL) isPlaying`**   `[read, nonatomic, unsafe_unretained]` | 재생 중 여부 |
| **`(BOOL) isBuffering`**   `[read, nonatomic, unsafe_unretained]` | 버퍼링 진행 여부 |
| **`(BOOL) isSeeking`**   `[read, nonatomic, unsafe_unretained]` | 탐색 중 여부 |
| **`(BOOL) isScrolling`**   `[read, nonatomic, unsafe_unretained]` | 화면 이동 중 여부 |
| **`(BOOL) isAudioOnly`**   `[read, nonatomic, unsafe_unretained]` | 오디오 콘텐츠 여부 |
| **`(BOOL) muteOnStart`**   `[read, nonatomic, unsafe_unretained]` | 시작 시 음소거 여부 |
| **`(CGSize) naturalSize`**   `[read, nonatomic, unsafe_unretained]` | 원본 콘텐츠 영상 크기 |
| **`(BOOL) isZoomedIn`**   `[read, nonatomic, unsafe_unretained]` | 확대(zoom in) 여부 |
| **`(KollusPlayerType) playerType`**   `[read, nonatomic, assign]` | 플레이어 타입 |
| **`(NSString*) customSkin`**   `[read, write, nonatomic, copy]` | 플레이어 스킨 정보 JSON |
| **`(KPSection*) playSection`**   `[read, write, nonatomic, assign]` | 미리보기 정보 |
| **`(NSInteger) nRepeatStartTime`**   `[read, nonatomic, unsafe_unretained]` | 반복 재생 시작 시간 |
| **`(NSInteger) nRepeatEndTime`**   `[read, nonatomic, unsafe_unretained]` | 반복 재생 종료 시간 |
| **`(NSInteger) nPlaybackLimitDuration`**   `[read, nonatomic, unsafe_unretained]` | 재생 제한 시간 |
| **`(NSString *) strPlaybackLimitMessage`**   `[read, nonatomic, copy]` | 재생 제한 안내 메시지 |
| **`(BOOL) audioBackgroundPlay`**   `[read, write, nonatomic, unsafe_unretained]` | 백그라운드 오디오 파일 재생 |
| **`(BOOL) lmsOffDownloadContent`**   `[read, write, nonatomic, unsafe_unretained]` | 다운로드 콘텐츠 LMS 비활성화 여부 |
| **`(NSUInteger) proxyPort`**   `[read, write, nonatomic, unsafe_unretained]` | 프록시 서버 포트 번호 |
| **`(BOOL) intro`**   `[read, nonatomic, unsafe_unretained]` | 인트로 여부 |
| **`(BOOL) seekable`**   `[read, nonatomic, unsafe_unretained]` | 탐색(Seek) 가능 여부 |
| **`(NSInteger) nSecSkip`**   `[read, nonatomic, unsafe_unretained]` | 인트로 건너뛰기 대기 시간 (sec) |
| **`(BOOL) isLive`**   `[read, nonatomic, unsafe_unretained]` | 라이브 여부 |
| **`(BOOL) disablePlayRate`**   `[read, nonatomic, unsafe_unretained]` | 배속 컨트롤 비활성화 여부 |
| **`(NSInteger) nSeekableEnd`**   `[read, nonatomic, unsafe_unretained]` | 탐색(Seek) 허용 종료 시점 (sec). `seekable`이 false일 때만 적용. -1: 탐색 불가 |
| **`(NSString*) strCaptionStyle`**   `[read, nonatomic, copy]` | Kollus Partner Portal에서 설정한 자막 스타일 (`"bg"`: 자막 배경 적용, 그 외: 사용자 정의 설정) |
| **`(BOOL) forceNScreen`**   `[read, nonatomic, unsafe_unretained]` | 이어보기 시작 시점을 사용자 확인 없이 자동 적용 여부 |
| **`(BOOL) ignoreZero`**   `[read, nonatomic, unsafe_unretained]` | 이어보기 위치가 기준 시간보다 짧아도 이어보기 활성화 |
| **`(BOOL) isThumbnailEnable`**   `[read, nonatomic, unsafe_unretained]` | 섬네일 사용 여부 |
| **`(BOOL) isThumbnailSync`**   `[read, nonatomic, unsafe_unretained]` | 섬네일 다운로드 방식 (`YES`: 동기, `NO`: 비동기) |
| **`(NSString*) fpsCertURL`**   `[read, write, nonatomic, copy]` | FairPlay 인증 URL |
| **`(NSString*) fpsDrmURL`**   `[read, write, nonatomic, copy]` | FairPlay DRM URL |
| **`(NSInteger) nOfflineBookmarkUse`**   `[read, nonatomic, unsafe_unretained]` | 오프라인 북마크 사용 여부. 다운로드 콘텐츠에만 적용 (0: 사용 안 함, 1: 사용) |
| **`(NSInteger) nOfflineBookmarkDownload`**   `[read, nonatomic, unsafe_unretained]` | 1: 인덱스만 다운로드, 2: 인덱스/북마크 모두 다운로드 |
| **`(NSInteger) nOfflineBookmarkReadOnly`**   `[read, nonatomic, unsafe_unretained]` | 오프라인 북마크 추가/삭제 사용 여부 (0 (기본값): 사용, 1: 사용 안 함) |
| **`(NSMutableDictionary*) chapterInfo`**   `[read, nonatomic, assign]` | 챕터 정보 목록 |
| **`(NSString*) strVideoWaterMark`**   `[read, nonatomic, copy]` | 비디오 워터마크에 표시할 문자열 |
| **`(NSInteger) nVideoWaterMarkAlpha`**   `[read, nonatomic, unsafe_unretained]` | 비디오 워터마크 투명도 |
| **`(NSInteger) nVideoWaterMarkFontSize`**   `[read, nonatomic, unsafe_unretained]` | 비디오 워터마크 폰트 크기 |
| **`(NSString*) strVideoWaterMarkFontColor`**   `[read, nonatomic, copy]` | 비디오 워터마크 텍스트 색상 |
| **`(NSInteger) nVideoWaterMarkShowTime`**   `[read, nonatomic, unsafe_unretained]` | 비디오 워터마크 표시 시간 |
| **`(NSInteger) nVideoWaterMarkHideTime`**   `[read, nonatomic, unsafe_unretained]` | 비디오 워터마크 숨김 시간 |
| **`(NSString*) extraDrmParam`**   `[read, write, nonatomic, copy]` | 동적 DRM 파라미터 |
| **`(NSMutableArray*) streamInfoList`**   `[read, nonatomic, assign]` | HLS ABR 정보 목록 |
| **`(KollusChat*) kollusChat`**   `[read, write, nonatomic, assign]` | 라이브 채팅 객체 |
| **`(NSInteger) nextEpisodeShowTime`**   `[read, nonatomic, unsafe_unretained]` | 다음 회차 재생 표시 시간 |
| **`(NSString*) nextEpisodeCallbackURL`**   `[read, nonatomic, copy]` | 다음 회차 재생 URL |
| **`(NSMutableDictionary*) nextEpisodeCallbackParams`**   `[read, nonatomic, assign]` | 다음 회차 재생 파라미터 |
| **`(BOOL) nextEpisodeShowButton`**   `[read, nonatomic, unsafe_unretained]` | 다음 회차 재생 버튼 표시 여부 |
| **`(NSString *) contentProviderKey`**   `[read, nonatomic, copy]` | 콘텐츠 제공자 키 |
| **`(NSString *) contentProviderName`**   `[read, nonatomic, copy]` | 콘텐츠 제공자 이름 |
| **`(BOOL) disableBackgroundAudio`**   `[read, nonatomic, unsafe_unretained]` | 백그라운드 오디오 재생 제한 여부 |
| **`(NSInteger) maxPlaybackRate`**   `[read, nonatomic, unsafe_unretained]` | 콘텐츠 재생속도 최댓값 |
| **`(NSMutableArray*) listSubTitle`**   `[read, nonatomic, assign]` | 자막 파일 목록 |
| **`(NSMutableArray*) listSubTitleSub`**   `[read, nonatomic, assign]` | 서브 자막 파일 목록 |
