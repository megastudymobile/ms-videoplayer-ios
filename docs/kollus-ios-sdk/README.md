<!-- source: https://docs.kollus.com/dev-guide/kollus-mobile-app/sdk/ios/ -->
<!-- 수집일: 2026-06-10 -->

# Kollus iOS SDK 문서 (로컬 정리본)

[Kollus 모바일 앱 SDK iOS 공식 문서](https://docs.kollus.com/dev-guide/kollus-mobile-app/sdk/ios/)의 **구현 가이드**와 **API 레퍼런스**를 markdown으로 수집한 사본이다. 원본 기준 시점: 2026-06-10. 각 파일 상단 주석에 원본 URL이 있다.

> **WARNING**
>
> 자동 수집본이다. SDK 버전 변경 시 [원본 문서](https://docs.kollus.com/dev-guide/kollus-mobile-app/sdk/ios/)와 [릴리즈 노트](https://docs.kollus.com/dev-guide/kollus-mobile-app/sdk/ios/release-note/)를 우선 확인한다.

## 구현 가이드 (`guide/`)

| # | 문서 | 설명 |
| --- | --- | --- |
| 00 | [개요](guide/00-overview.md) | 구현 가이드 구성, SDK 키/인증 사전 확인, FairPlay DRM 연동 안내 |
| 01 | [다운로드 준비](guide/01-prepare.md) | 오프라인 다운로드를 위한 사전 설정 |
| 02 | [스트리밍 재생](guide/02-streaming-playback.md) | JWT URL 기반 실시간 스트리밍 재생 (MP4/HLS/FairPlay) |
| 03 | [콘텐츠 다운로드](guide/03-download.md) | 콘텐츠 다운로드 실행 |
| 04 | [다운로드 목록 관리](guide/04-download-list.md) | 다운로드 항목 조회/관리 |
| 05 | [오프라인 재생](guide/05-offline-playback.md) | 다운로드된 콘텐츠 로컬 재생 |
| 06 | [DRM 라이선스 갱신](guide/06-license-renewal.md) | FairPlay 라이선스 갱신 |
| 07 | [다운로드 콘텐츠 삭제](guide/07-delete.md) | 다운로드 항목 삭제 |
| 08 | [다운로드 이벤트/콜백](guide/08-event.md) | 다운로드 진행/완료/오류 콜백 |
| 09 | [다운로드 에러 코드](guide/09-error-code.md) | 다운로드 에러 코드 목록 |
| 10 | [안티 패턴](guide/10-anti-pattern.md) | 자주 하는 실수 |

## API 레퍼런스 (`api-reference/`)

| # | 문서 | 설명 |
| --- | --- | --- |
| 00 | [개요](api-reference/00-overview.md) | 핵심 클래스 / 기능 / 참조 목록 |
| 01 | [KollusPlayerView](api-reference/01-player-view.md) | 재생·화면 출력·북마크·이벤트를 제어하는 재생 엔진 |
| 02 | [Player Delegates](api-reference/02-player-delegates.md) | 재생 라이프사이클·북마크·DRM·LMS 콜백 델리게이트 |
| 03 | [KollusStorage](api-reference/03-kollus-storage.md) | 오프라인 콘텐츠 다운로드·삭제·조회 관리 |
| 04 | [KollusContent](api-reference/04-kollus-content.md) | 콘텐츠 URL·DRM·다운로드 상태 등 메타데이터 |
| 05 | [Chapter & Subtitle](api-reference/05-chapter-subtitle.md) | 챕터 정보 및 자막 파일 데이터 모델 |
| 06 | [KollusBookmark](api-reference/06-bookmark.md) | 북마크 정보 |
| 07 | [KollusChat](api-reference/07-chat.md) | 라이브 채팅 서버 연결 및 사용자 정보 |
| 08 | [Utils](api-reference/08-utils.md) | 로그 유틸리티 및 로그 수신 델리게이트 |

## URL Scheme 연동

| 문서 | 설명 |
| --- | --- |
| [Kollus 모바일 앱 연동 (URL Scheme)](scheme-option.md) | `kollus://` 커스텀 스킴 호출 규격 — 재생/다운로드/목록 표시 (SDK 미사용, 설치된 앱 직접 호출) |
