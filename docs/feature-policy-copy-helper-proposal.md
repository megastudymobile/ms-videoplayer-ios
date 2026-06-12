# Policy/Traits 구조 검토 및 개선안 — copy helper 도입

작성: JunyoungJung, 2026-06-12 · 상태: 구현 완료 (2026-06-12) · 권고안: copy helper + 버그 수정

## 배경 — 외부 리뷰 결론

`EngineRuntimeTraits`와 `PlayerFeaturePolicy`의 역할 분리에 대한 외부 리뷰(codex)를 실제 코드와 대조 검증했다. 결론: **현 구조 유지가 맞다.** 구조 변경 없음.

```text
PlayerPlaybackEngine.runtimeTraits   엔진 타입의 기본 동작 선언 (사실)
PlayerEngineDescriptor.runtimeTraits 환경/팩토리 보정까지 반영한 최종 동작 선언
PlayerFeaturePolicy                  host/사용자가 원하는 정책 (의도)
PlayerCore                           policy + traits를 합쳐 effective behavior 결정
```

검증된 핵심 원칙:

| 원칙 | 근거 |
|---|---|
| traits를 Policy 안에 넣지 않는다 | "엔진 사실"과 "앱 의도"가 섞임. 특히 `stateAuthority`를 정책화하면 command-origin 입력과 SDK 콜백 입력이 같은 reducer에 이중 적용되어 상태 경합 발생 (`PlayerCore.swift` `applyCommandOriginIfNeeded` 주석 참고) |
| 타입 static 선언은 기본값으로만 | Core가 `type(of: engine).runtimeTraits`만 믿으면 부족 — Kollus의 `audioBackgroundPlayPolicy`처럼 환경이 traits를 보정하는 경우가 있다 (`KollusPlayerModuleFactory.swift:38`) |
| 최종 traits는 descriptor로 주입 | `PlayerEngineDescriptor`가 엔진과 보정된 traits를 한 단위로 묶어 불일치 주입을 차단 |

### 기각 — `PlayerRuntimeContext` 신설

리뷰에서 제시된 선택지 중 policy + traits를 묶는 별도 타입(`PlayerRuntimeContext` / `ResolvedPlaybackPolicy`)은 도입하지 않는다.

- effective 판단(`policy.allowsBackgroundPlayback && traits.surface.continuesWithoutSurface`)이 중복되는 곳은 `PlayerCore.applyEffectivePolicy`와 `PlayerLifecycleCoordinator.handleDidEnterBackground` 두 곳뿐. boolean 합성 하나를 위해 public 타입을 늘릴 이유가 없다
- `backgroundPlaybackEnabled` 별도 필드는 downgrade된 `featurePolicy`와 정보가 중복된다

## 발견된 버그 — 필드 누락 재구성

검증 과정에서 실제 버그를 발견했다. `PlayerFeaturePolicy`를 필드별로 수동 재구성하는 두 곳이 `allowsSeekPreview`를 빠뜨려, init 기본값 `true`로 **조용히 리셋**된다.

| 위치 | 시나리오 |
|---|---|
| `PlayerCore.swift` `applyEffectivePolicy` (약 390행) | host가 `allowsSeekPreview: false` + `allowsBackgroundPlayback: true` 설정 → surface 미지원 엔진에서 background downgrade가 일어나는 순간 seek preview가 다시 켜짐 |
| `PlayerCore.swift` `applySkipInterval` (약 404행) | `setSkipInterval` 명령 처리 시마다 `allowsSeekPreview`가 `true`로 리셋 |

수동 재구성 패턴의 전형적 취약점이다. 정책 필드가 추가될 때마다(이번엔 `allowsSeekPreview`, 과거 `skipInterval`·`nextEpisodeButtonLeadTime`도 같은 경로) 재구성 지점 전부를 손으로 찾아 고쳐야 하고, init 기본값이 있는 필드는 누락이 컴파일 에러로 드러나지 않는다.

## 개선안 — `with*` copy helper

`PlayerFeaturePolicy`에 나머지 필드를 보존하는 사본 생성 메서드를 추가하고, 수동 재구성 지점을 모두 대체한다. `EngineRuntimeTraits.withSurface(continuesWithoutSurface:)`가 이미 같은 패턴을 쓰고 있어 일관성도 맞는다.

```swift
extension PlayerFeaturePolicy {
    /// 나머지 정책 필드를 보존한 채 background 재생 허용만 바꾼 사본.
    public func withBackgroundPlayback(_ allowsBackgroundPlayback: Bool) -> PlayerFeaturePolicy {
        PlayerFeaturePolicy(
            allowsBackgroundPlayback: allowsBackgroundPlayback,
            allowedPlaybackRates: allowedPlaybackRates,
            allowsAutoplay: allowsAutoplay,
            skipInterval: skipInterval,
            nextEpisodeButtonLeadTime: nextEpisodeButtonLeadTime,
            allowsSeekPreview: allowsSeekPreview
        )
    }

    /// 나머지 정책 필드를 보존한 채 skip 간격만 바꾼 사본.
    public func withSkipInterval(_ skipInterval: TimeInterval) -> PlayerFeaturePolicy {
        PlayerFeaturePolicy(
            allowsBackgroundPlayback: allowsBackgroundPlayback,
            allowedPlaybackRates: allowedPlaybackRates,
            allowsAutoplay: allowsAutoplay,
            skipInterval: skipInterval,
            nextEpisodeButtonLeadTime: nextEpisodeButtonLeadTime,
            allowsSeekPreview: allowsSeekPreview
        )
    }
}
```

호출부 변경:

```swift
// PlayerCore.applyEffectivePolicy
guard engineRuntimeTraits.surface.continuesWithoutSurface else {
    return (policy.withBackgroundPlayback(false), .missingContinuesWithoutSurface)
}

// PlayerCore.applySkipInterval
currentPolicy = currentPolicy.withSkipInterval(interval)
```

이후 정책 필드가 추가되면 helper 내부 한 곳만 고치면 되고, helper 자체는 모든 필드를 명시 전달하므로 init에 필드가 추가되는 순간 컴파일 에러로 갱신이 강제된다(새 필드에 init 기본값을 주지 않는 경우). 기본값을 주더라도 누락 지점이 helper 한 곳으로 수렴한다.

## 작업 범위

1. `PlayerFeaturePolicy`에 `withBackgroundPlayback(_:)` / `withSkipInterval(_:)` 추가
2. `PlayerCore.applyEffectivePolicy` / `applySkipInterval`의 수동 재구성을 helper 호출로 대체
3. 회귀 테스트 추가 (`Tests/VideoPlayerModuleTests/Core/`)
   - `allowsSeekPreview: false` 정책이 background downgrade 후에도 보존되는지
   - `setSkipInterval` 처리 후에도 보존되는지
   - helper가 대상 외 필드를 전부 보존하는지

영향 범위는 `VideoPlayerCore` 한 모듈, public API는 추가만 있고 변경/제거 없음.

## 구현 결과 (2026-06-12)

작업 범위 1~3 전부 반영. 테스트는 `PlayerFeaturePolicyCopyHelperTests.swift` 3건, 전체 suite green.

구현 중 추가 결정:

- 테스트가 actor private 상태를 Mirror reflection으로 읽던 초안을 폐기하고,
  `PlayerCore.currentPolicy`를 `private(set)`(읽기 internal)으로 바꿔 `@testable` +
  `await core.currentPolicy` 직접 접근으로 대체 — actor isolation 준수, 리네임 시 컴파일 에러로 검출
- 같은 날 후속 작업으로 `EngineRuntimeTraits`의 엔진별 preset(`.avPlayer`/`.kollus`)을 Core에서
  제거하고 각 어댑터 타입이 자기 traits를 직접 선언하도록 이동 — Core가 엔진 이름을 모르는
  경계 규칙과 일치. 계약 테스트 기대값은 동어반복 방지를 위해 독립 literal로 유지
