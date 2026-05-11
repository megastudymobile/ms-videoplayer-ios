//
//  PlayerRenderSurface.swift
//  SmartPlayer
//
//  Created by 모바일개발팀_정준영 on 2026/04/17.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import UIKit

public protocol PlayerRenderSurface: AnyObject {
    var containerView: UIView { get }

    func engineDidAttach()
    func engineDidDetach()
}

extension PlayerRenderSurface {
    public func engineDidAttach() {}
    public func engineDidDetach() {}
}
