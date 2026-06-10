<!-- source: https://docs.kollus.com/dev-guide/kollus-mobile-app/sdk/ios/guide/download-list/ -->
<!-- 수집일: 2026-06-10 -->

# 4. 다운로드 목록 관리

SDK 저장소에 등록된 콘텐츠 데이터를 상태별로 조회하고 관리하는 방법을 설명합니다. Android와 달리 iOS SDK는 로컬 DB 영속화 없이 SDK가 관리하는 데이터 소스를 가져와 앱 레이어에서 직접 필터링하여 진행 중/완료/최근 다운로드 UI 목록을 구성합니다.

이 문서의 모든 예제 코드는 공식 샘플 앱인 `kollus_player_ios`를 바탕으로 작성되었습니다.

## 전체 콘텐츠 목록 조회

```swift
func contents() -> [KollusContent] {    return storage.contents() as! [KollusContent]}
```

`storage.contents()` 메서드는 SDK가 관리하는 모든 `KollusContent` 객체(다운로드 진행 중/완료/실패/샘플 등)가 통합된 원본 배열을 반환합니다. 이 원본 배열을 받아 아래 예시들과 같이 용도별로 필터링해서 사용합니다.

## 다운로드 진행 중 콘텐츠 목록 조회

전체 목록에서 용량이 아직 가득 차지 않았고(`progress < 1`), 타입이 다운로드 중인 콘텐츠만 필터링하여 진행 중 목록을 구성합니다.

```swift
func getDownloadList() -> [KollusContent] {    let contentsList = contents()    return contentsList.filter { content in        let progress = CGFloat(content.downloadSize) / CGFloat(content.fileSize)        return (progress < 1 && content.contentType == .downloading)            || (progress < 1 && content.contentType == .adaptiveDownload)    }}
```

## 다운로드 완료 콘텐츠 목록 조회

전체 목록에서 일반 다운로드가 완료되었거나, Adaptive 다운로드 진행률이 100%인 콘텐츠만 필터링하여 완료 목록을 구성합니다.

```swift
func getCompletedList() -> [KollusContent] {    return contents().filter { c in        (c.contentType == .downloading && c.downloaded)            || (c.contentType == .adaptiveDownload && c.downloadProgress == 100)    }}
```

## 최근 다운로드 목록 조회 (7일 이내)

다운로드가 최종 완료된 콘텐츠 중, 완료 시점 일시가 현재 시각 기준으로 7일 이내인 콘텐츠만 추출합니다.

```swift
func getRecentlyAddedFileList() -> [KollusContent] {    let now = Date().toLocalTime()    return contents().filter { c in        guard (c.contentType == .downloading && c.downloaded)           || (c.contentType == .adaptiveDownload && c.downloadProgress == 100)        else { return false }        let downloadedDate = KollusUtil.integerToDate(int: c.downloadedTime)        return downloadedDate.daysBetween(date: now) <= 7    }}
```

`downloadedTime` 속성은 다운로드 완료 시점의 정수형 타임스탬프(epoch seconds)를 반환합니다. 공식 샘플 앱에 포함된 `KollusUtil.integerToDate(int:)` 메서드를 사용하여 쉽게 변환할 수 있습니다.

## 다운로드 상태 플래그 정의

콘텐츠 객체의 분류 및 상태를 판단할 때 참조하는 `KollusContentType` 사양입니다.

| 구분 | 설명 |
| --- | --- |
| **`.downloading`** | 일반 다운로드 콘텐츠 (진행 중/완료 상태 객체 모두 포함, `downloaded` 속성으로 분기) |
| **`.adaptiveDownload`** | Adaptive HLS 다운로드 콘텐츠 (`downloadProgress` 속성으로 분기) |
| **`.sample`** | 샘플 콘텐츠 (전체 삭제 시 보존 권장) |

### 다운로드 완료 판단 기준

다운로드 방식에 따라 완료 상태를 판단하는 기준이 다릅니다. 아래 규칙을 참고하여 진행 중/완료 상태를 분기합니다.

- 일반 다운로드 (`.downloading`): downloaded == true이면 완료
- Adaptive HLS 다운로드 (`.adaptiveDownload`): downloadProgress == 100이면 완료

## 목록 표시 및 커스텀 정렬

공식 샘플 앱은 사용자의 설정에 따라 콘텐츠 제목, 다운로드 완료 일시, 파일 용량 순으로 목록을 정렬하는 가이드 모델을 제공합니다.

```swift
list.sort {    if $0.fileType != $1.fileType {        return $0.fileType > $1.fileType   // 폴더가 일반 파일보다 항상 위로 가도록 정렬    }    switch PreferenceManager.sortOrder {   // 사용자 설정 정렬 기준에 따른 분기    case Sort.name.rawValue:        return $0.title < $1.title    case Sort.downloadedTime.rawValue:        return $0.downloadedTime > $1.downloadedTime    default:        return $0.fileSize > $1.fileSize    }}
```
