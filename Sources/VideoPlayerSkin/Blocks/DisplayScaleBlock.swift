import UIKit
import VideoPlayerCore

public final class DisplayScaleBlock: UIView, PlayerSkinBlock {
    public var view: UIView { self }
    public var onAction: ((PlayerSkinAction) -> Void)?
    private let button = PlayerSkinIconButtonFactory.make()
    public override init(frame: CGRect) {
        super.init(frame: frame); pin(button)
        button.accessibilityIdentifier = "lecturePlayer.skin.displayScalingButton"
        button.addTarget(self, action: #selector(tap), for: .touchUpInside)
    }
    @available(*, unavailable) public required init?(coder: NSCoder) { fatalError() }
    public func render(_ state: PlayerSkinState, theme: PlayerSkinTheme) {
        let nextMode = state.displayScaleMode.next
        PlayerSkinIconButtonFactory.apply(button,
            icon: Self.icon(for: nextMode),
            fallbackTitle: Self.title(for: nextMode),
            theme: theme
        )
        button.accessibilityLabel = "\(Self.title(for: nextMode))으로 변경"
        button.isEnabled = !state.isLocked
        isHidden = state.isLocked || state.isFullScreenMode == false
    }
    @objc private func tap() { onAction?(.toggleDisplayScaling) }

    private static func icon(for mode: PlayerDisplayScaleMode) -> PlayerSkinIcon {
        switch mode {
        case .aspectFit:
            return .displayScaleFit
        case .aspectFill:
            return .displayScaleAspectFill
        case .fill:
            return .displayScaleFill
        }
    }

    private static func title(for mode: PlayerDisplayScaleMode) -> String {
        switch mode {
        case .aspectFit:
            return "화면 맞춤"
        case .aspectFill:
            return "화면 자름"
        case .fill:
            return "꽉찬 화면"
        }
    }

    private func pin(_ subview: UIView) {
        addSubview(subview)
        NSLayoutConstraint.activate([
            subview.topAnchor.constraint(equalTo: topAnchor),
            subview.bottomAnchor.constraint(equalTo: bottomAnchor),
            subview.leadingAnchor.constraint(equalTo: leadingAnchor),
            subview.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }
}
