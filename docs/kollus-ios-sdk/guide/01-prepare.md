<!-- source: https://docs.kollus.com/dev-guide/kollus-mobile-app/sdk/ios/guide/prepare/ -->
<!-- 수집일: 2026-06-10 -->

# 1. 다운로드 준비

SDK 초기화 및 인증, 시작 메서드(`start`) 선택, 백그라운드 다운로드 설정, 디바이스 가용 용량 체크 등 콘텐츠 다운로드를 위한 준비 단계에 대해 설명합니다.

이 문서의 모든 예제 코드는 공식 샘플 앱인 `kollus_player_ios`를 바탕으로 작성되었습니다.

## `KollusStorage` 초기화

샘플 애플리케이션은 SDK 인증 및 관리를 위해 `StorageManager` 클래스를 구현하여 사용합니다. 개발 프로젝트 연동 시에도 이와 동일한 구조적 패턴 구성을 권장합니다.

```swift
import UIKit// import KollusSDK  (또는 Bridging Header에서 노출)class StorageManager: NSObject {    static let shared = StorageManager()    let storage: KollusStorage    override init() {        storage = KollusStorage()        super.init()        storage.applicationKey      = "SDK_KEY"  // 카테노이드에서 발급받은 SDK 키        storage.applicationBundleID = "com.yourcompany.yourapp" // 앱의 Bundle ID        // 인증 만료일 설정        let formatter = DateFormatter()        formatter.dateFormat = "yyyy/MM/dd"        formatter.calendar   = Calendar(identifier: .gregorian)        storage.applicationExpireDate = formatter.date(from: "2030/12/31")        // (선택 사항) 키체인 그룹: 다중 앱 또는 확장 앱과 데이터 공유 시 사용        // storage.keychainGroup = "com.yourcompany.shared"        // (선택 사항) 동적 DRM 파라미터 설정        // storage.extraDrmParam = "..."    }    public func validateSDK() {        do {            try storage.start()            storage.setBackgroundDownload(true)        } catch {            // (error as NSError).code 값으로 에러 상황 분류            print(error.localizedDescription)        }    }}
```

## 시작 메서드 선택

일반적인 환경에서는 `start()` 또는 `startWithCheck()` 메서드를 사용합니다. `playerID` 분실에 따른 복구가 필요한 경우 `startWithNewPlayerID()` 메서드를 사용할 수 있습니다.

| 메서드 | 동작 |
| --- | --- |
| **`start()`** | 일반적인 환경에서 엔진을 시작합니다. |
| **`start(withFirst: Bool)`** | 애플리케이션 설치 후 최초 실행 플래그를 명시적으로 전달하여 시작합니다. |
| **`startWithCheck()`** | 키체인에서 `playerID` 획득에 실패하는 경우 자동 생성 및 재시도를 수행합니다. 최초 실행 시 새로 생성하며, 이후 실행 단계에서 3회 이상 실패하면 에러를 반환합니다. |
| **`startWithNewPlayerID()`** | `playerID`를 강제로 새로 생성한 후 시스템 키체인에 등록하여 시작합니다. |

## 백그라운드 다운로드 활성화

```swift
storage.setBackgroundDownload(true)
```

이 옵션을 활성화하면 앱이 백그라운드 상태로 전환된 후에도 콘텐츠 다운로드가 지속됩니다. 다만 iOS 시스템 정책 및 네트워크 환경에 의해 일정 시간 후 프로세스가 일시 중단될 수 있으므로, 다운로드 완료 가능성을 높이려면 `URLSession`의 백그라운드 설정(Background Configuration) 패턴을 함께 검토하는 것을 권장합니다.

## 저장소 정보 조회

`KollusStorage` 인스턴스를 통해 지정된 로컬 저장 공간의 경로 및 상태 메타데이터를 직접 조회할 수 있습니다.

| 속성 | 반환 정보 및 설명 |
| --- | --- |
| **`storage.storagePath`** | SDK가 사용하는 저장 폴더 경로 (`NSString`) |
| **`storage.storageSize`** | 다운로드 콘텐츠의 총 용량 (bytes) |
| **`storage.cacheDataSize`** | 스트리밍 캐시 데이터의 총 용량 (bytes) |
| **`storage.applicationDeviceID`** | 디바이스 ID |
| **`storage.applicationVersion`** | Kollus SDK 버전 |
| **`storage.appUserAgent`** | SDK 내부 통신 시 시스템 헤더의 User-Agent 정보 |
| **`storage.deviceType`** | 디바이스 유형 (`kp-mobile`: 모바일, `kp-tablet`: 태블릿) |

## 스토리지 델리게이트 등록

```swift
storage.delegate = self
```

`KollusStorageDelegate` 프로토콜에 대한 설명은 [8. 다운로드 이벤트/콜백](/dev-guide/kollus-mobile-app/sdk/ios/guide/event/) 문서를 참고하세요.

## 디바이스 가용 용량 확인

다운로드 시작 전 디바이스 가용 용량이 **콘텐츠 파일 크기와 최소 여유 공간(예: 150MB)의 합산 값** 이상인지 확인합니다.

```swift
let free = DiskStatus.freeDiskSpaceInBytes
```

## 콘텐츠 다운로드 URL과 보안 주의사항

다운로드 대상 URL은 일반적으로 `https://v.kr.kollus.com/s?jwt=...`와 같은 형태의 일회성(One-time) URL 구조를 가집니다.

- 서버 간 연동 필수: JWT 발급 로직에는 보안 키가 포함되므로 반드시 고객사의 백엔드 서버에서 수행해야 합니다. 보안 취약점이 발생할 수 있으므로 모바일 앱 클라이언트가 JWT를 직접 생성해서는 안 됩니다.
- SDK 처리 방식: 모바일 앱은 고객사 서버로부터 전달받은 URL을 변형 없이 그대로 SDK의 loadContentURL(_:) 메서드에 전달하여 사용합니다. 자세한 내용은 3. 콘텐츠 다운로드 문서를 참고하세요.
