# videoplayer-ios-ms 기술 사양 리뷰 발표 원고 작업본

작성자: JunyoungJung  
작성일: 2026-06-11  
원본: `docs/presentation/player-module-review-ios.html`  
최종 스토리보드: `docs/presentation/player-module-review-ios-storyboard-v3.md`  
시각 자료 원본: `docs/presentation/player-module-review-ios-visual-guide.md`  
대상: iOS 팀 엔지니어링 리뷰, 30분 발표 + Q&A

## 작업 방식

이 문서는 HTML 발표본의 내용을 슬라이드 단위로 분리한 원고 작업본이다. 먼저 메시지와 논리 흐름을 이 Markdown에서 고친 뒤, 확정된 문구만 HTML에 반영한다.
최종 HTML 개편은 `player-module-review-ios-storyboard-v3.md`를 기준으로 진행한다.
Mermaid, SVG, Swift 예시 코드, pseudo code는 `player-module-review-ios-visual-guide.md`에서 관리하고, HTML 반영 시 슬라이드별로 필요한 자료를 가져온다.

각 슬라이드는 아래 관점으로 검토한다.

- 청중이 한 장에서 가져갈 핵심 결론이 분명한가
- 기술 디테일이 많아도 승인/리뷰 의사결정으로 연결되는가
- 코드·숫자·제약이 실제 현재 상태와 맞는가
- 발표자가 말할 내용과 화면에 남길 문구가 분리되어 있는가
- 시각 자료가 개념 이해를 돕고, 텍스트 설명을 줄이는가

## 전체 흐름 초안

1. 왜 만들었는가: 기존 구조의 비용과 위험
2. 어떤 원칙으로 설계했는가: 의도, 방법, 상태 소유권 분리
3. 어떻게 동작하는가: command flow, module boundary, reducer, capability
4. 무엇이 검증됐는가: 문제 해결 매핑, 테스트, Example app
5. 어떻게 쓰는가: AVPlayer/Kollus/Skin quickstart
6. 무엇을 보여줄 것인가: live demo
7. 무엇이 남았는가: 한계, 결정 요청, 마이그레이션

## docs/blog 반영 개선 방향

`docs/blog`의 5편은 발표의 배경 논리로 그대로 쓸 수 있다. 현재 HTML 발표본은 "모듈을 만들었다"에서 바로 출발하지만, 블로그는 "왜 영상 재생이 단순 AVPlayer 문제가 아닌가"를 먼저 설득한다. 발표도 이 흐름을 압축해서 가져가야 한다.

### 블로그 5편의 핵심 주장

| 블로그 | 발표에 가져올 핵심 | 발표에서 쓰일 위치 |
| --- | --- | --- |
| 01. DRM과 FairPlay Streaming | 교육 영상은 URL 재생이 아니라 콘텐츠 보호 문제다. 키는 앱이 직접 볼 수 없고, OS 보호 재생 경로에 맡겨야 한다. | 문제 정의, 왜 모듈 경계가 필요한가 |
| 02. HLS/SPC/CKC | m3u8의 `#EXT-X-KEY`에서 FairPlay 키 교환이 시작되고, 앱은 SPC/CKC 메시지를 전달하는 경계 역할만 한다. | Kollus/DRM 복잡도 설명, 실기기 QA 이유 |
| 03. 왜 KollusSDK인가 | Kollus는 트랜스코딩, CDN, DRM, 분석, 운영 자동화를 사는 Build-vs-Buy 결정이다. | vendor를 쓰는 이유, 직접 구현하지 않는 이유 |
| 04. 왜 PallyCon FPS인가 | Kollus 아래에도 PallyCon DRM SaaS가 있고, 우리 코드에는 직접 호출이 없지만 link dependency로 들어온다. | PallyCon을 직접 import하지 않는 설계 설명 |
| 05. 플레이어 모듈화 | 이미 SDK가 있어도 앱 코드를 vendor에 묶지 않기 위해 엔진 교체, 단방향 상태, capability, vendor 격리, Swift concurrency 원칙이 필요하다. | 발표의 메인 설계 원칙 |

### 발표 메시지 재정의

현재 메시지:

> 영상 재생을 모듈로 만들었습니다.

개선 메시지:

> DRM/VOD/vendor 복잡도를 앱 화면 밖으로 격리하고, host 앱은 재생 의도와 상태만 다루게 만들었습니다.

이 메시지가 더 좋은 이유:

- 교육 서비스 영상 재생의 본질이 "URL을 재생하는 코드"가 아니라 "보호된 콘텐츠 전달 시스템"임을 먼저 설명한다.
- Kollus/PallyCon을 쓰는 이유와 동시에, 그 SDK를 앱 코드 전체에 퍼뜨리면 안 되는 이유가 자연스럽게 연결된다.
- 모듈화가 취향이나 리팩터링이 아니라 장기 운영 리스크를 줄이는 설계라는 점이 분명해진다.

### 개정 발표 흐름 제안

1. **영상 재생은 URL 문제가 아니다**  
   DRM, FPS, SPC/CKC, 오프라인 라이선스 때문에 앱 화면이 직접 떠안으면 안 되는 문제라는 전제를 만든다.

2. **우리는 Build 대신 Buy를 선택했다**  
   VOD 플랫폼은 Kollus에, DRM 라이선스는 PallyCon에 위임한다. 이 선택은 맞지만 vendor lock-in과 블랙박스 리스크가 남는다.

3. **그래서 vendor를 쓰되, 코드에서는 격리한다**  
   `VideoPlayerEngineKollus` 안에 Kollus/PallyCon을 가두고, host 앱은 `PlaybackSource`, `PlaybackCommand`, `PlaybackState`만 본다.

4. **모듈의 설계 원칙은 다섯 가지다**  
   엔진 교체 가능성, 단방향 상태 흐름, capability 게이팅, vendor 격리, Swift concurrency first.

5. **현재 구현은 이 원칙을 검증 가능한 코드로 만든다**  
   module graph, reducer, engine adapter, packaging, tests, Example app.

6. **회의에서 결정할 것은 구조 승인과 파일럿 범위다**  
   세부 정책 5건은 부속 의사결정이고, 메인 결정은 "이 구조를 팀 표준으로 삼을 것인가"다.

### 슬라이드 재구성 제안

현재 23장은 구현 설명이 많아 중반 이후 밀도가 높다. 블로그 흐름을 반영하면 아래처럼 20장 안팎으로 압축하는 편이 낫다.

| 새 번호 | 슬라이드 | 목적 | 기존 대응 |
| --- | --- | --- | --- |
| 01 | 영상 재생 모듈 기술 사양 리뷰 | 회의 목적 명확화 | 01 |
| 02 | 오늘 승인받고 싶은 것 | 구조 승인, 정책 결정, 파일럿 범위 | 02 |
| 03 | 영상 재생은 URL 하나가 아니다 | DRM/FPS/오프라인/기기 보호 전제 | 신규, blog 01 |
| 04 | HLS DRM은 SPC/CKC 흐름을 가진다 | 앱이 키를 직접 다루면 안 되는 이유 | 신규, blog 02 |
| 05 | Kollus와 PallyCon은 Build-vs-Buy 결과다 | vendor 사용의 정당성 | 신규, blog 03-04 |
| 06 | 문제는 vendor가 아니라 vendor 침투다 | 기존 구조 문제 정의 | 03-04 |
| 07 | 설계 원칙: vendor는 쓰되, 격리한다 | 발표 핵심 명제 | 05 |
| 08 | 명령과 상태는 한 방향으로 흐른다 | runtime flow | 06 |
| 09 | product 경계가 vendor 경계다 | module graph | 07 |
| 10 | 상태 전이는 SDK 밖에서 검증한다 | reducer/state ownership | 08 |
| 11 | capability로 기능을 사전 게이트한다 | engine contract | 09 |
| 12 | 기존 문제는 이렇게 줄었다 | 문제-해결 매핑 | 10-11 |
| 13 | 현재 검증 상태 | 숫자, 테스트, Example app | 12 |
| 14 | AVPlayer 사용 예 | Native quickstart | 13 |
| 15 | Kollus 사용 예 | Kollus quickstart | 14 |
| 16 | Skin은 엔진을 모른다 | UI 조립 전략 | 15 |
| 17 | 라이브 데모 | 설계 증명 | 16 |
| 18 | 품질 가드와 남은 한계 | 테스트/QA/패키징/미지원 | 17, 20 |
| 19 | 결정 요청 | 추천안 포함 | 21 |
| 20 | 파일럿 제안 | 마이그레이션과 마무리 | 22-23 |

### 새로 들어가야 하는 핵심 슬라이드 문구 초안

#### 신규 03. 영상 재생은 URL 하나가 아니다

Title: 강의 재생은 `AVPlayer(url:)`에서 끝나지 않습니다.

Bullets:

- 유료 강의는 HLS 세그먼트만 재생하는 문제가 아니라, 수강 권한과 콘텐츠 보호를 함께 검증하는 문제다.
- FairPlay Streaming은 콘텐츠 키를 앱 코드에 노출하지 않고 AVFoundation의 보호된 재생 경로에서 처리한다.
- 다운로드 강의는 persistent license, 만료, 오프라인 검증까지 포함한다.

Speaker note:

처음에는 URL 하나를 AVPlayer에 넣으면 끝처럼 보인다. 하지만 교육 서비스에서는 화면 녹화, 외부 출력, 수강 기간, 다운로드 만료가 모두 재생 요구사항이다. 그래서 플레이어 화면이 DRM과 권한 흐름을 직접 떠안으면 안 된다.

#### 신규 04. HLS DRM은 SPC/CKC 흐름을 가진다

Title: 앱은 키를 해석하지 않고, 안전하게 전달해야 합니다.

Flow:

1. m3u8에서 `#EXT-X-KEY`와 `skd://` 신호 발견
2. AVFoundation/FPS가 SPC 키 요청 생성
3. SDK가 라이선스 서버에 SPC 전달
4. 서버가 권한 확인 뒤 CKC 응답
5. AVFoundation이 보호된 경로에서 복호화와 디코딩 수행

Takeaway:

우리 코드가 해야 할 일은 키를 직접 다루는 것이 아니라, 이 흐름을 SDK 경계 안에 가두고 실패를 도메인 에러로 번역하는 것이다.

#### 신규 05. Kollus와 PallyCon은 Build-vs-Buy 결과다

Title: 우리는 영상 인프라를 직접 짓지 않기로 선택했습니다.

Cards:

- Kollus: 트랜스코딩, CDN, DRM 패키징, 분석, 운영 어드민을 제공하는 VOD 플랫폼
- PallyCon: FairPlay 라이선스 발급과 persistent license 처리를 맡는 DRM SaaS
- 우리 모듈: vendor를 직접 대체하지 않고, vendor 의존을 host 앱 밖으로 격리

Speaker note:

Kollus/PallyCon을 쓰는 선택은 합리적이다. 문제는 쓰느냐 마느냐가 아니라, 그 의존성이 앱 화면과 도메인 코드 전체에 퍼지느냐 한 곳에 갇히느냐다.

#### 개정 07. 설계 원칙

Title: vendor는 쓰되, 앱 코드는 vendor를 몰라야 합니다.

Principles:

- 엔진 교체 가능성: AVPlayer와 Kollus는 같은 engine contract 뒤에 둔다.
- 단방향 상태 흐름: 화면은 command를 보내고 state를 구독한다.
- capability 게이팅: 지원하지 않는 기능은 시작 시점에 숨기거나 명시적으로 거부한다.
- vendor 격리: Kollus/PallyCon import는 Kollus engine product 안에만 둔다.
- Swift concurrency first: 엔진과 core 상태 변경은 actor로 직렬화한다.

### 문구 톤 조정 규칙

- `레거시`는 발표 화면에서는 `기존 구조`로 바꾼다. 비판보다 문제 해결에 초점을 둔다.
- `SDK 무지`는 `SDK 비의존`으로 바꾼다.
- `보류 버그`는 `남은 상태 전이 이슈`로 바꾼다.
- `파리티`는 `기존 UX 정렬`로 바꾼다.
- 숫자와 API 예시는 HTML 반영 전에 코드와 테스트로 재확인한다.

## 팀 설득형 내러티브 v2

사용자 피드백을 반영한 실제 발표 흐름은 아래 순서가 더 적합하다. 팀원 입장에서는 DRM/FPS 자체보다 먼저 "왜 지금 우리 팀이 공통 플레이어 모듈을 만들어야 하는가"가 납득되어야 한다.

### 핵심 설득 흐름

1. **우리 팀에는 이미 플레이어 중복 문제가 있다**  
   고등 서비스 플레이어는 오래된 코드이고, 유초등, 해외사업부 등 여러 서비스가 각자 네이티브 플레이어를 다시 붙이고 있다. 같은 재생 정책, 같은 제스처, 같은 다운로드/DRM 처리를 서비스마다 반복 구현하고 있다.

2. **그래서 공통 모듈이 필요하다**  
   플레이어를 서비스 화면에 묶어두면 기능 추가와 버그 수정이 서비스별로 반복된다. 공통 모듈로 만들면 한 번 고친 재생 정책과 UI 조립 방식을 여러 서비스가 재사용할 수 있다.

3. **하지만 단순 wrapper로는 부족하다**  
   KollusSDK 호출만 감싼 wrapper는 SDK 의존 위치만 옮길 뿐이다. 서비스별 커스텀 UI, 정책 차이, 향후 SDK 교체 가능성을 감당하려면 우리 도메인 기준의 자체 engine contract가 필요하다.

4. **SDK는 사서 쓰되, 앱 코드는 SDK에 묶이지 않아야 한다**  
   블로그에서 정리했듯 VOD/DRM 인프라는 직접 구현보다 구매가 합리적이다. 다만 더 좋은 SDK가 나오거나 사업부별 요구가 달라질 수 있으므로, SDK는 engine adapter 안에 가두고 host는 `PlaybackCommand`와 `PlaybackState`만 다루게 해야 한다.

5. **그래서 POP와 주입 가능한 구조로 설계했다**  
   공통 core는 상태와 명령을 소유하고, 엔진/기능/스킨은 protocol로 분리한다. Host는 필요한 정책, skin block, engine module을 주입해 서비스별로 커스텀할 수 있다.

### v2 발표 메시지

> 여러 서비스가 각자 다시 만들던 플레이어를, SDK에 묶이지 않는 공통 재생 모듈로 바꿔 재사용 가능하게 만들겠습니다.

### v2 슬라이드 흐름

| 새 번호 | 슬라이드 | 핵심 질문 | 답 |
| --- | --- | --- | --- |
| 01 | 왜 지금 플레이어 모듈화인가 | 팀에 무슨 문제가 있나? | 서비스별 중복 구현과 오래된 코드가 누적되고 있다 |
| 02 | 현재 구조의 비용 | 어떤 비효율이 발생하나? | 기능/버그/UX/DRM 대응이 서비스별로 반복된다 |
| 03 | 목표는 공통 재사용 모듈 | 무엇을 만들려 하나? | 여러 서비스가 같은 core와 skin을 재사용한다 |
| 04 | 단순 SDK wrapper로는 부족 | 그냥 SDK 감싸면 안 되나? | 교체/커스텀/테스트 가능성이 부족하다 |
| 05 | SDK는 사서 쓰되, 의존은 줄인다 | SDK 의존 축소가 가능한가? | adapter와 engine contract로 가능하게 만든다 |
| 06 | 자체 engine contract | 어떻게 SDK 교체를 대비하나? | AVPlayer/Kollus/Future SDK가 같은 계약을 따른다 |
| 07 | POP와 Host 주입 | 서비스별 차이는 어떻게 처리하나? | protocol, capability, skin blueprint를 주입한다 |
| 08 | 명령과 상태 흐름 | Host는 무엇만 알면 되나? | command를 보내고 state를 구독한다 |
| 09 | product 경계 | SDK는 어디에 갇히나? | Kollus engine product 안에만 둔다 |
| 10 | 상태 소유권 | SDK 콜백 문제는 어떻게 막나? | reducer가 상태 전이를 소유한다 |
| 11 | capability 게이팅 | 기능 차이는 어떻게 처리하나? | 지원 가능한 기능만 UI에 노출한다 |
| 12 | Skin 커스텀 | 서비스별 UI는 어떻게 바꾸나? | block/theme/blueprint로 바꾼다 |
| 13 | DRM/VOD 배경 | 왜 SDK를 직접 만들지 않나? | VOD/DRM은 Build보다 Buy가 합리적이다 |
| 14 | Kollus/PallyCon 격리 | 구매 SDK를 어떻게 안전하게 쓰나? | adapter 내부 구현 디테일로 둔다 |
| 15 | 현재 검증 상태 | 지금 믿을 수 있나? | 테스트/Example/실기기 QA 범위를 분리했다 |
| 16 | 데모 | 실제로 동작하나? | HLS, Kollus, 다운로드, Skin 제스처로 증명한다 |
| 17 | 남은 한계 | 아직 안 되는 건 뭔가? | PiP, 실기기 QA, UX 정렬이 남았다 |
| 18 | 결정 요청 | 오늘 무엇을 결정하나? | 구조 승인, 파일럿 범위, 정책 추천안 |
| 19 | 파일럿 계획 | 어떻게 위험 없이 적용하나? | feature flag로 host 1개 화면부터 시작한다 |
| 20 | 마무리 | 그래서 다음 액션은? | 승인되면 공통 모듈 파일럿으로 간다 |

## 개정 슬라이드 원고 v2

이 섹션을 HTML 개편 기준으로 사용한다. v1은 블로그 중심 설명안이고, v2는 팀원 설득형 발표안이다.

### 01. 왜 지금 플레이어 모듈화인가

화면 문구:

- Title: 왜 지금 플레이어 모듈화인가
- Lead: 여러 서비스가 각자 다시 붙이던 플레이어를, 공통 재생 모듈로 재사용 가능하게 만들기 위해서입니다.
- Keywords: 고등 서비스 / 유초등 / 해외사업부 / 네이티브 재구현 / 중복 비용

발표자 메모:

이 발표는 "새 플레이어를 만들었다"가 아니라 "팀이 반복해서 치르고 있는 플레이어 비용을 줄이자"는 이야기다. 고등 서비스에는 오래된 플레이어 코드가 있고, 다른 서비스들은 각자 네이티브 플레이어를 다시 붙이고 있다. 이 구조가 계속되면 같은 문제를 서비스마다 다시 풀게 된다.

추천 시각 자료:

- `player-module-review-ios-visual-guide.md`의 `01. 서비스별 플레이어 중복 구조`

### 02. 현재 구조의 비용

화면 문구:

Title: 문제는 재생 코드가 아니라, 반복되는 유지보수 비용입니다.

| 반복되는 일 | 지금 발생하는 비용 |
| --- | --- |
| 제스처/자막/배속 정책 | 서비스별로 다시 구현하고 다시 맞춤 |
| DRM/다운로드 대응 | 실기기 이슈를 서비스마다 따로 추적 |
| SDK 버전 대응 | 각 앱의 빌드/링크/런타임 영향 범위가 커짐 |
| UX 정렬 | 고등, 유초등, 해외 서비스가 서로 다른 플레이어 경험을 가짐 |

발표자 메모:

각 서비스가 독립적으로 움직이는 건 빠르게 보일 수 있지만, 플레이어처럼 복잡한 영역에서는 중복 비용이 누적된다. 기능 하나를 추가해도 모든 서비스가 같은 판단을 반복한다.

추천 시각 자료:

- `02. 서비스별 중복 비용 맵`

### 03. 목표는 공통 재사용 모듈

화면 문구:

Title: 목표는 "한 번 만들고, 여러 서비스가 재사용"하는 구조입니다.

Bullets:

- 재생 상태와 명령은 공통 Core가 소유한다.
- 서비스별 UI 차이는 Skin block과 theme으로 조립한다.
- SDK별 차이는 Engine adapter가 흡수한다.
- Host 앱은 재생 의도와 화면 정책만 주입한다.

발표자 메모:

우리가 만들려는 건 특정 서비스 전용 플레이어가 아니다. 공통 상태 머신, 공통 엔진 계약, 조립 가능한 UI를 제공하고, 서비스는 필요한 정책과 UI를 주입하는 구조다.

추천 시각 자료:

- `03. 공통 모듈 재사용 구조`

### 04. 단순 SDK wrapper로는 부족하다

화면 문구:

Title: SDK 호출을 감싸는 wrapper만으로는 부족합니다.

| wrapper 방식 | 모듈 방식 |
| --- | --- |
| SDK API 모양을 거의 따라감 | 우리 도메인의 command/state를 먼저 정의 |
| SDK 교체 시 wrapper와 host가 같이 흔들림 | engine adapter만 교체 |
| 서비스별 커스텀은 분기와 옵션으로 증가 | protocol과 blueprint 주입으로 확장 |
| 테스트가 SDK 동작에 묶임 | 상태 전이는 SDK 밖에서 pure test |

발표자 메모:

단순 wrapper는 SDK 의존을 감추는 것처럼 보이지만, 실제로는 SDK의 사고방식을 그대로 host에 전달할 위험이 크다. 우리는 SDK를 감싸는 것이 아니라, 우리 플레이어 도메인을 먼저 세우고 SDK를 adapter로 번역해야 한다.

추천 시각 자료:

- `04. wrapper vs module`

### 05. SDK는 사서 쓰되, 의존은 줄인다

화면 문구:

Title: SDK는 사서 쓰는 게 맞습니다. 하지만 앱이 SDK에 묶이면 안 됩니다.

Bullets:

- VOD/DRM 인프라는 직접 구현보다 Kollus/PallyCon 같은 전문 SDK를 쓰는 편이 효율적이다.
- 하지만 더 좋은 SDK, 사업부별 요구, vendor 정책 변경 가능성은 항상 남는다.
- 그래서 SDK는 engine adapter 내부에 두고, host는 SDK 타입을 몰라야 한다.

발표자 메모:

블로그에서 정리한 결론은 "SDK를 직접 만들자"가 아니다. 트랜스코딩, CDN, DRM, 라이선스 서버는 사는 게 맞다. 다만 사 온 SDK가 앱 전체 구조를 결정하게 두면 장기적으로 교체가 어려워진다.

추천 시각 자료:

- `05. SDK 구매와 의존 격리`

### 06. 자체 engine contract

화면 문구:

Title: 교체 가능하게 하려면 우리만의 engine contract가 필요합니다.

Flow:

1. Host는 `PlaybackCommand`를 보낸다.
2. Core는 정책과 capability를 협상한다.
3. Engine adapter는 AVPlayer, Kollus, 미래 SDK 중 하나로 번역한다.
4. Core는 `PlaybackState`를 계산해 Host에 돌려준다.

발표자 메모:

자체 엔진이라는 말은 AVPlayer나 Kollus를 직접 대체한다는 뜻이 아니다. Host가 바라보는 계약을 우리가 소유한다는 뜻이다. 이 계약만 지키면 현재는 Kollus, 미래에는 다른 SDK도 붙일 수 있다.

추천 시각 자료:

- `06. engine contract와 adapter`

### 07. POP와 Host 주입

화면 문구:

Title: 서비스별 차이는 protocol과 주입으로 해결합니다.

Bullets:

- 기능은 optional protocol로 나눈다.
- 지원 여부는 capability로 선언한다.
- UI는 Skin blueprint에 block을 주입한다.
- 정책은 Host가 `PlayerFeaturePolicy`로 주입한다.

발표자 메모:

고등, 유초등, 해외사업부가 모두 같은 UI와 정책을 쓰지는 않을 것이다. 그래서 상속 기반으로 거대한 플레이어를 만들지 않고, protocol과 주입 지점으로 커스텀할 수 있게 만든다.

추천 시각 자료:

- `07. POP 주입 구조`

### 08. Host가 알면 되는 것은 두 가지다

화면 문구:

Title: Host는 command를 보내고, state를 구독합니다.

Code:

```swift
try await module.core.execute(command: .play)
try await module.core.execute(command: .seek(to: time))

for await state in module.core.stateStream {
    render(state)
}
```

Takeaway:

Host는 SDK delegate, DRM callback, AVPlayer 상태 전이를 직접 소유하지 않는다.

발표자 메모:

여기서 팀원이 가져가야 할 메시지는 간단하다. 서비스 화면은 재생 의도를 보내고, 계산된 상태를 그린다. 나머지 복잡도는 모듈 내부 경계에서 처리한다.

### 09. product 경계가 SDK 경계다

화면 문구:

Title: SDK는 필요한 product 안에만 들어옵니다.

| product | 역할 | SDK 의존 |
| --- | --- | --- |
| VideoPlayerCore | 도메인, 상태, 계약 | 없음 |
| VideoPlayerEngineNative | URL/HLS 재생 | 없음 |
| VideoPlayerEngineKollus | Kollus DRM/다운로드 | Kollus/PallyCon |
| VideoPlayerSkin | 재사용 UI | 없음 |

발표자 메모:

모든 서비스가 항상 Kollus/PallyCon을 링크해야 하는 구조가 아니다. Native만 필요한 화면은 Native product를, Kollus가 필요한 화면은 Kollus product를 선택한다.

### 10. 상태 소유권은 SDK가 아니라 Core에 있다

화면 문구:

Title: SDK 콜백은 신호일 뿐, 상태 결정은 Core가 합니다.

Pseudo code:

```text
SDK callback -> PlayerEngineOutput
PlayerEngineOutput -> PlaybackStateInput
PlaybackStateInput + currentState -> reducer -> nextState
```

발표자 메모:

SDK 콜백 순서는 언제나 우리가 통제할 수 없다. 그래서 SDK 콜백이 화면 상태를 직접 바꾸지 못하게 하고, Core reducer가 상태 전이를 소유하게 했다.

### 11. 기능 차이는 capability로 처리한다

화면 문구:

Title: 모든 엔진이 모든 기능을 지원하지 않아도 됩니다.

Bullets:

- 배속, 자막, 북마크, PiP, 다운로드는 엔진별로 지원 범위가 다를 수 있다.
- 모듈은 지원 가능한 기능만 Host/Skin에 노출한다.
- 미지원 기능은 눌러보고 실패하는 UX가 아니라 시작 시점에 게이트한다.

발표자 메모:

서비스별, SDK별 기능 차이를 없애겠다는 게 아니다. 차이를 명시하고 안전하게 다루겠다는 것이다.

### 12. UI는 Skin blueprint로 커스텀한다

화면 문구:

Title: 공통 플레이어지만, 서비스별 UI는 바꿀 수 있어야 합니다.

Code:

```swift
let blueprint = PlayerSkinBlueprint(
    blocks: [
        .topCenter: [{ TitleBlock() }],
        .centerControls: [{ CenterPlaybackControlsBlock() }],
        .bottomBar: [{ ProgressBarBlock() }]
    ],
    visibleSlots: [
        .fullScreen: [.topCenter, .centerControls, .bottomBar]
    ]
)

let skin = AssembledPlayerSkin(
    blueprint: blueprint,
    theme: serviceTheme
)
```

발표자 메모:

공통 모듈이 곧 모든 서비스가 똑같은 UI를 써야 한다는 뜻은 아니다. 공통 상태와 공통 액션 위에 서비스별 skin을 조립할 수 있게 한다.

### 13. 왜 SDK를 직접 구현하지 않는가

화면 문구:

Title: VOD/DRM은 직접 구현보다 구매가 합리적입니다.

Cards:

- Kollus: 트랜스코딩, CDN, DRM 패키징, 운영 어드민
- PallyCon: FairPlay 라이선스, SPC/CKC, persistent license
- 우리 팀: 학습 경험, 화면 정책, 재생 상태 모델, SDK 격리

발표자 메모:

여기서 블로그 내용을 연결한다. 우리가 SDK를 줄인다는 건 SDK를 안 쓰겠다는 뜻이 아니다. 사서 쓰되, SDK가 host 앱 구조를 결정하지 못하게 하는 것이다.

### 14. 구매 SDK는 adapter 내부 구현으로 둔다

화면 문구:

Title: SDK 교체 가능성은 adapter 경계에서 나옵니다.

Flow:

`PlaybackCommand` -> `PlayerCore` -> `PlayerEngineAdapter` -> `KollusSDK / FutureSDK`

Takeaway:

미래에 더 좋은 SDK가 생기면 Host 화면을 바꾸는 것이 아니라 engine adapter를 추가하거나 교체한다.

발표자 메모:

SDK 교체가 하루 만에 된다는 뜻은 아니다. 다만 교체 영향 범위를 화면 전체가 아니라 engine product로 제한하는 구조를 만든다는 뜻이다.

### 15. 현재 검증 상태

화면 문구:

Title: 공통 모듈로 쓰려면 검증 경계도 분리되어야 합니다.

| 검증 | 방법 |
| --- | --- |
| 상태 전이 | reducer pure test |
| SDK 이벤트 매핑 | signal mapper test |
| SDK 침투 방지 | boundary test |
| 통합 패턴 | Example app |
| DRM/다운로드 | 실기기 QA |

발표자 메모:

여러 서비스가 재사용하려면 "한 화면에서 돌아간다"만으로는 부족하다. 자동으로 검증할 수 있는 것과 실기기로 확인할 것을 나눠야 한다.

### 16. 데모

화면 문구:

Title: 데모는 기능이 아니라 구조를 보여줍니다.

| 데모 | 확인할 구조 |
| --- | --- |
| HLS 재생 | Native engine과 공통 state |
| Kollus DRM | SDK 격리와 engine 교체 |
| 다운로드/오프라인 | DRM 사전 검증 |
| Skin 제스처 | 서비스별 UI 조립 가능성 |

발표자 메모:

데모의 목적은 멋진 기능 소개가 아니라, 앞에서 말한 구조가 실제로 작동한다는 것을 보여주는 것이다.

### 17. 남은 한계

화면 문구:

Title: 아직 닫아야 할 부분도 명확합니다.

Bullets:

- Kollus PiP는 현재 capability로 열지 않는다.
- DRM/다운로드/백그라운드 오디오는 실기기 QA가 필요하다.
- 고등 서비스 기준 UX와 새 Skin의 제스처/HUD 정렬이 더 필요하다.
- Host 파일럿 전 실제 API 예시와 숫자를 재검증해야 한다.

발표자 메모:

한계를 숨기지 않는다. 대신 이 한계가 구조 실패인지, 검증 또는 정책 결정의 문제인지 분리한다.

### 18. 오늘 결정할 것

화면 문구:

Title: 오늘 결정하고 싶은 것은 세 가지입니다.

| 결정 | 추천안 |
| --- | --- |
| 공통 모듈 방향 | Core/Engine/Skin 구조 승인 |
| 파일럿 범위 | host 1개 화면부터 feature flag로 적용 |
| 정책 차이 | 기존 UX 기준으로 정렬하되 Host override 허용 |

발표자 메모:

회의가 기술 토론으로 흩어지지 않게 결정 항목을 줄인다. 구조 승인, 파일럿 범위, 정책 차이 처리 방식만 닫으면 다음 단계로 갈 수 있다.

### 19. 파일럿 계획

화면 문구:

Title: 전면 교체가 아니라, 되돌릴 수 있는 파일럿으로 시작합니다.

Flow:

1. Example app에서 통합 패턴 확인
2. host 1개 화면에 feature flag 적용
3. 실기기 QA와 기존 UX 정렬
4. 결과 리뷰 후 확대 여부 결정

발표자 메모:

여러 서비스 재사용을 목표로 하더라도 첫 적용은 작게 시작해야 한다. 성공 기준과 rollback 조건을 미리 정한다.

### 20. 마무리

화면 문구:

Title: 여러 서비스가 다시 만들지 않도록, 공통 플레이어 모듈로 가겠습니다.

Closing:

오늘 승인되면 다음 스프린트에 host 파일럿을 시작하고, 이후 유초등/해외사업부까지 재사용 가능한 경계로 확장합니다.

발표자 메모:

마지막 문장은 다시 팀 문제로 돌아와야 한다. 이 설계는 기술적으로 멋있기 위해서가 아니라, 여러 서비스가 같은 플레이어를 다시 만들지 않게 하기 위한 것이다.

## 개정 슬라이드 원고 v1

이 섹션은 `docs/blog`의 논리를 반영한 발표 원고 초안이다. 현재 HTML 개편 기준은 위의 v2를 우선한다.

### 01. 영상 재생 모듈 기술 사양 리뷰

화면 문구:

- Eyebrow: `videoplayer-ios-ms · iOS engineering review · 2026-06-12`
- Title: 영상 재생 모듈 기술 사양 리뷰
- Lead: DRM/VOD/vendor 복잡도를 앱 화면 밖으로 격리하고, host 앱은 재생 의도와 상태만 다루게 만드는 설계입니다.
- Badges: 설계 승인 요청 / 라이브 데모 포함 / 파일럿 범위 결정

발표자 메모:

오늘은 "플레이어를 새로 만들었다"가 아니라, 교육 서비스 영상 재생의 복잡도를 어떤 경계로 나눌지 승인받는 자리다.

### 02. 오늘 승인받고 싶은 것

화면 문구:

| 결정 | 내용 |
| --- | --- |
| 구조 승인 | Core, Engine, Skin, vendor product 경계를 팀 표준으로 승인 |
| 정책 결정 | HUD, 자막 범위, UseCase 제거, PiP, 남은 상태 전이 이슈 처리 |
| 파일럿 착수 | 다음 스프린트에 host 앱 1개 화면을 플래그 기반으로 적용 |

발표자 메모:

세부 기술 토론은 하되, 회의의 결론은 세 가지로 닫고 싶다. 구조를 승인할지, 정책 차이를 어떻게 맞출지, 실제 host 화면에 언제 넣을지다.

### 03. 강의 재생은 URL 하나가 아니다

화면 문구:

Title: 강의 재생은 `AVPlayer(url:)`에서 끝나지 않습니다.

Bullets:

- 유료 강의는 수강 권한, 콘텐츠 보호, 기기 보안, 다운로드 만료를 함께 다룬다.
- FairPlay Streaming은 콘텐츠 키를 앱 코드에 노출하지 않고 보호된 재생 경로에서 처리한다.
- 오프라인 강의는 persistent license와 만료 검증까지 포함한다.

발표자 메모:

처음 보면 영상 재생은 URL을 넣고 play를 호출하는 일처럼 보인다. 하지만 강의 앱에서는 "볼 권리가 있는가", "저장된 콘텐츠가 아직 유효한가", "키가 앱 밖으로 새지 않는가"가 모두 재생 요구사항이다.

### 04. HLS DRM은 SPC/CKC 흐름을 가진다

화면 문구:

Title: 앱은 키를 해석하지 않고, 안전하게 전달해야 합니다.

Flow:

1. m3u8에서 `#EXT-X-KEY`와 `skd://` 신호 발견
2. AVFoundation/FPS가 SPC 키 요청 생성
3. SDK가 라이선스 서버에 SPC 전달
4. 서버가 권한 확인 뒤 CKC 응답
5. AVFoundation이 보호된 경로에서 복호화와 디코딩 수행

Takeaway:

우리 코드의 역할은 키를 직접 다루는 것이 아니라, 이 흐름을 SDK 경계 안에 가두고 실패를 도메인 에러로 번역하는 것이다.

발표자 메모:

SPC와 CKC는 앱이 내용을 해석하는 데이터가 아니다. 앱은 메시지를 전달하고, 최종 키 처리는 AVFoundation/FPS가 담당한다. 이 특성 때문에 DRM 흐름은 화면 코드가 아니라 엔진 경계에 있어야 한다.

### 05. Kollus와 PallyCon은 Build-vs-Buy 결과다

화면 문구:

Title: 우리는 영상 인프라를 직접 짓지 않기로 선택했습니다.

Cards:

- Kollus: 트랜스코딩, CDN, DRM 패키징, 분석, 운영 어드민을 제공하는 VOD 플랫폼
- PallyCon: FairPlay 라이선스 발급과 persistent license 처리를 맡는 DRM SaaS
- videoplayer-ios-ms: vendor를 대체하지 않고, vendor 의존을 host 앱 밖으로 격리

발표자 메모:

Kollus와 PallyCon을 쓰는 선택은 합리적이다. 문제는 그 SDK가 화면과 도메인 코드 전체에 퍼지는 순간, 나중에 교체와 디버깅 비용이 폭발한다는 점이다.

### 06. 문제는 vendor가 아니라 vendor 침투다

화면 문구:

Title: 기존 구조는 화면이 너무 많은 것을 알고 있었습니다.

Bullets:

- 화면 클래스가 SDK delegate, UI 상태, DRM/다운로드, 진단 콜백을 함께 처리했다.
- 상태가 여러 프로퍼티와 콜백에 흩어져 재생 종료 후 상태 역전 같은 문제가 생겼다.
- vendor 변경 가능성이 코드 레벨에서 낮아졌다.

Bug card:

- 상태 역전: 영상 종료 뒤 늦은 buffering 해제 콜백이 도착하면 playing 상태가 되살아날 수 있었다.

발표자 메모:

SDK를 쓰는 것 자체가 문제가 아니다. SDK의 책임이 화면에 직접 섞인 것이 문제다. 그래서 목표는 SDK 제거가 아니라 SDK 격리다.

### 07. 설계 원칙: vendor는 쓰되, 앱 코드는 vendor를 몰라야 한다

화면 문구:

Title: vendor는 쓰되, 앱 코드는 vendor를 몰라야 합니다.

Principles:

- 엔진 교체 가능성: AVPlayer와 Kollus는 같은 engine contract 뒤에 둔다.
- 단방향 상태 흐름: 화면은 command를 보내고 state를 구독한다.
- capability 게이팅: 미지원 기능은 시작 시점에 숨기거나 명시적으로 거부한다.
- vendor 격리: Kollus/PallyCon import는 Kollus engine product 안에만 둔다.
- Swift concurrency first: Core와 engine 상태 변경은 actor로 직렬화한다.

발표자 메모:

이 다섯 원칙은 블로그 5편에서 정리한 모듈화 원칙과 같다. 발표의 나머지는 이 원칙이 코드로 어떻게 박혔는지 보여주는 증거다.

### 08. 명령과 상태는 한 방향으로 흐른다

화면 문구:

Title: 화면은 명령만 보내고, 상태만 구독합니다.

Flow:

1. Host/Skin: `PlaybackCommand` 발행
2. `PlayerCore` actor: 정책과 capability 협상
3. Engine Adapter: AVPlayer 또는 Kollus SDK 호출
4. Signal Mapper: SDK 이벤트를 엔진 중립 신호로 변환
5. Reducer: `PlaybackState` 계산
6. Host/Skin: 상태 렌더

발표자 메모:

화면이 SDK 콜백을 직접 받지 않는다. 마지막 command와 마지막 state만 보면 디버깅을 시작할 수 있는 구조가 된다.

### 09. product 경계가 vendor 경계다

화면 문구:

Title: product 경계가 vendor 경계입니다.

| product | 역할 | vendor 의존 |
| --- | --- | --- |
| VideoPlayerCore | 도메인 타입, 상태 머신, 엔진 계약 | 없음 |
| VideoPlayerShellSupport | wiring, render surface, lifecycle | 없음 |
| VideoPlayerEngineNative | AVPlayerAdapter | 없음 |
| VideoPlayerEngineKollus | KollusAdapter, DRM, 다운로드 | Kollus/PallyCon |
| VideoPlayerSkin | 재사용 UI | 없음 |

Takeaway:

Kollus/PallyCon은 앱 전체 의존성이 아니라 Kollus engine product의 구현 디테일이다.

발표자 메모:

PallyCon은 우리 Swift 코드에 직접 등장하지 않고, Kollus 경로의 link dependency로만 들어온다. 이 구조가 vendor 격리의 핵심이다.

### 10. 상태 전이는 SDK 밖에서 검증한다

화면 문구:

Title: 상태는 SDK 콜백이 아니라 Core reducer가 결정합니다.

Code:

```swift
func reduce(_ input: PlaybackStateInput, _ state: PlaybackState)
    -> (next: PlaybackState, events: [PlayerEvent])
```

Bullets:

- 엔진은 raw SDK 이벤트를 직접 상태로 쓰지 않고 `PlayerEngineOutput`만 발행한다.
- reducer가 terminal 상태, buffering, seek, failure 전이를 한 곳에서 결정한다.
- 순수 로직은 vendor SDK 없이 macOS `swift test`로 검증한다.

발표자 메모:

핵심은 상태 전이를 SDK 밖으로 꺼냈다는 것이다. SDK 콜백 순서가 흔들려도 Core가 invariant를 지킨다.

### 11. capability로 기능을 사전 게이트한다

화면 문구:

Title: 눌러보고 실패하는 기능을 만들지 않습니다.

Cards:

- EngineCapabilities: 백그라운드 재생, surface 유지, PiP 같은 엔진 특성 선언
- Optional protocols: 배속, 자막, 북마크, 미리보기, 디스플레이, 다운로드 등 기능별 지원 선언
- PlayerFeatureAvailability: 앱 정책과 엔진 지원의 교집합만 UI에 노출

발표자 메모:

AVPlayer와 Kollus는 지원 기능이 다르다. 그래서 UI가 "버튼은 있는데 누르면 실패"하는 구조가 아니라, 시작 시점에 가능한 기능만 보여주는 구조가 필요하다.

### 12. 기존 문제는 이렇게 줄었다

화면 문구:

| 기존 구조의 문제 | 모듈 설계 |
| --- | --- |
| SDK delegate를 화면이 직접 관리 | adapter actor와 signal mapper로 단일 output stream 구성 |
| 상태 역전 버그 | reducer가 terminal 상태 전이를 보호 |
| 실기기 없이는 검증 어려움 | 순수 상태/매핑 로직은 macOS 테스트로 분리 |
| SDK import가 화면까지 침투 | Core/Shell/Skin은 SDK 비의존, boundary test로 차단 |
| 만료 다운로드를 재생 후 감지 | 오프라인 재생 전 DRM 조건을 사전 검증 |

발표자 메모:

각 문제를 기능 하나로 땜질한 게 아니라, 경계를 바꿔서 문제의 위치를 줄였다.

### 13. 현재 검증 상태

화면 문구:

Title: 현재 상태는 리뷰 가능한 수준입니다.

Stats:

- Swift source files: 발표 전 재확인
- Tests passing: 발표 전 `swift test`로 재확인
- SPM products: Core, ShellSupport, Native, Kollus, Skin
- Example app: 조립, 설정, 다운로드, 관찰 로그 시연 가능

Cards:

- 자동 검증: reducer, signal mapper, boundary, pure logic
- 수동 검증 필요: DRM, 다운로드, 백그라운드 오디오, 실기기 gesture

발표자 메모:

숫자는 발표 당일 다시 돌려서 넣는다. 여기서는 자동화로 닫을 수 있는 것과 실기기로만 닫을 수 있는 것을 분리해 보여주는 게 중요하다.

### 14. AVPlayer 사용 예

화면 문구:

Title: 일반 URL/HLS는 Native engine으로 조립합니다.

Code note:

```swift
let module = await PlayerModuleWiring.makeModule(
    engine: AVPlayerAdapter(),
    engineCapabilities: AVPlayerAdapter.capabilities
)

for await state in module.core.stateStream {
    render(state)
}

try await module.core.start(source: .url(videoURL), policy: .default)
try await module.core.execute(command: .play)
```

Takeaway:

host는 재생 의도와 상태 렌더링만 다룬다.

발표자 메모:

실제 public API와 순서는 HTML 반영 전에 코드에서 재확인한다. 발표 목적은 "host가 engine 내부 구현을 모른다"는 점을 보여주는 것이다.

### 15. Kollus 사용 예

화면 문구:

Title: Kollus도 조립 지점만 다릅니다.

Code note:

```swift
let environment = KollusEnvironment(
    applicationKey: key,
    applicationBundleID: bundleID,
    applicationExpireDate: expireDate,
    storagePath: storagePath,
    drm: drmConfiguration
)
try environment.validate()

let factory = KollusPlayerModuleFactory(environment: environment)
let module = await factory.makeModule()

try await module.core.start(source: .mediaKey(mck), policy: .default)
```

Takeaway:

화면 코드는 KollusSDK나 PallyConFPSSDK 타입을 알 필요가 없다.

발표자 메모:

강제 언래핑이나 실제 API와 다른 타입명은 발표 코드에서 피한다. 이 예시는 코드 검증 후 확정한다.

### 16. Skin은 엔진을 모른다

화면 문구:

Title: UI는 엔진이 아니라 상태와 액션에 붙습니다.

Bullets:

- 슬롯 기반 blueprint로 top, center, progress, bottom 블록을 조립한다.
- 서비스별 버튼/제스처 차이를 모듈 fork 없이 block과 theme으로 처리한다.
- Skin은 `PlayerSkinAction`과 `PlayerSkinState`만 알고, AVPlayer/Kollus를 모른다.

발표자 메모:

Skin은 예쁜 UI 컴포넌트가 아니라 host 화면 차이를 흡수하는 경계다. 엔진 교체와 독립적으로 UI를 유지하는 것이 핵심이다.

### 17. 라이브 데모

화면 문구:

Title: 네 가지로 설계를 증명하겠습니다.

| 데모 | 증명할 것 |
| --- | --- |
| HLS 재생 | 공통 command/state 흐름 |
| Kollus DRM 재생 | engine 교체와 vendor 격리 |
| 다운로드 + 오프라인 | DRM 사전 검증과 download center |
| Skin 제스처 | 엔진 독립 UI 조립 |

Backup:

Kollus DRM/다운로드는 실기기와 네트워크 의존성이 있어 사전 녹화 영상을 준비한다.

발표자 메모:

데모는 기능 자랑이 아니라 설계 증명이다. 각 데모가 어떤 원칙을 보여주는지 먼저 말하고 시연한다.

### 18. 품질 가드와 남은 한계

화면 문구:

Title: 자동화로 닫을 것과 실기기로 닫을 것을 나눴습니다.

| 구분 | 현재 가드 |
| --- | --- |
| 모듈 경계 | SDK/서비스 용어 침투 boundary test |
| 상태 전이 | reducer와 signal mapper pure logic test |
| 패키징 | Vendor 원본 불변, XCFramework 재생성 스크립트, checksum 검증 |
| 실기기 QA | DRM, 다운로드, 백그라운드 오디오, 기존 UX 정렬 체크리스트 |

남은 한계:

- Kollus PiP는 현재 capability로 광고하지 않는다.
- Skin block 렌더링/제스처 테스트는 iOS destination 보강이 필요하다.
- 기존 UX 정렬은 host 화면 적용 전 한 차례 더 확인해야 한다.

발표자 메모:

한계를 숨기지 않는다. 대신 어떤 것은 설계상 보류인지, 어떤 것은 검증이 남은 것인지 구분한다.

### 19. 결정 요청

화면 문구:

Title: 오늘 결정이 필요한 항목입니다.

| # | 항목 | 추천안 |
| --- | --- | --- |
| D1 | 설계 구조 | Core/Engine/Skin/vendor product 경계를 승인 |
| D2 | 파일럿 범위 | 다음 스프린트 host 1개 화면, feature flag 병행 |
| D3 | HUD/자막 기본값 | 기존 UX 기준으로 정렬하되 host override 허용 |
| D4 | PiP | 모듈 내장 보류, host 통합 가능성 별도 검토 |
| D5 | 남은 상태 전이 이슈 | 파일럿 전 reducer test와 함께 우선 처리 |

발표자 메모:

정책 결정을 열어두기보다 추천안을 같이 가져간다. 회의에서는 이 추천안에 대해 승인/수정만 받는 형태로 진행한다.

### 20. 파일럿 제안과 마무리

화면 문구:

Title: 승인되면 다음 스프린트에 되돌릴 수 있게 적용합니다.

Flow:

1. Example app으로 통합 패턴 검증
2. host 앱 1개 화면을 feature flag로 병행 적용
3. 실기기 QA와 기존 UX 정렬
4. 결과 리뷰 후 적용 범위 확대

Closing:

오늘은 구조 승인, 정책 추천안, 파일럿 범위만 결정하면 됩니다.

발표자 메모:

마지막은 실행 계획으로 닫는다. 전면 전환이 아니라 되돌릴 수 있는 파일럿이므로 리스크가 제한적이라는 점을 강조한다.

---

## 01. 타이틀

### 현재 화면 문구

Eyebrow: `videoplayer-ios-ms — engineering review · 2026-06-12`

Title: 영상 재생을 모듈로 만들었습니다.

Lead:

공통 상태 머신과 교체 가능한 재생 엔진.  
기술 사양 승인과 엔지니어링 리뷰를 요청합니다.

Badges:

- 발표 30분 + Q&A
- 라이브 데모 포함
- iOS 팀 심화판

### 개선 후보

- "모듈로 만들었습니다"는 결과 중심이라 좋지만, 회의 목적이 약간 늦게 나온다.
- 첫 장에서 "승인 요청"과 "리뷰 범위"를 더 선명하게 보여줄 수 있다.
- 발표 제목 후보:
  - 영상 재생 모듈 기술 사양 리뷰
  - videoplayer-ios-ms 설계 승인 리뷰
  - 공통 플레이어 모듈, 이제 팀 리뷰 단계입니다

---

## 02. 오늘 결정할 것

### 현재 화면 문구

Title: 오늘 이 회의에서 결정할 것.

Cards:

- 설계 승인: API 표면 · 모듈 경계 · 상태 소유권 모델. "이 구조로 간다"는 합의.
- 정책 결정 5건: HUD 표시 시간, 자막 폰트 범위, UseCase 레이어, PiP 범위, reducer 보류 버그.
- 마이그레이션 착수: host 앱 파일럿 화면 1개 선정과 일정 합의.

Footer:

순서 — 왜 만들었나 → 어떻게 설계했나 → 무엇이 해결됐나 → 데모 → 한계와 결정 요청.

### 개선 후보

- "오늘 결정할 것"은 좋은 아젠다다. 다만 5건 정책 결정이 너무 구체적으로 빨리 나온다.
- 초반에는 "리뷰 범위"와 "결정 범위"를 나누면 청중이 따라오기 쉽다.
- D5 reducer 버그는 "보류 버그"라고 말하면 방어적으로 들릴 수 있다. "남은 상태 전이 이슈 처리 시점"이 더 중립적이다.

---

## 03. 문제 1: 화면 하나가 모든 것을 알고 있음

### 현재 화면 문구

Title: 화면 하나가 모든 것을 알고 있었습니다.

Bullets:

- SDK 델리게이트 26개를 ViewController가 직접 처리 — 재생·DRM·다운로드·진단 콜백이 한 클래스에.
- 상태가 분산 — UI 상태, SDK 콜백 상태, 렌더 상태가 서로 다른 프로퍼티에 흩어짐.
- god object — 화면 코드와 재생 로직과 학습 플랫폼 용어가 한 파일에서 성장.

Bug card:

- 실제 버그 사례: 상태 역전
- 영상이 끝난 뒤에 버퍼링 해제 콜백이 도착하면 재생 상태가 되살아남. SDK 콜백 순서는 보장되지 않는데, 이를 막는 단일 지점이 레거시엔 없었습니다.

### 개선 후보

- 이 슬라이드는 발표의 문제 정의 핵심이다.
- "god object"는 개발자에게 통하지만 발표 톤에서는 "거대 ViewController"가 더 자연스럽다.
- 상태 역전 버그는 구체적이고 좋다. 단, 이 버그가 사용자 경험에 어떤 영향을 주는지 한 줄 추가하면 설득력이 올라간다.

---

## 04. 문제 2: 고칠수록 비싸지는 구조

### 현재 화면 문구

Title: 고칠수록 비싸지는 구조.

Cards:

- 테스트 불가: SDK 없이 상태 전이를 검증할 방법이 없음. 모든 재생·DRM 로직은 실기기에서만 확인 가능.
- SDK 강결합: KollusSDK · PallyCon import가 화면 코드까지 침투. 엔진 교체 = 화면 전면 수정.
- 오프라인 사후 감지: 만료된 다운로드 콘텐츠는 재생을 시도해 본 뒤에야 실패를 알 수 있었음.
- 재현 불가 패키징: SDK 바이너리 산출물 관리가 수작업 — 버전 교체 절차가 사람 기억에 의존.

### 개선 후보

- 네 가지 문제는 좋지만 범위가 넓다. 발표에서는 "개발 비용", "품질 위험", "교체 비용" 세 축으로 묶을 수 있다.
- "재현 불가 패키징"은 중요하지만 플레이어 설계 승인과 거리가 있어 뒤쪽 품질 가드로 이동하는 선택도 가능하다.

---

## 05. 핵심 아이디어

### 현재 화면 문구

Title: 화면은 의도만, 엔진은 방법만, 상태는 순수 함수가.

Lead:

host는 PlaybackSource · PlaybackCommand · PlaybackState만 다룹니다.  
실제 재생은 AVPlayerAdapter나 KollusPlayerAdapter가 맡습니다.

### 개선 후보

- 핵심 문장으로 매우 좋다.
- "상태는 순수 함수가"는 문장으로는 압축적이지만 약간 끊긴다. 후보:
  - 상태는 Core가 계산합니다.
  - 상태는 reducer가 결정합니다.
  - 상태는 순수 함수로만 바뀝니다.

---

## 06. 명령 흐름

### 현재 화면 문구

Title: 명령은 한 방향으로만 흐릅니다.

Flow:

1. Shell (화면): `.play / .seek(to:)` — 의도만 발행
2. PlaybackCommand
3. PlayerCore — actor: 정책 · capability 협상 후 위임
4. async throws
5. Engine Adapter: AVPlayerAdapter / KollusPlayerAdapter — SDK 호출
6. PlayerEngineOutput — 단방향 신호
7. PlaybackStateReducer — 순수 함수: 신호 → 다음 상태 계산
8. AsyncStream<PlaybackState>
9. Shell (화면): 상태 구독 → 렌더

### 개선 후보

- 구조는 명확하다. 다만 슬라이드 안 텍스트가 많아서 발표자가 흐름을 읽게 될 수 있다.
- 화면에는 5단계로 줄이고, 발표 멘트에서 세부 타입명을 보충하는 방식이 더 좋다.
- "Shell" 용어는 팀원이 바로 이해하는지 확인 필요. 필요하면 "화면/Host" 병기.

---

## 07. 모듈 그래프

### 현재 화면 문구

Title: 5개 product, 의존은 아래로만.

Table:

| product | 역할 | 의존 |
| --- | --- | --- |
| VideoPlayerCore | 상태 머신 · 도메인 타입 · 엔진 계약 | 없음 — SDK·UIKit 모름 |
| VideoPlayerShellSupport | wiring · render surface · lifecycle | Core |
| VideoPlayerEngineNative | AVPlayerAdapter — URL/HLS | ShellSupport |
| VideoPlayerEngineKollus | Kollus + DRM + 다운로드 | ShellSupport + KollusSDK |
| VideoPlayerSkin | 재사용 플레이어 UI | Core + ShellSupport — 엔진 모름 |

Note:

`import KollusSDK`는 VideoPlayerEngineKollus 안에서만. 위반은 boundary 테스트가 빌드에서 차단합니다.

### 개선 후보

- 제품 경계 승인용 핵심 슬라이드다.
- "의존은 아래로만"이라고 말하지만 표만으로는 방향이 시각적으로 약할 수 있다.
- Core가 SDK/UIKit을 모른다는 점과 Skin이 엔진을 모른다는 점을 강조해야 한다.

---

## 08. 상태 머신

### 현재 화면 문구

Title: 상태를 움직이는 신호는 단 7종.

Code:

```swift
enum PlaybackStateInput {
    case prepared(snapshot)
    case playStarted, pauseStarted
    case bufferingChanged(Bool)
    case positionChanged(time, duration)
    case seeking(time)
    case stopped(reason), failed(error)
}

func reduce(_ input, _ state)
    -> (next: PlaybackState, events: [PlayerEvent])
```

Bullets:

- 순수 함수 — SDK 없이 macOS swift test로 밀리초 단위 검증.
- invariant 보호 — finished 이후 bufferingChanged(false)가 와도 playing으로 부활하지 않음.
- 상태 소유권은 Core에 — 엔진은 신호만 발행, 상태를 직접 쓰지 못함.

### 개선 후보

- 코드 예시는 좋다. 단, "단 7종"은 enum case 그룹 기준인지 실제 케이스 수인지 애매하다.
- "밀리초 단위 검증"은 테스트 속도를 말하는지 시간 정밀도를 말하는지 모호하다.
- 핵심은 "상태 전이를 SDK 밖으로 꺼냈다"로 잡는 것이 더 명확하다.

---

## 09. 엔진 계약

### 현재 화면 문구

Title: 필수 계약 1개, 선택 계약 12개.

Cards:

- mandatory / PlayerEngineAdapter: prepare · play · pause · seek · stop — 전 명령 async throws. 실패 가능성을 숨기지 않습니다.
- optional × 12 / 기능별 프로토콜: rate · subtitle · bookmark · zoom · streaming · PiP · display · metadata · preview · background audio …
- 기능 가용성 사전 협상 — PlayerFeatureAvailability: 앱 정책(PlayerFeaturePolicy) ∩ 엔진 실제 지원(EngineCapabilities) = 화면에 노출할 기능. Skin 버튼이 시작 시점에 게이트됩니다 — 눌러보고 실패하는 UX 없음.

### 개선 후보

- 설계의 유연성을 보여주는 좋은 슬라이드다.
- "선택 계약 12개"는 숫자가 바뀔 가능성이 있으므로 실제 코드와 재확인 필요.
- "눌러보고 실패하는 UX 없음"은 청중에게 바로 와닿는 문장이라 유지 가치가 높다.

---

## 10. 문제에서 설계로 1

### 현재 화면 문구

Title: 레거시 문제 → 설계 요소 매핑.

| 레거시 문제 | 해결 |
| --- | --- |
| 델리게이트 26개 직접 관리 | adapter actor + 델리게이트 브릿지 — 단일 FIFO 스트림으로 순서 보장 |
| 상태 역전 버그 | reducer가 입력별 invariant 보호 — terminal 상태 전이 차단 |
| 실기기에서만 테스트 | 순수 로직은 macOS swift test — 232개 테스트 통과 |
| SDK 강결합 | Core·Shell·Skin은 SDK 무지 — boundary 테스트가 위반 차단 |

### 개선 후보

- 앞의 문제 슬라이드와 직접 연결되어 좋다.
- "레거시 문제"라는 표현은 발표 자료에서는 괜찮지만, 팀 리뷰 톤에서는 "기존 구조의 문제"가 덜 방어적이다.
- "SDK 무지"는 구어체라 "SDK 비의존"이 더 문서적이다.

---

## 11. 문제에서 설계로 2

### 현재 화면 문구

Title: 재생 품질 이슈도 같은 원리로.

| 레거시 문제 | 해결 |
| --- | --- |
| play 직후 배속 설정 실패 | emitsObservedCommandState capability — 엔진별 콜백 권위 차이 흡수 |
| 연타 seek 끊김 | seek chase — in-flight seek 1개만 유지, 최신 목표만 추적 |
| 만료 라이선스 사후 감지 | KollusOfflinePlaybackValidator — 재생 전 DRM 4조건 사전 검증 |
| 다운로드가 앱 코드와 얽힘 | PlayerDownloadCenter 중립 프로토콜 — Kollus 타입은 조립 지점에만 |

### 개선 후보

- 실제 엔지니어링 가치가 강한 슬라이드다.
- 다만 내부 용어가 많아 발표 때 설명이 필요하다.
- "콜백 권위 차이"는 좋은 표현이지만 한 번에 이해하기 어렵다. "엔진마다 신뢰할 상태 신호가 다른 문제"로 풀 수 있다.

---

## 12. 현재 상태 숫자

### 현재 화면 문구

Title: 숫자로 보는 현재 상태.

Stats:

- 109 swift source files
- 232 tests passing
- 5 spm products
- 13 engine protocols

Cards:

- 설계 개선 P1–P7 완료: 벤더 중립 source · 중립 다운로드 계약 · 기능 협상 · 에러 분류 · DRM 사전 검증 · adapter 분해 (1200줄 → 400줄)
- Example 앱 와이어링 완성: 메인 · 플레이어 · 세팅 3화면 + 다운로드 센터 + 관찰 로그 — 실제 통합 패턴의 레퍼런스

### 개선 후보

- 숫자는 최신성 검증이 필요하다. 발표 당일 `swift test`와 파일 수를 다시 확인해야 한다.
- "232 tests passing"은 설득력 있지만, 어떤 테스트 범위인지 작은 글씨로 명시하는 게 좋다.
- "1200줄 → 400줄"도 실제 기준 파일과 시점 확인 필요.

---

## 13. Quickstart: AVPlayer

### 현재 화면 문구

Title: 일반 URL 재생 — 전부입니다.

```swift
let module = await PlayerModuleWiring.makeModule(
    engine: AVPlayerAdapter(),
    engineCapabilities: AVPlayerAdapter.capabilities)

Task { for await state in module.core.stateStream { render(state) } }

try await module.core.start(source: .url(videoURL), policy: .default)
try await module.core.execute(command: .play)
await module.engine.bind(renderSurface: myView)
```

Caption:

조립 → 구독 → 명령 → 부착. host가 알아야 할 전부.

### 개선 후보

- 사용성 증명 슬라이드다. 코드가 실제 public API와 정확히 맞는지 재확인 필요.
- `bind(renderSurface:)` 순서는 실제 권장 순서가 start/play 이후인지 확인 필요. 일반적으로 render surface binding이 더 앞에 올 수 있다.
- 화면 문구는 "전부입니다"보다 "핵심은 네 줄입니다"가 덜 과장되어 보일 수 있다.

---

## 14. Quickstart: Kollus

### 현재 화면 문구

Title: Kollus도 같은 모양 — 환경만 다릅니다.

```swift
let env = KollusEnvironment(applicationKey: key,
    applicationBundleID: bundleID, storagePath: dir,
    drm: KollusDRMConfiguration(fpsCertificateURL: cert, fpsDRMURL: drm))
try env.validate()  // 필수 값 사전 검증

let factory = KollusPlayerModuleFactory(environment: env)
let module = await factory.makeModule()
try await module.core.start(source: .mediaKey(contentKey), policy: .default)

for await event in factory.downloads!.events { /* 진행률·완료·실패 */ }
```

Caption:

start 이후 API는 AVPlayer와 동일 — 화면 코드는 엔진을 구분하지 않습니다.

### 개선 후보

- "같은 모양" 메시지가 좋다.
- `factory.downloads!` 강제 언래핑은 발표 코드로는 불안해 보일 수 있다. 실제 API가 optional이면 안전한 형태로 바꾸는 게 좋다.
- Kollus는 실기기/DRM 제약이 있으므로 "조립 지점에서만 Kollus를 안다"를 더 강조할 수 있다.

---

## 15. Skin

### 현재 화면 문구

Title: UI는 blueprint로 조립합니다.

```swift
let blueprint = PlayerSkinBlueprint(
    blocks: [
        .topCenter: [{ TitleBlock() }],
        .bottomBar: [{ ProgressBarBlock() }],
        .floatingBottomTrailing: [{ MoreButtonBlock() }]
    ],
    visibleSlots: [
        .fullScreen: [.topCenter, .bottomBar, .floatingBottomTrailing]
    ]
)

let skin = AssembledPlayerSkin(
    blueprint: blueprint,
    theme: MyBrandTheme()
)
```

Bullets:

- 슬롯 9곳에 블록 단위로 끼우고 빼기 — 포크 없이 화면별 변형.
- 색상·폰트는 토큰 — Theme 교체로 브랜드 대응.
- 엔진 의존 없음 — PlayerSkinAction / PlayerSkinState로만 통신. Rx · SnapKit 의존도 없음.

### 개선 후보

- Skin의 가치는 잘 드러난다.
- "블록 조립식"이 실제로 host가 얻는 이점으로 연결되어야 한다. 예: "서비스별 버튼 차이를 모듈 fork 없이 처리".
- Rx/SnapKit 비의존은 팀 맥락상 의미 있지만, 발표 화면에서는 작은 보조 문장으로 낮춰도 된다.

---

## 16. 라이브 데모

### 현재 화면 문구

Title: 직접 보여드리겠습니다.

Demo list:

- HLS 재생 — AVPlayerAdapter, 상태 스트림 라이브 로그.
- 엔진 스왑 — 같은 화면 코드로 Kollus DRM 재생.
- 다운로드 + 오프라인 — 진행률 스트림, 만료 사전 검증.
- Skin 제스처 — 더블탭 시킹 · 롱프레스 2배속 · 시킹 프리뷰.

Backup:

사전 녹화 영상 준비. Kollus DRM은 실기기 의존 — 네트워크 이슈 시 영상으로 즉시 전환합니다.

### 개선 후보

- 데모 슬라이드는 간결해서 좋다.
- 발표 리스크를 낮추려면 각 데모가 어떤 설계 포인트를 증명하는지 한 단어씩 붙이면 좋다.
- 예: HLS 재생=공통 상태, 엔진 스왑=경계, 오프라인=사전 검증, Skin 제스처=조립식 UI.

---

## 17. 품질 가드

### 현재 화면 문구

Title: 설계는 테스트가 지킵니다.

Cards:

- boundary 테스트: 패키지 소스에 서비스 앱 용어·SDK 침투를 빌드 시점에 차단.
- 순수 로직 테스트: Reducer · SignalMapper · ErrorClassifier — Swift Testing, macOS에서 즉시 실행.
- packaging 재현: Vendor 원본 불변 + 스크립트로 XCFramework 재생성 — checksum 검증 포함.
- 실기기 QA 체크리스트: 시뮬레이터로 못 닫는 Kollus DRM·다운로드는 문서화된 체크리스트로 검증.

### 개선 후보

- 앞에서 나온 테스트/패키징 이야기를 한곳에 모아주는 역할이다.
- "서비스 앱 용어" 차단은 왜 필요한지 짧게 설명하면 좋다. 모듈이 특정 host에 오염되지 않게 하는 장치.
- 실기기 QA는 "테스트가 지킨다"보다 "자동화 밖 검증은 체크리스트로 관리한다"에 가깝다.

---

## 18. 새 엔진 추가

### 현재 화면 문구

Title: 새 엔진 추가 — host는 한 곳만 바뀝니다.

Flow:

1. 필수 계약 구현: prepare · play · pause · seek · stop + 상태 스트림
2. 선택 프로토콜 채택: 배속·자막·북마크… 지원하는 것만
3. 신호 mapper 작성: SDK 이벤트 → PlaybackStateInput, 순수 함수로 단독 테스트
4. host는 factory 교체뿐: 화면·Skin·상태 머신 코드 변경 0줄

Footer:

AVPlayer ↔ Kollus 스왑이 Example 앱에서 이미 실증된 경로입니다.

### 개선 후보

- 확장성을 설득하는 좋은 슬라이드다.
- "코드 변경 0줄"은 과장으로 보일 수 있다. 화면 코드 기준인지 조립 코드 제외인지 명확히 해야 한다.
- "한 곳만 바뀐다"는 메시지는 유지하되, factory/wiring 지점으로 한정하면 더 정확하다.

---

## 19. 로드맵

### 현재 화면 문구

Title: 다음 확장은 설계가 이미 있습니다.

| 계획 | 상태 | 내용 |
| --- | --- | --- |
| 시킹 프리뷰 | 구현 완료 | 스크럽 중 썸네일 스프라이트 표시 |
| 스크린샷 보호 | 구현 완료 | secure 캔버스 + QA용 해제 플래그 |
| 스킨 로컬라이제이션 | 설계 완료 | 언어별 문자열 + 아이콘 변형 |
| 자막 LLM 채팅 | 설계 완료 | 자막 선택 → LLM 단어·문맥 설명 |
| 재생 테스트 콘솔 | 설계 중 | 상태·이벤트 실시간 로그 패널 |

### 개선 후보

- 로드맵은 흥미롭지만 승인 회의에서는 산만할 수 있다.
- "다음 확장"보다 "이미 설계가 받아낼 수 있는 요구"로 표현하면 현재 설계의 타당성 증거가 된다.
- LLM 채팅은 발표 주제에서 튈 수 있으므로 부록이나 한 줄로 낮추는 선택도 가능하다.

---

## 20. 한계

### 현재 화면 문구

Title: 아직 안 되는 것, 그대로 말씀드립니다.

Cards:

- PiP 미지원: Kollus adapter의 PiP capability는 현재 항상 거짓. host AVPictureInPictureController 통합은 별도 과제.
- 실기기 QA 잔여: DRM 만료·스토리지 에러 응답, 다운로드 실패 델리게이트의 error nil 가능성 — 실기기 확정 필요.
- Skin 블록 테스트 공백: 19개 블록이 스모크 테스트만 — 제스처·상태 반영 단위 테스트 미비.
- 파리티 정렬 중: 제스처 HUD 에셋 4종 누락(텍스트 fallback), HUD 시간·자막 범위 기본값이 레거시와 불일치.

### 개선 후보

- 솔직한 한계 슬라이드는 좋다.
- "미비", "불일치"는 방어적으로 들릴 수 있다. "남은 검증", "정렬 필요"처럼 다음 액션과 묶으면 좋다.
- "파리티"는 팀 안에서 통하는지 확인 필요. 발표 자료에서는 "기존 UX 정렬"이 더 명확하다.

---

## 21. 결정 요청

### 현재 화면 문구

Title: 리뷰에서 결정해 주세요 — 5건.

| # | 항목 | 선택지 |
| --- | --- | --- |
| D1 | 제스처 HUD 표시 시간 | 신규 1.2초 유지 vs 레거시 2.0초 정렬 |
| D2 | 자막 폰트 기본 범위 | 신규 14–22pt vs 레거시 10–40pt (host 주입 가능) |
| D3 | UseCase 레이어 | deprecated 3종 제거 시점 — 즉시 vs 마이그레이션 후 |
| D4 | PiP 지원 범위 | 모듈 내장 vs host 통합 vs 보류 |
| D5 | reducer 보류 버그 | 일시정지 중 버퍼링 후 종료 → playing 복귀, 수정 시점 |

### 개선 후보

- 회의 목적과 직접 연결되는 가장 중요한 슬라이드다.
- 각 결정에 "추천안"이 없으면 회의가 토론으로만 흐를 수 있다.
- 다음 버전에서는 각 항목에 `추천` 열을 추가하는 것이 좋다.

---

## 22. 마이그레이션

### 현재 화면 문구

Title: 전환은 화면 단위로, 되돌릴 수 있게.

Flow:

1. 완료: Example 앱으로 통합 패턴 검증, 232 테스트 통과
2. 파일럿 (다음 스프린트): host 화면 1개 교체 — 레거시 플레이어와 플래그로 병행
3. 점진 확대: 화면별 순차 전환, 각 단계 실기기 QA
4. 레거시 제거: MoviePlayerController 계열 삭제

### 개선 후보

- "되돌릴 수 있게"가 좋은 메시지다.
- 실제 host 앱 적용 계획이 있다면 화면 후보와 rollback 기준을 넣으면 더 실행 가능해진다.
- "레거시 제거"는 최종 목표로 두되, 발표에서는 너무 빨리 약속하지 않는 편이 안전하다.

---

## 23. 마무리

### 현재 화면 문구

Title: 승인해 주시면, 다음 스프린트에 파일럿 들어갑니다.

Lead:

설계 배경과 내부 구조는 docs/HANDOVER 01–10,  
사용 가이드는 README에 정리되어 있습니다.

CTA:

- Q&A
- docs/HANDOVER

### 개선 후보

- 종료 메시지가 실행 지향이라 좋다.
- 마지막에는 "오늘 필요한 결정"을 한 번 더 압축하면 회의 후 액션이 선명해진다.
- 후보 문구: "오늘은 설계 승인, 정책 5건, 파일럿 범위만 결정하면 됩니다."

---

## 우선 개선 순서 제안

1. 01-02: 회의 목적과 결정 항목을 더 선명하게 만든다.
2. 03-05: 문제 정의와 설계 원칙의 연결을 정리한다.
3. 06-09: 아키텍처 설명을 줄이고 핵심 타입만 남긴다.
4. 10-12: 숫자와 증거를 실제 코드/테스트 결과로 재검증한다.
5. 13-15: Quickstart 코드가 실제 public API와 맞는지 확인한다.
6. 20-22: 한계와 결정 요청을 "추천안 포함" 형태로 바꾼다.
