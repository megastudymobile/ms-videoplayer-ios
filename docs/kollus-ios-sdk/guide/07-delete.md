<!-- source: https://docs.kollus.com/dev-guide/kollus-mobile-app/sdk/ios/guide/delete/ -->
<!-- 수집일: 2026-06-10 -->

# 7. 다운로드 콘텐츠 삭제

오프라인 저장소에 보관된 다운로드 콘텐츠 파일 및 스트리밍 캐시 데이터를 안전하게 삭제하고 디스크 공간을 확보하는 제어 방법을 설명합니다.

이 문서의 모든 예제 코드는 공식 샘플 앱인 `kollus_player_ios`를 바탕으로 작성되었습니다.

## 단일 콘텐츠 삭제

`removeContent` 메서드를 사용하여 메모리 버퍼와 로컬 디스크에 저장된 콘텐츠 파일을 동시에 정리합니다.

```swift
func removeContent(mediaContentsKey: String) {    do {        try storage.removeContent(mediaContentsKey)    } catch {        print(error.localizedDescription)    }}
```

## 다운로드 콘텐츠 전체 삭제

전체 목록 조회를 통해 확보된 모든 다운로드 콘텐츠 객체를 순회하며 `removeContent` 프로세스를 연속 실행합니다. 공식 샘플 앱은 테스트 편의를 위해 샘플 콘텐츠(`.sample`) 속성을 가진 객체는 보존하고 나머지 다운로드 파일만 삭제합니다.

```swift
func removeAllDownloadContents() {    for content in storage.contents() as! [KollusContent] {        if content.contentType == .sample {            continue   // 샘플 콘텐츠는 보존합니다.        }        removeContent(mediaContentsKey: content.mediaContentKey)    }}
```

## 스트리밍 캐시 삭제

다운로드된 파일이 아닌, 스트리밍 재생(온라인 환경) 중에 디바이스 내부에 임시로 누적된 캐시 데이터만 정리합니다.

`storage.cacheDataSize` 속성을 참조하면 현재까지 쌓인 스트리밍 캐시 총 용량을 사전에 계산할 수 있습니다. 이를 활용해 설정 화면 등에 캐시 크기를 사용자에게 보여주는 UI를 구현할 수 있습니다.

```swift
func deleteCacheDatas() {    try? storage.removeCache()}
```

## 만료 콘텐츠 자동 정리

SDK가 DRM 콜백 `kind: 2, kind: 3`의 응답으로 백그라운드 환경에서 미디어 파일을 자동으로 삭제하는 케이스가 존재합니다.

강제 삭제 신호가 감지되었을 때, SDK는 이미 로컬 파일을 지운 상태입니다. SDK가 파일을 먼저 삭제한 후 앱에 사후 통지하는 구조이므로, 앱 레이어에서는 별도의 삭제 API를 호출할 필요 없이 주입된 델리게이트(`kollusStorage(_:request:json:error:)`) 콜백 내에서 응답 프로퍼티를 분석하여 **UI 목록만 새로고침(Refresh)**하면 됩니다.

## 디바이스 저장소 부족 시 예외 처리

디바이스의 디스크 잔여 용량이 부족할 때, SDK가 임의로 다른 완료 파일을 강제 정리하거나 스스로 공간을 확보해 주지는 않습니다. 다운로드 시작 전에 용량을 체크하여 사용자 액션을 유도하는 방어 코드 패턴을 권장합니다.

- 사전 용량 제한 체크: 다운로드 시작 직전 DiskStatus.freeDiskSpaceInBytes와 콘텐츠 파일 크기를 비교하여, 공간이 부족할 경우 다운로드를 반려하고 "디바이스 저장 공간 부족" 안내 다이얼로그를 표시합니다.
- 정리 옵션 제공: 사용자 편의를 위해 화면 내에 "최근 30일 동안 시청하지 않은 파일 정리" 또는 "시청 완료한 콘텐츠 일괄 삭제"와 같은 메뉴를 제공하는 것이 좋습니다.
