# Kollus iOS SDK Reference Notes

Author: JunyoungJung
Date: 2026-05-15
Source checked: 2026-05-15

## 범위

이 문서는 Kollus 공식 문서를 `videoplayer-ios-ms`의 `VideoPlayerEngineKollus` 구현 관점으로 정리한 내부 참고 문서다.

SDK embedded 구현의 1차 근거:

- [Kollus 모바일 앱 연동 (URL Scheme)](https://docs.kollus.com/dev-guide/vod/kollus-mobile-app/scheme-option/)
- [Kollus iOS SDK 다운로드](https://docs.kollus.com/dev-guide/vod/kollus-mobile-app/sdk/ios/download/)
- [Kollus 모바일 앱 SDK iOS 개발 가이드](https://docs.kollus.com/dev-guide/vod/kollus-mobile-app/sdk/ios/guide/)
- [Kollus iOS SDK Xcode 설정 가이드](https://docs.kollus.com/dev-guide/vod/kollus-mobile-app/sdk/ios/guide/xcode-setting/)
- [Kollus iOS SDK API 레퍼런스](https://docs.kollus.com/dev-guide/vod/kollus-mobile-app/sdk/ios/api-reference/)
- [Kollus iOS SDK 릴리즈 노트](https://docs.kollus.com/dev-guide/vod/kollus-mobile-app/sdk/ios/release-note/)

서버 정책과 SDK 동작을 같이 검증해야 하는 문서:

- [플레이어 호출](https://docs.kollus.com/dev-guide/vod/player/call-player/)
- [재생 URL 생성 (JWT)](https://docs.kollus.com/dev-guide/vod/player/jwt/)
- [통합 JWT 규격](https://docs.kollus.com/dev-guide/vod/player/jwt/standard/)
- [플레이 콜백](https://docs.kollus.com/dev-guide/vod/player-callback/play-callback/)
- [DRM 다운로드 콜백](https://docs.kollus.com/dev-guide/vod/player-callback/drm-callback/)
- [LMS 콜백](https://docs.kollus.com/dev-guide/vod/player-callback/lms-callback/)
- [다음 회차 콜백](https://docs.kollus.com/dev-guide/vod/player-callback/next-episode-callback/)
- [북마크 연동](https://docs.kollus.com/dev-guide/vod/player/bookmark/)
- [주요 에러 코드](https://docs.kollus.com/dev-guide/troubleshooting/error-code/)

이 repo에서 우선해야 하는 통합 방식은 앱 외부 `kollus://` 호출이 아니라 `VideoPlayerEngineKollus` product를 통한 SDK embedded 방식이다. URL Scheme은 웹/외부 앱에서 Kollus 모바일 앱을 실행할 때의 규격으로만 참고한다.

## 통합 모델

### 공식 SDK의 두 축

| 공식 구성 요소 | 역할 | 이 repo의 대응 |
| --- | --- | --- |
| `KollusStorage` | SDK 인증, 다운로드 콘텐츠 관리, 캐시/DRM/LMS 처리 | `KollusSessionBootstrapper`, `KollusStorageAdapter`, `KollusDownloadCenter` |
| `KollusPlayerView` | 재생 뷰, 재생 제어, 북마크/자막/DRM/LMS delegate 연결 | `KollusPlayerAdapter`, `KollusDelegateBridge` |

공식 가이드는 `KollusPlayerView`를 `UIView` 하위 뷰로 붙이는 방식을 전제로 한다. 이 repo에서는 host 앱이 SDK view를 직접 알지 않도록 `PlayerRenderSurface`와 `KollusPlayerAdapter.attach(...)` 경계 뒤에 숨긴다.

### 권장 진입점

```swift
let environment = KollusEnvironment(...)
let factory = KollusPlayerModuleFactory(
    environment: environment,
    observer: observer,
    diagnostics: diagnostics
)

let module = await factory.makeModule()
let downloads = factory.downloads
```

- `KollusEnvironment`는 application key, bundle ID, expire date, storage/cache/network, DRM, chat, diagnostics 값을 한 번에 묶는다.
- `KollusPlayerModuleFactory`는 단일 `KollusSessionBootstrapper`와 단일 `KollusDownloadCenter`를 만들고 모든 `makeModule()` 호출에서 공유한다.
- SmartLearning 같은 host 앱은 `KollusSDKBinary`를 직접 import하지 않는다.

## URL Scheme 요약

`kollus://` URL Scheme은 Kollus 모바일 앱을 실행하기 위한 외부 연동 규격이다. 모든 파라미터 값은 percent-encoding이 필요하다.

| 동작 | Scheme | 주요 파라미터 | 메모 |
| --- | --- | --- | --- |
| 즉시 재생 | `kollus://path` | `url` | 재생 URL을 전달한다. |
| 다운로드 | `kollus://download` | `url`, `folder` | `url`은 여러 개 전달 가능하다. `folder`는 앱 내부 가상 폴더다. |
| 다운로드 콘텐츠 재생 | `kollus://download_play` | `url` | 로컬에 없는 콘텐츠면 호출이 무시된다. |
| 다운로드 목록 표시 | `kollus://list` | `folder` | 미지정 시 최상위 목록을 표시한다. |

`videoplayer-ios-ms` 내부 구현에는 URL Scheme을 직접 넣지 않는다. SDK embedded 경로에서는 `PlaybackSource.url` 또는 `.kollus(mediaContentKey:)`를 통해 모듈로 진입시킨다.

## Xcode / SwiftPM 설정

공식 Xcode 설정 가이드는 다음 build setting과 link dependency를 요구한다.

| 항목 | 공식 요구 | 이 repo 상태 |
| --- | --- | --- |
| Other Linker Flags | `-lz`, `-lc++` | `Package.swift`의 `VideoPlayerEngineKollus` linker settings에서 `z`, `c++` 연결 |
| Swift standard libraries | Always Embed Swift Standard Libraries = YES | 앱 target 설정 영역. SPM package 자체에서는 직접 설정하지 않음 |
| Bitcode | Enable Bitcode = NO | 최신 Xcode/iOS에서는 bitcode가 사실상 제거되었지만, legacy target 확인 시 참고 |
| SDK binary | `libKollusSDK.a` | `Binaries/KollusSDK.xcframework` binary target |
| System libraries | SQLite, iconv | `Package.swift`에서 `sqlite3`, `iconv` 연결 |
| System frameworks | UIKit, Foundation, AVFoundation, CoreMedia, QuartzCore, AudioToolbox, Security, SystemConfiguration, MediaPlayer, CoreGraphics | `Package.swift`에서 iOS linker settings로 연결. Foundation은 기본 SDK 영역 |

관련 운영 절차는 [Kollus SDK Packaging](./kollus-sdk-packaging.md)을 따른다. `Vendor/`와 `Binaries/`를 직접 수정하지 않고 rebuild script로 재생성한다.

## SDK 버전 / 릴리즈 노트 확인

SDK drop을 교체하거나 `Vendor/KollusSDK`를 갱신할 때는 `SDK 다운로드`와 `릴리즈 노트`를 먼저 확인한다.

| 확인 항목 | 구현 영향 |
| --- | --- |
| 최신 SDK 버전 | `Vendor/KollusSDK`, `Binaries/KollusSDK.xcframework`, simulator stub 재생성 대상 확인 |
| 최소 iOS 버전 | `Package.swift`의 `platforms`와 host app deployment target 확인 |
| Added APIs | `KollusPlayerView`, `KollusStorage`, `KollusContent` snapshot/adapter 반영 여부 확인 |
| Fixed / behavior change | callback error 처리, background/foreground, HLS/DRM/download 동작 회귀 확인 |
| QoE / action stats / network event | diagnostics sink 또는 observer로 host에 노출할지 판단 |

현재 문서 확인 기준으로 iOS SDK `2.3.35`에는 서버 설정 기반 `maxPlaybackRate`가 추가되어 있다. 배속 UI나 `PlayerFeaturePolicy.maxPlaybackRate`를 다룰 때 `KollusPlayerView.maxPlaybackRate` 반영 여부를 같이 확인해야 한다.

최근 릴리즈 중 구현 검토에 직접 영향을 주는 항목:

- `2.3.35`: `maxPlaybackRate` 추가.
- `2.3.33`: playback limit duration/message 추가.
- `2.3.32`: 콘텐츠 다운로드 이벤트 데이터 전송.
- `2.3.31`: chapter model과 `chapterInfo` 추가. `prepareToPlayWithError` 이후 참조해야 함.
- `2.3.25`: `setKollusPath(_:)` 추가. `startStorage()` 전에 호출해야 하고, 기존 설치 후 변경하면 다운로드 콘텐츠 접근이 깨질 수 있음.
- `2.3.21`: iOS SDK 최소 지원 버전 iOS 15.0.

## SDK 초기화 흐름

공식 가이드의 storage 인증 흐름은 다음 순서로 해석한다.

1. `KollusStorage` 인스턴스를 만든다.
2. application key, bundle ID, expire date를 설정한다.
3. 필요 시 storage path, cache size, network timeout/retry, background download를 설정한다.
4. `startStorage` 계열 API로 인증과 storage 초기화를 완료한다.
5. 이후에 다운로드, 캐시 삭제, 다운로드 목록 조회, player view 재생을 수행한다.

이 repo의 대응:

- `KollusEnvironment.validate(now:)`가 application key, bundle ID, expire date, cache size, storage path를 사전 검증한다.
- `KollusSessionBootstrapper`가 storage 초기화를 한 번 수행하고, 준비된 storage를 재사용한다.
- `KollusDownloadCenter`는 동일 storage 위에서 다운로드/삭제/캐시/DRM/LMS facade를 제공한다.

## 재생 흐름

### 스트리밍 재생

공식 흐름은 `KollusPlayerView(contentURL:)` 생성, view 부착, storage 연결, delegate 연결, `prepareToPlay`, `play` 순서다.

이 repo의 대응:

- `PlaybackSource.url`이 들어오면 `KollusPlayerAdapter`가 `KollusPlayerView(contentURL:)`를 만든다.
- `PlayerRenderSurface`가 있으면 SDK view를 surface의 `containerView`에 붙인다.
- `KollusDelegateBridge`를 `prepareToPlay` 전에 delegate로 연결한다.
- 준비/재생 결과는 `PlaybackState`와 `PlayerEvent`로 변환해 host에 전달한다.

### 다운로드 콘텐츠 재생

공식 흐름은 `KollusPlayerView(mediaContentKey:)` 생성, view 부착, storage 연결, delegate 연결, `prepareToPlay`, `play` 순서다.

이 repo의 대응:

- `PlaybackSource.kollus(mediaContentKey:)`가 들어오면 `KollusPlayerView(mediaContentKey:)`를 만든다.
- 다운로드 콘텐츠 목록/상태는 `KollusDownloadCenter.contents`와 `KollusContentSnapshot`으로 노출한다.

## 다운로드 / 오프라인 관리

공식 `KollusStorage` 주요 API와 repo 대응은 다음과 같다.

| 공식 API | 의미 | 이 repo의 대응 |
| --- | --- | --- |
| `loadContentURL:error:` | 다운로드 URL 분석 후 media content key 확보 | `KollusDownloadCenter.resolve(contentURL:)` |
| `checkContentURL:error:` | URL에 대응하는 로컬 다운로드 콘텐츠 확인 | `KollusDownloadCenter.check(contentURL:)` |
| `downloadContent:error:` | media content key로 다운로드 시작 | `KollusDownloadCenter.startDownload(mediaContentKey:)` |
| `removeContent:error:` | 다운로드 콘텐츠 삭제 | `KollusDownloadCenter.remove(mediaContentKey:)` |
| `downloadCancelContent:error:` | 다운로드 중지 | `KollusDownloadCenter.cancelDownload(mediaContentKey:)` |
| `removeCacheWithError:` | 스트리밍 캐시 삭제 | `KollusDownloadCenter.clearStreamingCache()` |
| `setNetworkTimeOut:retry:` | storage 네트워크 timeout/retry 설정 | `KollusEnvironment.storageNetworkTimeout`, `storageNetworkRetry` |
| `setCacheSize:` | 스트리밍 캐시 크기 설정 | `KollusEnvironment.cacheSizeMB` |
| `setBackgroundDownload:` | 백그라운드 다운로드 사용 여부 | `KollusEnvironment.backgroundDownload` |
| `contents` | 다운로드 콘텐츠 배열 조회 | `KollusContentSnapshot` 배열 |
| `sendStoredLms` | 미전송 LMS 데이터 전송 | `KollusDownloadCenter.sendStoredLMS()`와 `KollusObserver` |

storage path는 신규 설치 시점에만 안정적으로 고정해야 한다. 공식 문서상 기존 설치 후 path를 바꾸면 이전 다운로드 콘텐츠 접근이 깨질 수 있으므로, `KollusEnvironment.storagePath` 변경은 migration 설계 없이 수행하지 않는다.

### DRM 다운로드 콜백 경계

다운로드/오프라인 DRM 정책은 SDK API만으로 끝나지 않는다. 공식 `DRM 다운로드 콜백` 문서는 서버가 다음 세 시점의 권한을 JWT 응답으로 제어한다고 설명한다.

| 콜백 종류 | 의미 | 클라이언트 관찰 지점 |
| --- | --- | --- |
| `kind1` | 다운로드 승인 및 DRM 정책 할당 | `KollusStorageDelegate` DRM callback, `downloadContent` 결과 |
| `kind2` | 다운로드 완료 통보 | 다운로드 완료 callback, snapshot refresh |
| `kind3` | 오프라인 재생 권한 확인 | 다운로드 콘텐츠 재생 준비/재생 callback |

따라서 `KollusDownloadCenter`는 단순 다운로드 시작/삭제 facade만이 아니라, storage delegate의 DRM 응답과 LMS 결과를 host가 진단할 수 있는 경로를 유지해야 한다. callback 서버가 지연되거나 응답 타입이 틀리면 다운로드/오프라인 재생 자체가 차단될 수 있으므로, 운영 로그에는 request/response/error를 함께 남긴다.

## Delegate / 이벤트 매핑

공식 API reference는 4개 delegate 그룹을 제공한다.

| Delegate | 공식 역할 | 이 repo의 대응 |
| --- | --- | --- |
| `KollusPlayerDelegate` | prepare/play/pause/buffering/stop/position/scroll/zoom/해상도/배속/외부 출력/자막/thumbnail/mck/bitrate 등 재생 생명주기 이벤트 | `KollusEngineSignal` 23개 raw signal, 일부는 `PlayerEvent`로 승격 |
| `KollusPlayerBookmarkDelegate` | 재생 준비 과정에서 북마크 목록 로딩 결과 수신 | `PlayerEvent.bookmarksDidLoad` |
| `KollusPlayerDRMDelegate` | DRM callback 요청/응답 결과 수신 | `KollusObserver` |
| `KollusPlayerLMSDelegate` | LMS 전송 결과 수신 | `KollusObserver` |
| `KollusStorageDelegate` | 다운로드 상태 변화, 다운로드 DRM callback, storage LMS callback, 미전송 LMS 전송 결과 수신 | `KollusStorageBridge`, `KollusDownloadCenter.contents`, `KollusObserver` |

`KollusDelegateBridge`는 SDK delegate를 SDK 타입 바깥으로 직접 노출하지 않고 다음처럼 분배한다.

- 재생 raw signal: `KollusDiagnosticsSink.kollus(_:)`에 그대로 전달
- domain에 필요한 재생 이벤트: `PlayerEvent`로 변환
- DRM/LMS 운영 이벤트: `KollusObserver`로 전달
- 북마크 목록: 도메인 `Bookmark` 배열로 변환

### 구현 반영 상태 (2026-05-15)

| 공식 callback / property | repo 반영 |
| --- | --- |
| `prepare/play/pause/buffering/stop` delegate의 `error` | `KollusPlayerAdapter`가 실패 상태와 `PlayerEvent.didFail`로 변환 |
| `prepareToPlayWithMode:error:` | `.preparing` 전이 후 호출. 빠른 prepare callback이 `.preparing`에 덮이지 않도록 순서 고정 |
| `playWithError:` / `pauseWithError:` | 즉시 성공 반환만으로 `.playing`/`.paused` 전이하지 않고 SDK delegate callback을 최종 상태로 사용 |
| `KollusStorageDelegate` DRM callback | `KollusStorageBridge`를 통해 `KollusObserver.kollus(didResolveDRM:response:error:)`로 전달 |
| `KollusContent.contentType/fileSize/downloadSize/downloadProgress/downloaded/downloadedTime` | `KollusContentSnapshot` 값 타입으로 복사. 다운로드 진행률은 SDK 백분율(0~100) 유지 |

### 플레이 / LMS / 다음 회차 callback 경계

| 공식 문서 | 핵심 정책 | repo 적용 |
| --- | --- | --- |
| 플레이 콜백 | 재생 시작 전/준비 후 서버 승인. JWT에는 `client_user_id`가 필요. 오프라인 재생 제어는 DRM 다운로드 콜백 담당. | `KollusPlayerDelegate` error와 `PlayerEvent.didFail` 매핑에서 서버 거절을 누락하지 않는다. |
| LMS 콜백 | 재생 중 주기/이벤트 단위로 LMS 데이터를 비동기 전송. 장애 시 클라이언트에 임시 저장 후 재전송. | `KollusObserver.kollus(didPostLMS:)`, `sendStoredLMS()`, `kollusStorage(didCompleteStoredLMS:)`를 운영 로그와 연결한다. |
| 다음 회차 콜백 | JWT `next_episode: true`일 때 서버가 다음 콘텐츠 정보를 제공. 오프라인 재생은 서버 콜백 연동이 불가능. | `NextEpisodeInfo`는 스트리밍에서만 신뢰한다. 다운로드 콘텐츠에서는 별도 host 정책으로 처리한다. |

LMS 데이터는 동일 세션에서 여러 번 도착할 수 있다. host는 `client_user_id`와 `start_at` 조합을 기준으로 최신 값을 확정해야 한다. 이 패키지는 LMS payload를 해석하지 않고 observer로 전달하는 경계만 유지한다.

### JWT / 호출 정책 경계

SDK embedded 방식에서도 재생 URL 또는 media content key가 서버 정책으로 생성된 결과라는 점은 동일하다. host/server가 JWT를 만들 때 설정한 옵션이 SDK 동작을 바꿀 수 있다.

| JWT / 호출 옵션 | 영향 |
| --- | --- |
| `cuid` / `client_user_id` | 중복 재생, 북마크, 이어보기, callback 식별 기준 |
| `expt` | 재생 요청 URL 만료 기준 |
| `next_episode` | 다음 회차 callback / SDK next episode metadata 노출 조건 |
| `seek`, `seekable_end`, `play_section` | host의 seek UI와 `PlaybackCommand.seek` 허용 정책에 영향 |
| `disable_playrate`, `maxPlaybackRate` | 배속 UI 및 `PlayerFeaturePolicy.maxPlaybackRate`와 동기화 필요 |
| `subtitle_policy` | SDK subtitle list/filter/노출 상태에 영향 |
| `bookmark` | 북마크 버튼/연동 가능 여부에 영향 |

server-generated 정책과 client policy가 다르면 SDK callback error 또는 기능 미노출로 나타날 수 있다. 클라이언트 구현 문제로 단정하기 전에 JWT payload와 채널 설정을 같이 확인한다.

## API 표면별 구현 메모

### `KollusPlayerView`

주요 method 그룹:

- 초기화: content URL 또는 media content key 기반 생성
- playback: prepare, play, pause, stop
- view control: scroll, zoom, zoom stop, video position, zoom value
- bookmark: add/remove/current bookmarks
- streaming option: network timeout, buffering ratio, bandwidth 변경
- subtitle: main/sub subtitle file 선택
- policy: foreground pause, zoom-out disable, decoder 선택, AI 배속

주요 property 그룹:

- delegate/storage/content 식별자
- playback state: current time, rate, prepared/playing/buffering/seeking
- display state: scaling mode, content frame, natural size, zoom state, external output
- content policy: seekable, max playback rate, background audio, playback limit
- DRM/FPS: certificate URL, DRM URL, extra DRM parameter
- chapter/subtitle/bookmark/chat/next episode metadata

이 repo는 모든 property를 public API로 그대로 열지 않는다. host가 실제로 사용하는 기능은 domain command, `PlayerEvent`, `KollusContentSnapshot`, diagnostics sink 중 하나로만 승격한다.

### `KollusContent`

주요 데이터:

- 강의/콘텐츠 메타: company, title, course, teacher, thumbnail, synopsis
- 식별자: media content key, content index
- DRM 상태: check date, expire date, expire count/time, expired 여부
- playback/download 상태: duration, last position, file size, download size/progress, downloaded 여부

이 repo의 `KollusContentSnapshot`은 host UI가 필요한 메타/DRM/download 상태만 값타입으로 복사한다.

### Chapter / Subtitle / Bookmark / Chat / Utils

| 공식 타입 | 의미 | repo 적용 |
| --- | --- | --- |
| `Chapter`, `ChapterDict` | 챕터 위치/언어별 목록 | `chapterInfo` raw metadata 또는 diagnostics로 관찰 가능 |
| `KPSection` | preview 재생 구간 | `playSection` 기반 preview/limit 정책 검토 시 참고 |
| `SubTitleInfo` | 자막 이름, URL, 언어, AI 자막 여부 | `listSubTitle`, `listSubTitleSub`, subtitle selection 경계에서 참고 |
| `KollusBookmark` | position/time/title/value/kind | domain `Bookmark`로 변환 |
| `KollusChat` | live chat URL, room, user profile | `KollusLiveChatProfile` |
| `LogUtil`, `UtilDelegate` | SDK 로그 수신 | 필요 시 `KollusDiagnosticsSink` 또는 별도 logger bridge로 연결 |

## 에러 코드 / 운영 진단

공식 `주요 에러 코드` 문서는 보안 플레이어, HTML5 agent, callback HTTP/curl 계열 에러를 분류한다. iOS SDK callback에서 내려오는 `Error`를 `PlayerError.engineError` 문자열로만 축약하면 원인 분리가 어려워진다.

진단 로그에 남길 최소 정보:

- SDK callback 이름 (`prepare`, `play`, `pause`, `buffering`, `download`, `DRM`, `LMS` 등)
- raw `NSError.domain`, `code`, `localizedDescription`
- playback source 종류 (`url`, `mediaContentKey`)
- 현재 `PlaybackState.Status`
- DRM/LMS/download callback request/response 식별값
- network timeout/retry/cache/backgroundDownload 환경값

사용자 노출 메시지는 host 앱에서 결정한다. 이 패키지는 raw error를 diagnostics/observer로 보존하고, domain state에는 실패 상태와 최소 메시지를 전달한다.

## 구현 시 주의

- `prepareToPlayWithMode:error:`와 `playWithError:`는 즉시 반환값만으로 최종 성공을 판단하지 않는다. 공식 delegate callback을 통해 최종 상태를 확인해야 한다.
- bookmark delegate는 재생 준비 전에 연결해야 초기 북마크 목록을 놓치지 않는다.
- buffering callback에서 SDK가 시스템 일시정지 후 buffering 해제 상태를 알릴 수 있으므로, 자동 재개 정책은 host UX와 함께 정해야 한다.
- FairPlay 사용 시 `fpsCertURL`, `fpsDrmURL`, `extraDrmParam` 주입 경로를 `KollusDRMConfiguration`으로 통일한다.
- 다운로드/캐시/storage API는 storage 인증 완료 이후에만 호출한다.
- 외부 출력, device lock, bitrate/height, caption raw callback은 domain event와 diagnostics event를 구분해서 처리한다.
- 공식 API가 Objective-C pointer와 mutable collection을 많이 노출하므로, public Swift API로 내보낼 때는 값타입 snapshot으로 복사한다.
- SDK 릴리즈 노트에 새 property/API가 추가되면 `KollusContentSnapshot`, `KollusEngineSignal`, capability protocol 중 어디로 승격할지 먼저 정한다.
- JWT/채널/callback 서버 정책이 SDK 동작을 바꾸므로, 재생 실패를 클라이언트 코드만으로 판단하지 않는다.
- 다음 회차 콜백은 스트리밍 서버 연동 기능이다. 다운로드 콘텐츠에서는 `nextEpisodeCallbackURL` 기반 자동 전환을 기대하지 않는다.
- LMS는 재전송이 가능하므로 동일 세션의 중복 이벤트를 host 저장소에서 idempotent하게 처리해야 한다.

## 관련 로컬 문서

- [Kollus SDK Packaging](./kollus-sdk-packaging.md)
- [README - Kollus SDK 운영 규칙](../README.md#kollus-sdk-운영-규칙)
