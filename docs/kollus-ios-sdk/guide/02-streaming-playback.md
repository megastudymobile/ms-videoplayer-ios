<!-- source: https://docs.kollus.com/dev-guide/kollus-mobile-app/sdk/ios/guide/streaming-playback/ -->
<!-- 수집일: 2026-06-10 -->

# 2. 스트리밍 재생

JWT URL을 사용하여 `KollusPlayerView`를 생성하고 콘텐츠를 디바이스에 직접 실시간 스트리밍 재생하는 방법을 설명합니다. 로컬에 다운로드된 콘텐츠 재생과 달리, 스트리밍 시에는 매 재생 시점마다 고객사 서버에서 새로 발급받은 일회성(One-time) URL을 사용합니다.

이 문서의 모든 예제 코드는 공식 샘플 앱인 `kollus_player_ios`를 바탕으로 작성되었습니다.

## 콘텐츠 전달 방식

Kollus 서비스는 채널 설정에 따라 세 가지 전달 방식 중 하나로 콘텐츠를 제공합니다. 애플리케이션 클라이언트 레이어에서는 동일한 JWT URL을 전달받아 `KollusPlayerView(contentURL:)` 인스턴스를 빌드하므로 별도의 코드 분기를 구현하지 않아도 됩니다.

다만, 전달 방식에 따라 가변 비트레이트(ABR) 작동 방식이나 DRM 검증 및 라이선스 발급 흐름, AirPlay 호환성 정책이 달라지므로 인프라 채널 구성을 파악하고 있으면 디버깅과 최적화에 도움이 됩니다.

| 전달 방식 | 기본값 | 설명 | 채널 설정 |
| --- | --- | --- | --- |
| **MP4 Progressive Download** | ◯ | 단일 MP4 파일을 실시간으로 내려받으며 동시 재생합니다. 가변 비트레이트(ABR)를 지원하지 않는 단일 품질 방식입니다. | 별도 설정 없음 (기본 채널) |
| **HLS 스트리밍** | - | 매니페스트(`.m3u8`)와 세그먼트 파일로 구성됩니다. iOS AVKit 시스템에 최적화되어 있으며 네트워크 대역폭 변화에 맞춰 실시간으로 품질이 자동 전환(ABR)됩니다. | 콘솔 채널 설정 내 HLS 출력 활성화 |
| **Multi-DRM (FairPlay)** | - | HLS 미디어 구조에 FairPlay 보안 라이선스 발급 흐름이 결합된 형태입니다. 내부적으로 `PallyConFPSSDK` 컴포넌트가 연동되어 동작합니다. | 콘솔 채널 설정 내 DRM 정책 등록 |

> **TIP**
>
> 팁
>
> 애플리케이션 소스 코드에서는 `KollusPlayerView(contentURL: jwtUrl)` 생성자를 호출하는 것만으로 세 가지 방식을 모두 재생할 수 있습니다. 실제 스트리밍 전달 방식은 Kollus 서버 측에서 채널 설정에 따라 결정되어 클라이언트로 전달됩니다.

### 전달 방식 상세 비교

| 비교 영역 | MP4 Progressive Download | HLS 스트리밍 | Multi DRM |
| --- | --- | --- | --- |
| **ABR 옵션 제어** | 대역폭 설정 영향 없음 | 적용됨 (iOS AVKit 기본 정책 준수) | 적용됨 (iOS AVKit 기본 정책 준수) |
| **탐색(Seek) 동작** | HTTP Byte-Range 요청 기반 제어 | 세그먼트 단위의 위치 탐색 | 세그먼트 단위의 위치 탐색 |
| **추가 프레임워크 통합** | 외부 의존성 없음 | 외부 의존성 없음 | `PallyConFPSSDK.framework` 라이브러리 빌드 포함 필수 |
| **라이선스 발급 흐름** | 라이선스 연동 없음 | 라이선스 연동 없음 | FairPlay 인증서 및 SPC 데이터 추출 후 CKC 교환 단계 수행 |
| **AirPlay / 외부 출력** | 외부 화면 출력 허용 | 외부 화면 출력 허용 | 콘텐츠 DRM 정책에 따라 출력 차단 제어 연동 |

> **INFO**
>
> 일반적인 채널 운영 패턴
>
> 대부분의 고객사는 서비스 초기 단계에서 **MP4 Progressive** 방식으로 시작하여, 트래픽이 증가하거나 가변 비트레이트(ABR) 환경이 필요한 시점에 **HLS 스트리밍**으로 전환합니다. 이후 저작권 보호 및 DRM 보안이 필수적인 콘텐츠에 한해 **Multi DRM (FairPlay) 채널**을 추가로 분리하여 운영하는 패턴이 일반적입니다.

## 기본 스트리밍 재생

KollusPlayer SDK의 `KollusPlayerView`에 실시간으로 재생할 인프라 환경과 델리게이트 객체들을 매칭한 후, 프로젝트 UIView 계층에 추가하여 실시간 스트리밍 재생을 시작합니다.

```swift
class PlayerViewController: UIViewController {    var playerView: KollusPlayerView!    // 1. 데이터 소스 지정 (JWT URL)    func play(streamingURL: String) {        DispatchQueue.main.async { [weak self] in            self?.playerView = KollusPlayerView(contentURL: streamingURL)            DispatchQueue.global().async {                self?.initPlayerView()            }        }    }    func initPlayerView() {        // 2. 인스턴스 내부 환경 설정 및 전용 델리게이트 수신 객체 연결        playerView.debug          = false        playerView.storage        = StorageManager.shared.storage   // KollusStorage 연결        playerView.delegate       = self                            // KollusPlayerDelegate (재생 라이프사이클)        playerView.DRMDelegate    = self                            // KollusPlayerDRMDelegate (Multi DRM)        playerView.LMSDelegate    = self                            // KollusPlayerLMSDelegate (시청 통계)        playerView.bookmarkDelegate = self                          // KollusPlayerBookmarkDelegate (북마크 감지)        playerView.scalingMode    = .scaleAspectFit        playerView.proxyPort      = LICENSE_KEY_PROXY_PORT   // 라이선스 키 발급 시 전달받은 포트        // 3. UIView 계층에 추가        view.addSubview(playerView)        playerView.frame = view.bounds        // 4. 재생 준비        // prepareToPlayWithError: 사용 권장 (하단 [재생 준비 완료 검증] 섹션 참고)    }}
```

### `KollusPlayerView` 초기화 옵션

| 초기화 생성자 | 용도 |
| --- | --- |
| **`KollusPlayerView(contentURL: String)`** | 스트리밍 재생 (JWT URL) |
| **`KollusPlayerView(mediaContentKey: String)`** | 오프라인 재생 (다운로드된 콘텐츠) |

스트리밍/오프라인 모드는 인스턴스 생성 시점에 결정됩니다. 같은 인스턴스로 두 모드를 전환할 수 없으므로, 콘텐츠 변경 시에는 새 `KollusPlayerView`를 생성해 attach하는 패턴이 일반적입니다.

### proxyPort 지정

`playerView.proxyPort` 속성은 SDK가 내부 통신을 처리하기 위해 사용하는 포트입니다. 키 발급 시 함께 전달받은 프록시 포트 번호를 그대로 지정하세요. 임의의 값으로 설정하면 정상적인 스트리밍 재생이 이루어지지 않습니다.

## 재생 준비 완료 검증

`KollusPlayerView`의 재생 준비 상태 추적은 단순 `prepareToPlay` 호출 대신, 델리게이트 콜백 메서드인 `prepareToPlayWithError:`를 통해 처리하는 방식을 권장합니다. 단순 호출로는 플레이어 초기화 단계에서 유발되는 정밀한 내부 오류를 포착하기 어렵지만, `prepareToPlayWithError:` 방식을 사용하면 준비 완료 혹은 실패 시점에 구체적인 `NSError` 객체가 함께 수신되므로 구체적인 대응이 가능합니다.

```swift
func kollusPlayerView(_ playerView: KollusPlayerView,                      prepareToPlayWithError error: Error?) {    if let error = error {        // 초기화 실패 — 에러 코드에 따라 사용자 안내        let nsError = error as NSError        UIApplication.presentErrorViewController(            title: "재생 준비 실패 (\(nsError.code))",            errorDescription: nil,            errorReason: error.localizedDescription)        return    }    // 재생 준비 완료 — 제어 메서드를 연동하여 자동 재생을 실행하거나 사용자 입력을 대기합니다.}
```

## 플레이어 주요 속성

### 재생 제어

다음 속성들은 값을 직접 설정(`set`)하여 재생을 제어합니다.

| 속성 | 타입 | 설명 |
| --- | --- | --- |
| **`contentURL`** | **`NSString`** | 스트리밍 재생 URL (초기화 시 지정) |
| **`currentPlaybackTime`** | **`NSTimeInterval`** | 현재 재생 위치 (`set`으로 탐색 실행) |
| **`currentPlaybackRate`** | **`float`** | 배속 (1.0, 1.25, 1.5, 2.0 등) |
| **`scalingMode`** | **`KollusPlayerContentMode`** | 화면 출력 모드 |
| **`repeatMode`** | **`KollusPlayerRepeatMode`** | 재생 구간 반복 모드 |
| **`playerContentFrame`** | **`CGRect`** | 플레이어 화면 영역 |
| **`AIRateEnable`** | **`BOOL`** | AI배속 지원 여부 |

> **WARNING**
>
> 배속 제어 권장 정책
>
> 최대 10배속까지 설정 가능하지만, `currentPlaybackRate` 값이 **2.0**을 초과하면 오디오-비디오의 싱크가 어긋나는 현상이나 일시적인 품질 저하가 발생할 수 있습니다.

#### 탐색(Seek) 및 재생 제어 예시

```swift
// 탐색(Seek)playerView.currentPlaybackTime = 60.0   // 60초 시점으로 재생 위치 이동// 재생속도(배속)playerView.currentPlaybackRate = 1.5    // 1.5배속으로 재생// 구간 반복playerView.repeatMode = .all            // 전체 반복 (.none: 해제, .one: 단일 콘텐츠 반복)
```

### 상태 정보 조회

다음 속성들은 읽기 전용으로, 현재 플레이어 상태를 조회하는 데 사용합니다.

| 속성 | 설명 |
| --- | --- |
| **`isPreparedToPlay`** | 재생 준비 완료 여부 |
| **`isPlaying`** | 실시간 재생 중 여부 |
| **`isBuffering`** | 버퍼링 진행 중 여부 |
| **`isSeeking`** | 탐색(Seek) 중 여부 |
| **`isScrolling`** | 화면 이동(Scroll) 중 여부 |
| **`isAudioOnly`** | 오디오 전용 콘텐츠 여부 |
| **`naturalSize`** | 원본 영상 크기 (CGSize) |
| **`screenConnectEnabled`** | 외부 디스플레이 출력 허용 여부 |

## 플레이어 라이프사이클 제어

`KollusPlayerDelegate`를 통해 재생 라이프사이클 및 하드웨어 연동 런타임 이벤트 신호들을 수신하여 앱의 비즈니스 UI 로직과 연동합니다.

```swift
// 1. 재생 준비 완료func kollusPlayerView(_ playerView: KollusPlayerView,                      prepareToPlayWithError error: Error?) {    if let error = error {        // 준비 실패 처리        return    }    // 자동 재생 또는 사용자 입력 대기}// 2. 재생 시작func kollusPlayerView(_ playerView: KollusPlayerView,                      play userInteraction: Bool,                      error: Error?) {    // userInteraction == true  : 애플리케이션에서 play() 명령을 실행하여 재생    // userInteraction == false : SDK 내부에서 자동 재생 (예: 이어폰 탈착 후 자동 재개)}// 3. 일시정지func kollusPlayerView(_ playerView: KollusPlayerView,                      pause userInteraction: Bool,                      error: Error?) { }// 4. 버퍼링 상태 변화func kollusPlayerView(_ playerView: KollusPlayerView,                      buffering: Bool,                      prepared: Bool,                      error: Error?) {    // buffering == true  : 버퍼링 시작    // buffering == false : 버퍼링 해소}// 5. 정지func kollusPlayerView(_ playerView: KollusPlayerView,                      stop userInteraction: Bool,                      error: Error?) { }// 6. 탐색(Seek): 탐색 전/후 총 2회 호출func kollusPlayerView(_ playerView: KollusPlayerView,                      position: TimeInterval,                      error: Error?) {    // playerView.isSeeking 값으로 전/후 구간 구별}
```

> **WARNING**
>
> 버퍼링 이벤트 대응 시 예외 처리
>
> iOS 시스템 환경 특성상 `buffering: true` 통지 이벤트 신호가 수신되기 전, 일시정지(`pause`) 델리게이트 메서드가 먼저 호출되는 경우가 존재할 수 있습니다. 따라서 `buffering: false` 상태 신호가 수신되는 시점에 애플리케이션 메인 UI 제어권을 참조하여 명시적으로 재생 상태를 복원해야 안전합니다.

## DRM 콘텐츠 스트리밍

JWT URL 구조 내부에 유효한 DRM 정책이 포함되어 있는 경우, SDK가 자동으로 라이선스 파싱 및 핸드셰이킹 단계를 제어합니다.

- FairPlay (Multi DRM): PallyConFPSSDK 프레임워크 컴포넌트가 SDK와 통합되어 FairPlay 인증서 교환 및 SPC·CKC 라이선스 발급 흐름 전반을 대행합니다.
- Kollus DRM: 별도의 종속성 추가 구성 단계 없이 라이선스를 파싱 처리합니다.

DRM 관련 이벤트는 `KollusPlayerDRMDelegate`를 통해 전달됩니다. 세부적인 델리게이트 메서드 명세는 SDK 내부 헤더 파일의 인터페이스 선언부를 참고해 주세요.

## 플레이어 타입 분기 처리

공식 샘플 앱에서는 콘텐츠 URL 내부에 수신된 `hint` 메타데이터를 통해 최적의 플레이어 타입을 자동 지정합니다.

대부분의 일반적인 환경에서는 위와 같은 하드웨어 가용성 체크 분기 코드를 개발 레이어에서 매번 직접 조율할 필요가 없으며, SDK 내부의 자동 감지를 사용하는 것을 권장합니다.

```swift
let strPlayerType = checkPlayerType(streamingURL)switch strPlayerType {case "hw":     playerType = 0  // Kollus 자체 하드웨어 내장 디코더case "sw":     playerType = 1  // Kollus 자체 소프트웨어 디코더case "native": playerType = 2  // iOS AVPlayerdefault:       break}// playerType == 0 또는 1 → KollusPlayer 지정// playerType == 2 → Native AVPlayer 지정if playerType == 0 || playerType == 1 {    try self.playerView.prepareToPlay(withMode: .PlayerTypeKollus)} else if playerType == 2 {    try self.playerView.prepareToPlay(withMode: .PlayerTypeNative)}
```

## LMS(시청 통계) 데이터 연동

학습 관리 시스템(LMS)으로 시청 통계 전송이 필요한 콘텐츠는 SDK가 주기적으로 LMS 콜백을 호출합니다. 전송 상태 및 통계 처리 결과 피드백은 연결된 `KollusPlayerLMSDelegate` 콜백을 통해 처리됩니다.

오프라인 시청 시 전송에 실패한 LMS 데이터는 로컬 `KollusStorage` 저장 공간에 누적됩니다. 이후 네트워크 상태가 복구되는 시점에 명시적으로 `storage.sendStoredLms()` 메서드를 호출해 주면, 적체되어 있던 로컬 시청 통계 데이터가 LMS 서버로 일괄 전송됩니다. 자세한 내용은 [8. 다운로드 이벤트/콜백](/dev-guide/kollus-mobile-app/sdk/ios/guide/event/) 문서를 참고하세요.

## 백그라운드 재생

장시간 백그라운드 재생을 유지하려면, iOS 운영체제가 규정하는 미디어 백그라운드 실행 권한 구조가 선행 명시되어 있어야 합니다.

1. Info.plist의 UIBackgroundModes에 audio 옵션 추가
2. 애플리케이션 시작 시 하드웨어 오디오 세션을 재생 모드로 격상하는 코드 설정 `AVAudioSession.sharedInstance().setCategory(.playback, ...)`
3. 설정한 오디오 세션을 시스템 단에 최종 등록하여 활성화 `AVAudioSession.sharedInstance().setActive(true)`

> **INFO**
>
> 오디오 제어 주체
>
> `KollusPlayerView` 인스턴스 자체가 iOS 운영체제의 백그라운드 오디오 실행 권한을 획득해 주지는 않습니다. 따라서 위 3가지 하드웨어 오디오 세션 승인 및 활성화 처리를 직접 구현해야 백그라운드 오디오 출력이 무중단 상태로 유지됩니다.

## 라이브 콘텐츠 스트리밍

실시간 라이브 방송 스트리밍 세션 역시 일반적인 VOD 환경과 동일한 `contentURL` 형태로 인입됩니다.

- 라이브 식별 방법: 라이브인지 VOD인지에 대한 판별 처리는 수신된 JWT Payload 내 mc[].live 속성 필드의 존재 여부를 통해 파악할 수 있습니다.
- SDK 내부 동작: SDK가 라이브 데이터 구조임을 정상 식별하게 되면, 해당 방송 사양에 최적화된 타임시프트(Timeshift) 기능 제어 및 DVR 동작을 자동으로 수행합니다.

```swift
let liveDuration = playerView.liveDuration   // 타임시프트 가능 길이 (s)
```

## 리소스 해제

사용자가 재생 화면을 완전히 이탈하는 시점에는 실행 중이던 `KollusPlayerView` 객체의 리소스를 완전히 반환하고 뷰 계층에서 명시적으로 차단해야 합니다. 이 작업을 생략하는 경우 화면이 꺼진 이후에도 백그라운드 상태에서 오디오 출력이 계속되는 오류가 발생할 수 있습니다.

```swift
deinit {    playerView?.removeFromSuperview()    playerView = nil}
```
