<!-- source: https://docs.kollus.com/dev-guide/kollus-mobile-app/scheme-option/ -->
<!-- 수집일: 2026-06-10 -->

# Kollus 모바일 앱 연동 (URL Scheme)

모바일 웹 브라우저에서 Kollus 모바일 앱이 설치된 디바이스를 대상으로 커스텀 URL Scheme(`kollus://`)을 호출하여, 플레이어를 직접 실행하거나 특정 동작을 수행할 수 있습니다.

이 문서에서는 Android와 iOS 환경에서 공통으로 지원하는 호출 옵션 및 규격을 설명합니다.

## 사전 확인 사항

- 구분자 규칙: Scheme 뒤에 ?를 붙이고, 각 파라미터는 &로 구분하여 연결합니다.
- 재생 URL 구성: 호출 시 전달할 url 파라미터 값은 플레이어 호출 규격에 맞춰 생성된 URL이어야 합니다.
  - 참고 문서: 플레이어 호출 문서를 참고하여 재생 URL을 구성하세요.
- 필수 인코딩: URL Scheme에 포함되는 모든 파라미터의 값은 반드시 URI 인코딩(Percent-encoding) 처리를 해야 합니다.

## 호출 규격

### 재생

콘텐츠를 Kollus 모바일 앱에서 즉시 재생합니다. macOS 전용 Kollus 플레이어도 모바일 앱과 동일한 URL Scheme 규격을 사용하여 호출할 수 있습니다.

#### Scheme

```text
kollus://path
```

#### 파라미터

| 파라미터 | 타입 | 설명 |
| --- | --- | --- |
| `url` | `string` | 재생 URL |

#### 호출 예시

```js
kollus://path?url=https%3A%2F%2Fv.kr.kollus.com%2Fsi%3Fjwt%3D{JWT}%26custom_key%3D{CUSTOM_KEY}%26title%3D{CUSTOM_TITLE}
```

### 다운로드

콘텐츠 파일을 Kollus 모바일 앱 내 보관함으로 다운로드합니다.

> **INFO**
>
> 기능 활성화
>
> 다운로드 기능을 사용하려면 해당 콘텐츠가 등록된 채널의 설정에서 다운로드 기능을 활성화해야 합니다.
>
> - 참고 문서: 다운로드 콜백 설정 방법

#### Scheme

```text
kollus://download
```

#### 파라미터

| 파라미터 | 타입 | 설명 |
| --- | --- | --- |
| `url` | `string` | 다운로드할 콘텐츠의 재생 URL |
| `folder` | `string` | (선택 사항) 콘텐츠가 저장될 폴더 경로. 이 폴더 경로는 실제 물리적 경로가 아닌 플레이어 앱 내 가상 구조이며, `media/movie/video`와 같이 설정이 가능합니다. |

#### 다중 다운로드 호출 예시

```js
kollus://download?url={ENCODED_URL_1}&url={ENCODED_URL_2}&url={ENCODED_URL_3}
```

### 다운로드된 콘텐츠 재생

디바이스에 다운로드된 콘텐츠를 Kollus 모바일 앱에서 재생합니다. 해당 콘텐츠 파일이 디바이스에서 삭제되었거나 존재하지 않는 경우, URL Scheme 호출은 **자동으로 무시**되며 플레이어는 아무런 동작을 수행하지 않습니다.

#### Scheme

```text
kollus://download_play
```

#### 파라미터

| 파라미터 | 타입 | 설명 |
| --- | --- | --- |
| `url` | `string` | 다운로드된 콘텐츠의 재생 URL |

### 다운로드 완료 목록 표시

Kollus 모바일 앱을 실행하고, 다운로드 완료된 콘텐츠 목록 화면을 즉시 보여줍니다. 특정 폴더의 콘텐츠 목록만 표시하고 싶다면 `folder` 파라미터를 지정하세요.

#### Scheme

```text
kollus://list
```

#### 파라미터

| 파라미터 | 타입 | 설명 |
| --- | --- | --- |
| `folder` | `string` | 해당 폴더에 저장된 콘텐츠 목록만 표시 (미지정 시 최상위 폴더의 목록 표시) |
