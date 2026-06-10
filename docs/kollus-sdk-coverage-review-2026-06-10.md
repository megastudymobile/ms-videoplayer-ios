# Kollus SDK 기능 구현 대조 검토 보고서

- 작성자: JunyoungJung
- 작성일: 2026-06-10
- 검토 기준: `docs/kollus-ios-sdk/` SDK 문서 ↔ `Sources/VideoPlayerEngineKollus/` 구현
- 검토 방법: 문서의 delegate/메서드/프로퍼티/가이드 절차 전수 나열 후 구현 코드와 1:1 대조. 핵심 주장은 코드 직접 확인으로 검증함
- 관련 문서: [architecture-review-2026-06-10.md](./architecture-review-2026-06-10.md)
- 개선 설계: [improvement-plan-2026-06-10.md](./improvement-plan-2026-06-10.md)

---

## 1. 총평

**재생 핵심 경로는 완성도가 높다.** SDK delegate 26종이 전부 브리지되어 있고, prepare/stop 호출 순서·스레딩 요구사항·anti-pattern 가이드를 모두 준수한다. 반면 **챕터·라이브 채팅·자막 트랙 열거는 미구현**이며, **다운로드 에러 무음 드롭과 Kollus 에러 코드 미분류**가 실질적 위험으로 남아 있다.

### 구현 충실도 맵

| 영역 | 커버리지 | 상태 |
|------|---------|------|
| 재생 제어 (prepare/play/pause/stop/seek/rate) | 100% | ✅ 완전 |
| Delegate 26종 (Player/DRM/LMS/Bookmark) | 100% | ✅ 완전 |
| 북마크 (add/remove/list/kind 구분) | 100% | ✅ 완전 |
| 줌 / 스크롤 / 화면 배율 | 100% | ✅ 완전 |
| HLS 대역폭 / adaptive streaming | 100% | ✅ 완전 |
| DRM(FairPlay) 설정 / LMS 추적 | 100% | ✅ 완전 |
| Next episode 메타데이터 | 100% | ✅ 완전 |
| 다운로드 lifecycle | ~85% | ⚠️ 에러 전파 누락 |
| 오프라인 재생 | ~70% | ⚠️ 사전 라이선스 검증 없음 |
| 자막 | ~40% | ⚠️ 외부 파일 주입만 지원 |
| 에러 코드 매핑 | ~20% | 🔴 대부분 `.unknown` 수렴 |
| 챕터 (Chapter/ChapterDict/KPSection) | 0% | ❌ 전체 미구현 |
| 라이브 채팅 (KollusChat) | 0% (기능상) | ❌ profile 수신 후 미주입 |
| Utils (LogUtil/UtilDelegate) | 0% | ❌ 미사용 (영향 미미) |

---

## 2. 🔴 버그성 — 우선 수정 필요

### 2.1 다운로드 에러 무음 드롭

`KollusStorageAdapter.swift:145-147`

```swift
func kollusStorage(_ kollusStorage: KollusStorage, downloadContent content: KollusContent, error: Error?) {
    storageDelegate?.storageDidUpdateContents(contentSnapshots)  // error 파라미터 버려짐
}
```

- 문서(guide/03-download.md)는 다운로드 진행 delegate에 `error` 파라미터를 정의하나, 구현은 이를 버리고 snapshot 갱신만 전달.
- 네트워크 실패·디스크 풀·쿼터 초과 등 **다운로드 실패가 host에 전달되지 않음**. `downloadProgress` 정체를 폴링으로 간접 감지하는 방법뿐.
- **조치**: `storageDidUpdateContents`에 error 전달 경로 추가 (또는 별도 `storageDidFailDownload(mediaContentKey:error:)` 콜백).

### 2.2 `checkContentURL` 에러 삼킴

`KollusStorageAdapter.swift:104-106`

```swift
func checkContentURL(_ url: String) -> String? {
    try? storage.checkContentURL(url)
}
```

- 문서(guide/03-download.md)는 미등록 URL 전달 시 에러 반환을 명시. 구현은 `try?`로 **"미등록 콘텐츠"와 "조회 실패"가 모두 nil**로 수렴.
- **조치**: throws 시그니처 유지 또는 Result 반환으로 두 케이스 구분.

### 2.3 Kollus 에러 코드 미분류

`PlayerError+Classify.swift`

- 문서(guide/09-error-code.md)가 정의하는 에러 카테고리: 인증 실패, 미지원 기기, 저장소 풀, 파일 쓰기 실패, 중복 다운로드, 다운로드 완료 상태 재요청, 콘텐츠 미존재, DRM 기한 만료, 재생 시간 초과, 재생 횟수 초과, 서버 강제 삭제 — 총 11종.
- 현재 분류기는 `NSURLErrorDomain`/`AVFoundationErrorDomain`만 처리. **Kollus SDK 고유 에러 도메인은 전부 `.unknown`으로 수렴**.
- host가 "재다운로드 필요" vs "라이선스 갱신 필요" vs "저장 공간 확보 필요"를 구분할 수 없어 사용자 안내 UX 분기 불가.
- **조치**: Kollus 에러 도메인·코드 분류기 추가. `PlayerError`에 라이선스 만료/저장소 풀 등 세분화 케이스 신설 검토.

---

## 3. 🟠 기능 누락 — 의도 확인 필요

### 3.1 챕터 전체 미구현

- 문서: `Chapter`(position, value), `ChapterDict`(언어별 챕터 목록), `KPSection`(미리보기 구간), `playerView.chapterInfo` 프로퍼티 정의 (api-reference/05-chapter-subtitle.md).
- 구현: Core에 `PlayerChapterID` 타입(`PlayerIdentity.swift:43`)만 존재. adapter가 `chapterInfo`를 한 번도 읽지 않음 (grep 0건).
- 강의 콘텐츠 특성상 챕터 탐색 요구 가능성 높음. **의도적 제외인지 확인 후 결정**.

### 3.2 라이브 채팅 미배선

- `KollusEnvironment.chat`으로 `KollusLiveChatProfile`(roomId, chattingServer, userId, nickName 등)을 받지만, **adapter에 `playerView.kollusChat` 주입 코드가 없음** (grep 확인: adapter 내 chat 관련 코드 0건).
- 설정만 받고 동작하지 않는 반쪽 상태 — API 사용자가 "설정했는데 왜 안 되지"에 빠지는 최악의 형태.
- **조치**: 배선하거나, 당장 쓸 계획 없으면 `KollusEnvironment`에서 제거(또는 deprecated + 미동작 명시).

### 3.3 자막 트랙 관리 미구현

- 미구현: `listSubTitle`/`listSubTitleSub` 트랙 열거 (미조회), `setSubTitleSubPath` 보조 자막, `SubTitleInfo` 모델 매핑.
- 현재 가능한 것: 외부 자막 파일 경로 주입(`setSubTitlePath`)뿐. `selectSubtitleTrack(_:)`도 trackID rawValue를 파일 경로로 해석 — **SDK 내장 자막 트랙 선택 불가**.
- 참고: 자막 가시성 토글·폰트 크기 조절은 SDK 자체에 API가 없음 — 현재의 `.policyDowngraded` 처리(`KollusPlayerAdapter.swift:348-365`)는 올바름.

### 3.4 오프라인 재생 사전 DRM 검증 없음

- 문서(guide/05-offline-playback.md)는 재생 전 4조건 체크 권장: `DRMExpired == false`, `DRMExpireDate > now`, 재생 시간 잔여, 재생 횟수 잔여.
- 구현은 `prepareToPlay` 중 SDK 내부 실패에만 의존 → **만료 콘텐츠가 재생 버튼을 누른 뒤에야 실패**.
- 연쇄 문제 — `KollusContentSnapshot` 미캡처 필드:

| 누락 필드 | 문서 위치 | 영향 |
|----------|----------|------|
| `DRMTotalExpirePlayTime` / `DRMExpirePlayTime` | api-reference/04 | 시간제한 라이선스 검증 불가 |
| `contentIndex` | api-reference/04 ("오프라인 재생에 사용") | SDK 의존 시 오프라인 재생 문제 가능 |
| `DRMCheckDate` / `DRMExpireRefreshPopup` | api-reference/04 | 갱신 안내 UX 신호 유실 |
| `downloadStopSize` | api-reference/04 | 다운로드 재개 위치 미노출 |
| `iosPlayerType` | api-reference/04 | 디코더 타입 힌트 유실 |

- **조치**: snapshot에 DRM 시간/횟수 필드 보강 + 재생 전 검증 헬퍼(`validateOfflineDRM()`) 추가.

### 3.5 라이선스 갱신 트리거 부재

- `updateDRM(includeExpiredOnly:)` API 자체는 노출됨 (`KollusDownloadCenter:77`).
- 문서(guide/06-license-renewal.md) 권장 패턴 — foreground 진입 시(`applicationDidBecomeActive`) 또는 재생 전 만료 임박 콘텐츠 갱신 — 은 미통합. host 책임으로 남음.
- **조치**: 최소한 host 책임임을 모듈 문서에 명시. 가능하면 prepare 경로에 만료 임박 시 자동 갱신 옵션 제공.

---

## 4. 🟡 경미한 차이

| 항목 | 위치 | 내용 |
|------|------|------|
| `userInteraction` 플래그 부분 드롭 | `KollusSignalMapper.swift:38` | play/pause에서 버림. stop은 사용 중(`.userClosed` vs `.finished` 구분). 사용자 조작 vs 시스템 자동 재생 구분이 필요해지면 전파 추가 |
| buffering 종료 후 자동 재생 | `KollusPlayerAdapter.swift:865-869` | 문서는 buffering 해제 시 수동 `play()` 재호출 요구, 구현은 자동 `.playing` 복귀. 의도적 UX 개선으로 보임 — 주석에 문서 대비 의도적 일탈임을 기록 권장 |
| scheme 고급 옵션 미노출 | `KollusEnvironment` | 워터마크 일체, repeat 구간(`nRepeatStartTime/EndTime`), intro skip, `forceNScreen`/`ignoreZero`(이어보기), `setBufferingRatio`, `muteOnStart` — 필요 시 추가 |
| storage 시작 변형 미노출 | `KollusStorageProtocol` | `startStorageWithFirst/Check/NewPlayerID` 3종 미구현. anti-pattern 문서가 `NewPlayerID` 남용을 금지하므로 의도적일 수 있음 — 의도라면 주석으로 명시 |
| `storagePath`/`appUserAgent`/`deviceType` 미노출 | `KollusStorageProtocol` | 진단·고급 설정용 프로퍼티. 현재 필요성 낮음 |
| position 폴링 (0.5s) | `KollusPlayerAdapter.swift:103-108` | SDK `position:` 콜백이 seek 전용이라는 한계의 올바른 보완. 문서에 없는 전략이므로 폴링 간격 설정값화 검토 |

---

## 5. ✅ 문서 준수 확인된 항목

- **Delegate 커버리지 100%**: `KollusPlayerDelegate` 23종 + DRM/LMS/Bookmark delegate 3종 전부 `KollusDelegateBridge`에서 브리지 → `KollusEngineSignal` 매핑. 누락 0건.
- **prepare 시퀀스 정확**: delegate 연결 → storage/DRM/옵션 주입 → `prepareToPlay(withMode:)` → continuation으로 완료 대기. 문서 순서와 일치.
- **stop/cleanup 순서 정확**: 폴링 중지 → `stop()` → `removeFromSuperview()` → 참조 해제. 문서의 리소스 반환 지침 준수.
- **스레딩 준수**: `playerView` 접근 전부 MainActor 보장. bridge `@MainActor`, 동기 줌은 `MainActor.assumeIsolated`.
- **anti-pattern 위반 0건**: JWT 클라이언트 생성 없음, `startWithNewPlayerID` 미호출, `loadContentURL` 전 `checkContentURL` 패턴 준수, bundle ID 검증 존재, `setBackgroundDownload` 의미 오해 없음.
- **북마크 낙관적 캐시**: SDK가 로컬 add를 `playerView.bookmarks`에 즉시 반영하지 않는(서버 동기화 후 갱신) 비동기 특성을 정확히 이해한 처리. 문서에 없는 동작을 코드 주석으로 보존한 점 양호.

---

## 6. 권장 조치 순서

1. **다운로드 에러 전파** (§2.1) — 무음 실패는 데이터 손실급. delegate error 전달 경로 추가
2. **Kollus 에러 도메인 분류** (§2.3) — 사용자 안내 UX 분기의 전제조건
3. **`checkContentURL` 에러 구분** (§2.2) — 소규모 수정
4. **오프라인 사전 DRM 검증 + snapshot 필드 보강** (§3.4)
5. **채팅: 배선 또는 설정 제거** (§3.2) — 반쪽 상태 해소
6. **챕터·자막 트랙: 제품 요구사항 확인 후 구현 여부 결정** (§3.1, §3.3)
7. **라이선스 갱신 책임 문서화** (§3.5)

---

## 7. 결론

문서화된 SDK 기능 중 **재생·북마크·DRM·LMS·디스플레이 제어는 누락 없이 올바르게 구현**되었고, 호출 순서와 스레딩도 문서를 정확히 따른다. 미구현 영역(챕터·채팅·자막 트랙)은 기능 단위로 깔끔하게 비어 있어 추가 구현 시 충돌 없음. 즉시 손봐야 할 것은 구현 품질 문제 3건 — **다운로드 에러 무음 드롭, 에러 코드 미분류, checkContentURL 에러 삼킴** — 이며, 모두 국소 수정으로 해결 가능하다.
