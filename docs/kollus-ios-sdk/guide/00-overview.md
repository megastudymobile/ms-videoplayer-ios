<!-- source: https://docs.kollus.com/dev-guide/kollus-mobile-app/sdk/ios/guide/ -->
<!-- 수집일: 2026-06-10 -->

# 구현 가이드

iOS 환경에서 Kollus SDK를 사용하여 DRM 콘텐츠를 디바이스에 다운로드하고, 네트워크 연결이 없는 환경에서도 안전하게 재생하기까지의 전체 프로세스를 다룹니다. 이 문서의 모든 예제 코드는 공식 샘플 앱인 `kollus_player_ios`를 바탕으로 작성되었습니다.

## 사전 확인 사항: SDK 키와 인증

Kollus SDK는 카테노이드에서 발급하는 **SDK 키(Key)**와 **만료일** 정보를 기반으로 인증을 수행합니다. 올바른 키를 발급받지 못했거나 유효 기간이 만료된 키를 사용하는 경우, SDK 초기화 및 시작(`start`) 단계에서 에러가 발생하며 동작이 실패합니다.

| 항목 | 설명 및 위치 |
| --- | --- |
| **SDK 키** | 영업 담당자 또는 기술 지원팀을 통해 발급받은 고유 키 (`KollusStorage.applicationKey`) |
| **만료일** | SDK 키와 함께 제공되는 인증 유효 기간 (`KollusStorage.applicationExpireDate`) |
| **Bundle ID** | 필수 지정 항목으로 `Info.plist` 내용과 일치 필요 (`KollusStorage.applicationBundleID`) |

> **INFO**
>
> SDK 키 발급
>
> SDK 키는 콘솔에서 직접 발급할 수 없습니다. 영업 담당자 또는 기술 지원팀(PE, [tech_support@catenoid.net](mailto:tech_support@catenoid.net))으로 Bundle ID와 함께 발급을 요청하세요.

### Multi DRM (FairPlay) 연동 안내

iOS 환경에서 FairPlay 기반의 Multi DRM 콘텐츠를 처리하는 경우 `PallyConFPSSDK.framework`가 함께 통합되어 동작합니다. SDK 키 외에 별도의 `site_id` 및 FPS 인증서 등이 필요할 수 있으므로, 해당 콘텐츠를 다루는 경우 기술 지원팀([tech_support@catenoid.net](mailto:tech_support@catenoid.net))에 문의하세요.

### 콘텐츠 다운로드 URL과 보안 주의사항

다운로드 대상 URL은 일반적으로 `https://v.kr.kollus.com/s?jwt=...`와 같은 형태의 일회성(One-time) URL 구조를 가집니다.

- 서버 간 연동 필수: JWT 발급 로직에는 보안 키가 포함되므로 반드시 고객사의 백엔드 서버에서 수행해야 합니다. 보안 취약점이 발생할 수 있으므로 모바일 앱 클라이언트가 JWT를 직접 생성해서는 안 됩니다.
- SDK 처리 방식: 모바일 앱은 고객사 서버로부터 전달받은 URL을 변형 없이 그대로 SDK 내부 연동 메서드에 전달하여 사용합니다.

## 구현 가이드 구성

- [1. 다운로드 준비](/dev-guide/kollus-mobile-app/sdk/ios/guide/prepare/): SDK 초기화 및 인증, 시작 메서드 선택, 백그라운드 다운로드 옵션 및 저장소 정보 조회
- [2. 스트리밍 재생](/dev-guide/kollus-mobile-app/sdk/ios/guide/streaming-playback/): JWT URL 온라인 스트리밍, 미디어 전달 방식 특징, LMS 시청 통계 콜백 및 라이브 처리
- [3. 콘텐츠 다운로드](/dev-guide/kollus-mobile-app/sdk/ios/guide/download/): 정보 등록 및 다운로드 시작 2단계 제어, 취소/재시작 프로세스 및 진행률 추적
- [4. 다운로드 목록 관리](/dev-guide/kollus-mobile-app/sdk/ios/guide/download-list/): 다운로드 콘텐츠 목록 조회, 유형별 필터링 분기, 최근 다운로드 및 정렬 표시
- [5. 오프라인 재생](/dev-guide/kollus-mobile-app/sdk/ios/guide/offline-playback/): 플레이어 연동 및 로컬 재생 흐름, 네트워크 단절 시 DRM 검증 조건 처리
- [6. DRM 라이선스 갱신](/dev-guide/kollus-mobile-app/sdk/ios/guide/license-renewal/): 라이선스 만료 조건 확인, 일괄 갱신 처리 및 백그라운드 실행 제약 사항
- [7. 다운로드 콘텐츠 삭제](/dev-guide/kollus-mobile-app/sdk/ios/guide/delete/): 단일/전체 콘텐츠 삭제 및 DRM 응답에 따른 만료 파일 정리
- [8. 다운로드 이벤트/콜백](/dev-guide/kollus-mobile-app/sdk/ios/guide/event/): 다운로드 상태 변경 추적 및 DRM 검증/갱신 결과를 다루는 리스너
- [9. 다운로드 에러 코드](/dev-guide/kollus-mobile-app/sdk/ios/guide/error-code/): 주요 에러 대응 방법
- [안티 패턴 (자주 하는 실수)](/dev-guide/kollus-mobile-app/sdk/ios/guide/anti-pattern/): 잘못된 구현 사례와 이를 올바르게 해결하는 방법

## 참고 자료

- 공식 샘플: kollus_player_ios
- 콜백 상세 명세: DRM 다운로드 콜백
- 기술 문의: tech_support@catenoid.net
