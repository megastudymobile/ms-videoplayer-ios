//
//  PlayerRenderSurface.swift
//  VideoPlayerModule
//
//  Created by 모바일팀_정준영 on 2026/04/17.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import UIKit

public protocol PlayerRenderSurface: AnyObject {
    var containerView: UIView { get }

    func engineDidAttach()
    func engineDidDetach()

    /// 현재 실행 환경(예: 시뮬레이터)에서 엔진이 실제 재생을 제공할 수 없을 때,
    /// 렌더 표면에 "미지원" 안내를 표시하도록 요청한다.
    /// `UnsupportedEnvironmentEngine` 가 `bind` 시점에 호출한다.
    func showUnsupportedEnvironment(message: String)
}

extension PlayerRenderSurface {
    public func engineDidAttach() {}
    public func engineDidDetach() {}
    public func showUnsupportedEnvironment(message: String) {}
}
