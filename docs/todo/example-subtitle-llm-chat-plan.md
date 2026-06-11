# Example 앱 자막 기반 LLM 챗봇 구현 계획

- 작성: JunyoungJung, 2026-06-10
- 참조 구현: `~/Documents/GitHub/Smart_Report` (DollarMore) — GPT Auth / OpenAI Codex Responses API 패턴
- 상태: 계획 (미착수)

## 1. 목표

영상 재생 시 자막 파일을 **미리(전체) 확보**해 LLM 컨텍스트로 넣고, 플레이어 콘솔에서 강의 내용에 대해 질문/답변하는 챗봇 pane을 Example 앱에 추가한다.

범위:

- 패키지(`Sources/`): Kollus 자막 트랙 목록(`listSubTitle`) 브리지 — 최소 변경
- Example 앱: 자막 다운로드/파싱, GPT 인증/클라이언트, 챗 UI — 변경 대부분
- LLM/챗 코드는 Example 앱에만 둔다. 패키지는 자막 URL 노출까지만 책임

비범위:

- host 앱(서비스) 적용 — 콘텐츠 텍스트 외부 전송에 대한 계약/보안 검토 선행 필요
- RAG/벡터 검색 — 자막 전체를 프롬프트에 넣는 단순 방식으로 시작

## 2. 현재 구조 진단 (2026-06-10 기준)

| 항목 | 상태 |
|---|---|
| 자막 cue 스트림 | `KollusDelegateBridge` → `PlayerEvent.captionDidUpdate(text:isSecondary:)` — 재생 중 한 줄씩. 미리 받기 불가 |
| 전체 자막 파일 | SDK `KollusPlayerView.listSubTitle`(`SubTitleInfo`: `strName`/`strUrl`/`strLanguage`/`isAISubtitles`)에 존재하나 **패키지가 노출 안 함** |
| 도메인 타입 | `PlayerSubtitleTrack` / `availableTracks`(`PlayerFeatureSet.swift`) 정의돼 있으나 채우는 코드 없음 |
| 트랙 선택 | `selectSubtitleTrack(trackID)` → rawValue를 경로로 `setSubTitlePath`에 전달 — 트랙 ID = 자막 경로 설계 이미 존재 |
| 콘솔 UI | `PlayerConsoleViewController` pane 패턴 (Bookmark/Metadata/Caption) — 챗 탭 추가 지점 |

## 3. Smart_Report에서 가져올 GPT 패턴

출처: `Smart_Report/Modules/Data/Sources/AI/`

### 3.1 인증 — OpenAI Device Code Flow (`OpenAIDeviceAuthenticator.swift`)

API 키 발급 없이 ChatGPT Plus/Pro 구독으로 과금. 흐름:

1. `POST auth.openai.com/api/accounts/deviceauth/usercode` → `user_code` + `device_auth_id`
2. 사용자가 `auth.openai.com/codex/device`에서 코드 입력 (앱은 URL/코드 표시)
3. 앱은 `deviceauth/token`을 interval 간격 폴링 (403/404 = 미인증, 15분 타임아웃)
4. 성공 시 `authorization_code` + `code_verifier` 수신 → `oauth/token`으로 교환 → `id_token`/`access_token`/`refresh_token`
5. JWT claims에서 email/planType/만료 추출

### 3.2 자격증명 저장 — Keychain (`OpenAICredentialVault.swift`)

- `kSecClassGenericPassword`, service 이름 버전 포함 (예: `videoplayer.example.openai-credential.v1`)
- `OpenAICredential`: 토큰 3종 + email/planType/expiresAt, `isExpired`(5분 여유)
- UserDefaults 금지 — Keychain만

### 3.3 API 호출 — Codex Responses API SSE 스트리밍 (`OpenAIClient.swift`)

- `POST https://chatgpt.com/backend-api/codex/responses`, `Bearer {accessToken}`
- body: `{ model, instructions(시스템), input[메시지 배열], store: false, stream: true }`
- `URLSession.bytes(for:)` → `data: ` 라인 파싱 → `response.output_text.delta` 누적, 델타 콜백으로 UI 실시간 갱신
- 에러: 429 → quota/rate 구분, 401 → 인증 만료

### 3.4 오케스트레이션 (`GPTAnalysisService.swift`)

- vault에서 credential 로드 → 호출 → 401이면 refresh 후 1회 재시도 → retryable 에러 최대 2회 백오프(1s/3s)
- refresh 성공 시 vault에 즉시 저장

### 3.5 챗봇용 변형 포인트 (Smart_Report와 다른 부분)

- Smart_Report는 단발 분석(프롬프트 1회 → JSON 응답). 챗봇은 **멀티턴**: `input` 배열에 대화 이력(user/assistant 교대)을 누적해 전송
- 시스템 instruction에 자막 전문 투입: "아래는 강의 자막 전문이다. 이 내용에 근거해 한국어로 답하라. 자막에 없는 내용은 모른다고 답하라."
- JSON 강제 불필요 — 일반 텍스트 응답, 파서 불필요

## 4. 아키텍처

```
[패키지]
KollusDelegateBridge ─(콘텐츠 준비 시 listSubTitle 읽기)→ KollusEngineSignal.subtitleListUpdated
  → KollusSignalMapper → PlayerEngineOutput → PlayerEvent.subtitleTracksDidLoad([PlayerSubtitleTrack])

[Example 앱]
PlayerInteractor ─(이벤트 수신)→ SubtitleTranscriptStore
  SubtitleFetcher: URLSession 다운로드(원격) / 파일 read(다운로드 콘텐츠 로컬 경로)
  SubtitleParser: SMI·SRT → [(시각, 텍스트)] → 전문 텍스트
ChatPaneViewController (PlayerConsolePane)
  ↕ SubtitleChatViewModel ── GPTChatService
        GPTChatClient (SSE 스트리밍, 멀티턴 input)
        OpenAIDeviceAuthenticator / OpenAICredentialVault (Smart_Report 포팅)
```

## 5. 단계별 구현

### Phase 1 — 패키지: 자막 트랙 목록 브리지 (소규모)

| 파일 | 작업 |
|---|---|
| `Sources/VideoPlayerEngineKollus/KollusEngineSignal.swift` | `case subtitleListUpdated([KollusSubtitleTrackInfo])` 추가 (name/language/url/isAI 값 타입) |
| `Sources/VideoPlayerEngineKollus/KollusDelegateBridge.swift` | 콘텐츠 준비(readyToPlay 계열) 시점에 `listSubTitle` 읽어 emit |
| `Sources/VideoPlayerEngineKollus/Signal/KollusSignalMapper.swift` | signal → `PlayerEngineOutput` 매핑 (순수 함수) |
| `Sources/VideoPlayerCore/Domain/PlayerEvent.swift` | `case subtitleTracksDidLoad([PlayerSubtitleTrack])` 추가 |
| `Sources/VideoPlayerCore/Domain/PlayerFeatureSet.swift` | `PlayerSubtitleTrack`에 `sourceURL: URL?` 필드 추가 검토 (현행 trackID=경로 설계 유지 시 불필요) |
| `Tests/VideoPlayerModuleTests/Kollus/` | mapper 매핑 테스트 (Swift Testing) |

경계 규칙: SDK 타입(`SubTitleInfo`)은 `VideoPlayerEngineKollus` 밖으로 안 나감. Core에는 이름·언어·URL 문자열만 전달.

### Phase 2 — Example: 자막 확보 파이프라인 (중규모)

| 파일(신규) | 책임 |
|---|---|
| `Example/Sources/Player/Chat/SubtitleFetcher.swift` | 트랙 URL → `Data` 로드. `http(s)`는 URLSession, 로컬 경로는 FileManager. **인코딩 처리 필수**: UTF-8 시도 → 실패 시 EUC-KR(`CFStringEncodings.EUC_KR`) 변환 (한국어 SMI 대부분 EUC-KR) |
| `Example/Sources/Player/Chat/SubtitleParser.swift` | SMI(`<SYNC Start=ms>`) + SRT(타임코드 블록) 파싱 → `[SubtitleCue(start, text)]`. HTML 태그 제거, `&nbsp;` 등 엔티티 정리 |
| `Example/Sources/Player/Chat/SubtitleTranscriptStore.swift` | 콘텐츠당 1회 다운로드 캐시. `subtitleTracksDidLoad` 수신 → 첫 트랙(또는 한국어 우선) 즉시 fetch — URL에 만료 토큰 가능성 있어 로드 직후 받는 게 안전 |

수신 연결: `PlayerInteractor`(또는 `PlayerViewController`)의 이벤트 스트림 구독부에 `subtitleTracksDidLoad` 분기 추가.

### Phase 3 — Example: GPT 인증/클라이언트 포팅 (중규모)

Smart_Report에서 복사 후 네임스페이스/의존 정리 (Core/Domain/Logger 의존 제거, Foundation만):

| 파일(신규) | 원본 | 변경점 |
|---|---|---|
| `Example/Sources/Player/Chat/GPT/OpenAICredential.swift` | 동명 | 그대로 |
| `Example/Sources/Player/Chat/GPT/OpenAICredentialVault.swift` | 동명 | service 이름만 `videoplayer.example.openai-credential.v1` |
| `Example/Sources/Player/Chat/GPT/OpenAIDeviceAuthenticator.swift` | 동명 | 그대로 (clientID 동일 사용 가능) |
| `Example/Sources/Player/Chat/GPT/GPTChatClient.swift` | `OpenAIClient.swift` | `input`을 멀티턴 메시지 배열로 일반화, JSON 시스템 지침 제거, `AnalysisError` → 로컬 `GPTChatError` |
| `Example/Sources/Player/Chat/GPT/GPTChatService.swift` | `GPTAnalysisService.swift` | 401 refresh 재시도 로직 유지, 파서 제거, 대화 이력 관리 |

로그인 UI: 설정 탭 또는 챗 pane 첫 진입 시 — user code + 인증 URL 표시, "Safari에서 열기" 버튼, 폴링 진행 표시. (Smart_Report `SettingViewController` GPT 로그인 섹션 참고)

### Phase 4 — Example: 챗 UI (중규모)

| 파일(신규) | 책임 |
|---|---|
| `Example/Sources/Player/Console/ChatPaneViewController.swift` | `PlayerConsolePane` 채택. 말풍선 리스트(UITableView) + 입력바. 스트리밍 델타로 마지막 셀 텍스트 갱신 |
| `Example/Sources/Player/Chat/SubtitleChatViewModel.swift` | 상태: `자막없음 / 로딩 / 준비됨 / 미인증 / 응답중`. 대화 이력 보관, transcript를 시스템 instruction에 합성 |

콘솔 등록: `PlayerConsoleViewController` 탭 배열에 "AI 챗" pane 추가. 자막 없는 콘텐츠(`subtitleTracksDidLoad` 빈 배열)면 pane에 비활성 안내 표시.

프롬프트 구성:

```
[시스템 instruction]
당신은 강의 내용 보조 튜터다. 아래 자막 전문에 근거해 한국어로 답하라.
자막에 없는 내용은 추측하지 말고 없다고 답하라.
--- 자막 전문 ---
{HH:MM:SS 텍스트 ...}
```

토큰 한도: 1시간 강의 자막 ≈ 수만 자. 한도 초과 시 1차 대응은 타임스탬프 간략화 + 빈 줄 제거. 그래도 초과하면 앞/뒤 분할 요약 후 합성(후순위).

### Phase 5 — 테스트/QA

- 단위 테스트 (`Example/Tests/`, xcodebuild test):
  - `SubtitleParserTests` — SMI/SRT 샘플, EUC-KR 디코딩, 태그 제거
  - `SubtitleChatViewModelTests` — 상태 전이, 이력 누적, transcript 합성 (GPTChatService protocol mock)
- 패키지 테스트: `swift test --filter KollusSignalMapper`
- 실기기 QA: Kollus 자막 콘텐츠로 트랙 수신 → 다운로드 → 질문/답변 스트리밍, 자막 없는 콘텐츠 fallback, 토큰 만료 후 refresh 재시도

## 6. 리스크 / 결정 필요

| 항목 | 내용 | 대응 |
|---|---|---|
| Codex Responses API 비공식 | `chatgpt.com/backend-api/...`는 공개 계약 아님 — 변경 시 동작 중단 가능 | Example 테스트 용도로 수용. 클라이언트를 protocol로 격리해 정식 API/다른 벤더 교체 용이하게 |
| 자막 URL 만료 | edge 토큰 포함 가능 | 트랙 수신 즉시 다운로드 |
| EUC-KR | 한국어 SMI 다수 | charset 휴리스틱 + 양 인코딩 폴백, 테스트 고정 |
| 콘텐츠 텍스트 외부 전송 | 자막 = 콘텐츠 자산. 외부 LLM 전송은 유출에 해당 | Example 내부 검증 한정. 서비스 적용 전 별도 승인 |
| AI 자막 품질 | `isAISubtitles == true` 트랙 정확도 편차 | UI에 AI 자막 출처 뱃지 표시 |
| 경계 테스트 | `PlayerModuleBoundaryTests` 금지어 | 패키지 소스에 GPT/서비스 용어 안 들어감 (Example만) — 위반 없음 |

## 7. 작업 순서 요약

1. Phase 1 패키지 브리지 + mapper 테스트 → `swift test`
2. Phase 2 자막 fetch/parse + 파서 테스트
3. Phase 3 GPT 포팅 (Smart_Report 복사 → 의존 정리) + 로그인 UI
4. Phase 4 챗 pane + ViewModel 테스트
5. Phase 5 실기기 QA → `docs/example-app-rebuild-plan.md` 상태 갱신
