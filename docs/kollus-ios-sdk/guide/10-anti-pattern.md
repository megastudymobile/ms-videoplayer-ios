<!-- source: https://docs.kollus.com/dev-guide/kollus-mobile-app/sdk/ios/guide/anti-pattern/ -->
<!-- 수집일: 2026-06-10 -->

# 안티 패턴 (자주 하는 실수)

Kollus iOS SDK를 연동할 때 흔히 발생하는 잘못된 구현 사례(안티 패턴)와 올바른 해결 방법을 정리했습니다. 안정적인 서비스 구현을 위해 개발 전 아래 사항들을 반드시 확인하시기 바랍니다.

### 모바일 앱 내에서 JWT URL 직접 생성

> **WARNING**
>
> 안티 패턴
>
> 보안 키가 포함된 JWT 서명 로직을 모바일 클라이언트 앱(iOS) 소스 코드에 직접 구현하는 경우

- 문제점: 보안 키가 외부로 유출될 수 있어 심각한 보안 취약점이 발생합니다.
- 올바른 방법: JWT는 반드시 고객사의 서버에서 발급한 후, 모바일 앱에 전달하는 구조로 구현해야 합니다.

### `loadContentURL`과 `checkContentURL` 메서드 혼용

> **WARNING**
>
> 안티 패턴
>
> 신규 콘텐츠를 다운로드할 때 `loadContentURL(_:)` 대신 `checkContentURL(_:)` 메서드를 먼저 호출하는 경우

- 문제점: checkContentURL(_:)은 기존에 이미 등록된 다운로드 링크와의 매칭 여부만 확인합니다. 등록되지 않은 URL을 전달하면 에러(throw)만 발생하고 다운로드할 콘텐츠 정보가 등록되지 않습니다.
- 올바른 방법: 신규 콘텐츠를 다운로드하려면 반드시 loadContentURL(_:)을 먼저 호출하여 콘텐츠 정보를 등록해야 합니다.

### `downloadCancelContent` 메서드를 일시정지 목적으로 오용

> **WARNING**
>
> 안티 패턴
>
> 콘텐츠 다운로드를 일시정지하기 위해 `downloadCancelContent` 메서드를 호출하는 경우

- 문제점: downloadCancelContent는 다운로드를 취소하는 동작이므로, 다운로드 재개 시 처음부터 다시 전체 파일을 다운로드해야 합니다.
- 올바른 방법: 부분 재개(이어받기) 기능이 필요하다면 별도의 진행 상태 추적과 함께 SDK의 resume 동작을 직접 확인하세요.

### DRM 만료 콘텐츠 재생 시 파일 전체를 자동 재다운로드

> **WARNING**
>
> 안티 패턴
>
> DRM 라이선스가 만료되었을 때, 영상 파일 자체를 다시 다운로드하도록 구현하는 경우

- 문제점: 불필요한 네트워크 트래픽이 발생하고 사용자 다운로드 대기 시간이 길어집니다.
- 올바른 방법: 영상 파일 재다운로드 없이, updateDownloadDRMInfo 메서드를 호출하여 DRM 라이선스만 갱신하면 됩니다. 자세한 사항은 6. DRM 라이선스 갱신 문서를 참고하세요.

### `setBackgroundDownload(true)` 설정이 라이선스 갱신까지 백그라운드에서 수행한다고 가정

> **WARNING**
>
> 안티 패턴
>
> `setBackgroundDownload(true)` 옵션을 활성화하면 라이선스 갱신 프로세스까지 백그라운드에서 안정적으로 지속될 것이라 예상하고 구현하는 경우

- 문제점: 해당 옵션은 파일 다운로드를 백그라운드에서 유지하는 기능일 뿐, 라이선스 갱신 작업의 백그라운드 수행을 보장하지 않습니다.
- 올바른 방법: 라이선스 갱신은 앱이 포그라운드(활성 상태)로 진입하는 시점이나, 재생 직전에 동기(Sync) 방식으로 호출하는 것이 가장 안정적입니다.

### 플레이어 `start` 메서드 오용

> **WARNING**
>
> 안티 패턴
>
> 명확한 시나리오 없이 `startWithNewPlayerID()` 메서드를 호출하여 플레이어를 시작하는 경우

- 문제점: startWithNewPlayerID()는 플레이어 고유 ID(playerID)를 강제로 새로 생성합니다. 이로 인해 이전에 기존 ID로 다운로드해 두었던 다른 콘텐츠들과의 연결이 끊어질 수 있습니다.
- 올바른 방법: startWithNewPlayerID()는 디바이스 변경이나 ID 분실 등 명확한 복구 시나리오에서만 제한적으로 사용해야 합니다. 일반적인 상황에서는 start() 또는 startWithCheck()를 사용하는 것이 안전합니다.

### `Info.plist` 내 `applicationBundleID` 설정 불일치

> **WARNING**
>
> 안티 패턴
>
> `KollusStorage.applicationBundleID`에 설정한 값과 실제 iOS 앱 프로젝트의 `CFBundleIdentifier`(Bundle ID)가 다르게 입력된 경우

- 문제점: 인증 정보가 일치하지 않아 SDK 인증 및 초기화 단계에서 실패가 발생합니다.
- 올바른 방법: 두 식별자 값이 일치하는지 항상 확인해야 합니다. 만약 Bundle ID를 변경해야 하는 상황이라면, 영업 담당자 또는 기술 지원팀(tech_support@catenoid.net)으로 SDK 키 재발급을 요청하세요.

### `storage.contents()` API 호출 시 폴더 노드를 콘텐츠로 오인

> **WARNING**
>
> 안티 패턴
>
> `storage.contents()` 맵핑 데이터 중, 하위 요소를 포함하고 있는 폴더 노드를 단일 미디어 콘텐츠로 간주하고 접근하는 경우

- 문제점: 제공되는 샘플 앱은 KollusContent(directory:)를 통해 폴더 형태의 가상 노드를 함께 생성하여 표시합니다. 이를 일반 파일로 처리하려 하면 mediaContentKey가 nil이 반환되어 런타임 에러가 발생할 수 있습니다.
- 올바른 방법: 목록을 구성할 때 데이터의 속성을 확인하여 fileType == 1인 경우는 미디어 파일이 아닌 '폴더'로 인식하도록 분기 처리 로직을 구현해야 합니다.
