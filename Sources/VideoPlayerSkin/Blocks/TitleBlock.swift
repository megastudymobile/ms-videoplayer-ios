import UIKit

public final class TitleBlock: UIView, PlayerSkinBlock {
    public var view: UIView { self }
    public var onAction: ((PlayerSkinAction) -> Void)?
    public var theme: PlayerSkinTheme = .default
    private let label = UILabel()
    public override init(frame: CGRect) {
        super.init(frame: frame)
        label.lineBreakMode = .byTruncatingTail; label.numberOfLines = 1; label.textAlignment = .left
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor),
            label.trailingAnchor.constraint(equalTo: trailingAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)])
    }
    @available(*, unavailable) public required init?(coder: NSCoder) { fatalError() }
    public func setTitle(_ title: String) { label.text = title }

    public func didInjectTheme() {
        label.textColor = theme.color(.controlTint)
        label.font = theme.font(.title)
    }

    public func render(_ state: PlayerSkinState) {}
}
