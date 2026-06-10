#if canImport(UIKit)
//
//  PlayerSecureDisplayContainerViewTests.swift
//  VideoPlayerModuleTests
//
//  Created by JunyoungJung on 2026/06/10.
//

import Testing
import UIKit
@testable import VideoPlayerSkin

@MainActor
struct PlayerSecureDisplayContainerViewTests {

    @Test("secure 캔버스 추출이 활성화된다")
    func secureCanvasIsActive() {
        let container = PlayerSecureDisplayContainerView()
        // UITextField 내부 구조가 바뀌어 추출이 실패하면 여기서 깨진다 —
        // 강등은 런타임 폴백이지, 조용히 보호가 꺼진 채 출시되면 안 된다.
        #expect(container.isSecureRenderingActive)
    }

    @Test("embed한 뷰는 컨테이너 계층 안에 들어간다")
    func embedAddsToHierarchy() {
        let container = PlayerSecureDisplayContainerView()
        let embedded = UIView()
        container.embed(embedded)

        #expect(embedded.isDescendant(of: container))
        // 직접 자식이 아니라 secure 캔버스 아래에 있어야 보호된다.
        #expect(embedded.superview !== container)
    }
}
#endif
