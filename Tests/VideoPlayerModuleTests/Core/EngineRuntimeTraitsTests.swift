//
//  EngineRuntimeTraitsTests.swift
//  VideoPlayerModuleTests
//
//  Created by JunyoungJung on 2026/06/11.
//

import Testing
import VideoPlayerCore

@Suite("EngineRuntimeTraits 구조화 계약")
struct EngineRuntimeTraitsTests {
    @Test("default는 Core command-origin으로 상태를 닫고 surface 지속을 지원하지 않는다")
    func defaultRuntimeTraits() {
        let traits = EngineRuntimeTraits.default

        #expect(traits.stateAuthority == .commandSuccessClosesState)
        #expect(traits.surface.continuesWithoutSurface == false)
    }

    @Test("withSurface는 기존 상태 권위 설정을 보존한다")
    func withSurfacePreservesStateAuthority() {
        let traits = EngineRuntimeTraits(stateAuthority: .engineEventsAreAuthoritative)
            .withSurface(continuesWithoutSurface: true)

        #expect(traits.stateAuthority == .engineEventsAreAuthoritative)
        #expect(traits.surface.continuesWithoutSurface)
    }
}
