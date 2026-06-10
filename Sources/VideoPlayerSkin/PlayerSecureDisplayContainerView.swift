//
//  PlayerSecureDisplayContainerView.swift
//  VideoPlayerModule
//
//  Created by JunyoungJung on 2026/06/10.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

import UIKit

/// 스크린샷·화면 녹화 결과물에서 내용을 제외하는 보안 컨테이너.
///
/// iOS는 스크린샷을 사전 차단하는 공개 API가 없다 — 유일한 실효 수단은
/// `UITextField.isSecureTextEntry`의 secure 캔버스 레이어를 콘텐츠 컨테이너로
/// 쓰는 것이다. 시스템이 캡처 합성 단계에서 해당 레이어를 제외하므로
/// 스크린샷/녹화/미러링 화면에는 이 컨테이너 영역이 비어 보인다.
///
/// 캔버스 추출은 문서화되지 않은 UITextField 내부 뷰 구조에 의존한다 —
/// 추출 실패 시(향후 iOS 변경) 일반 컨테이너로 강등되어 표시는 정상 동작하고,
/// `isSecureRenderingActive == false`로 호스트가 강등을 감지할 수 있다.
public final class PlayerSecureDisplayContainerView: UIView {
    /// secure 캔버스 추출에 성공해 캡처 제외가 실제로 활성인지.
    public private(set) var isSecureRenderingActive: Bool

    /// 캔버스의 secure 속성은 이 필드의 상태에 묶여 있다 — 해제되지 않게 보유.
    private let secureField: UITextField
    private let canvas: UIView

    public override init(frame: CGRect) {
        let field = UITextField()
        field.isSecureTextEntry = true
        // iOS 15+ `_UITextLayoutCanvasView`, 이전 `_UITextFieldCanvasView` — 이름 대신
        // "CanvasView" 포함 여부로 찾는다.
        let secureCanvas = field.subviews.first {
            String(describing: type(of: $0)).contains("CanvasView")
        }
        self.secureField = field
        self.canvas = secureCanvas ?? UIView()
        self.isSecureRenderingActive = secureCanvas != nil
        super.init(frame: frame)

        canvas.subviews.forEach { $0.removeFromSuperview() }
        canvas.isUserInteractionEnabled = true
        canvas.translatesAutoresizingMaskIntoConstraints = false
        addSubview(canvas)
        NSLayoutConstraint.activate([
            canvas.topAnchor.constraint(equalTo: topAnchor),
            canvas.leadingAnchor.constraint(equalTo: leadingAnchor),
            canvas.trailingAnchor.constraint(equalTo: trailingAnchor),
            canvas.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @available(*, unavailable) public required init?(coder: NSCoder) { fatalError() }

    /// 보호 대상 뷰를 컨테이너 전체에 채워 넣는다. 호출 순서가 z-order가 된다.
    public func embed(_ view: UIView) {
        view.translatesAutoresizingMaskIntoConstraints = false
        canvas.addSubview(view)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: canvas.topAnchor),
            view.leadingAnchor.constraint(equalTo: canvas.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: canvas.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: canvas.bottomAnchor)
        ])
    }
}
