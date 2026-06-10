#if canImport(UIKit)
//
//  UIViewTestHelpers.swift
//  VideoPlayerModuleTests
//
//  Created by JunyoungJung on 2026/06/10.
//

import UIKit

extension UIView {
    /// 뷰 계층에서 숨김 여부를 실효적으로 판단한다 (부모 뷰의 숨김 상태 포함).
    var isEffectivelyHidden: Bool {
        if isHidden || alpha == 0 { return true }
        return superview?.isEffectivelyHidden ?? false
    }

    /// `accessibilityIdentifier`로 자손 뷰를 탐색한다.
    func descendant(accessibilityIdentifier: String) -> UIView? {
        if self.accessibilityIdentifier == accessibilityIdentifier { return self }
        for subview in subviews {
            if let match = subview.descendant(accessibilityIdentifier: accessibilityIdentifier) {
                return match
            }
        }
        return nil
    }
}
#endif
