//
//  GestureViewController.swift
//  VideoPlayerExample
//
//  Created by JunyoungJung on 2026/06/05.
//
//  화면 제스처 설정 — SLGestureSettingViewController 디자인 parity.
//  흰 스크롤뷰(paleGrey 배경) + 상단 10pt 구분 + "플레이 제스처" 마스터 행
//  + 더블탭 전용 2옵션 행 + 제스처별 항목 구성.
//  실제 더블탭 동작은 Example 정책상 좌/우 10초 이동만 허용한다.
//

import UIKit

@MainActor
final class GestureViewController: UIViewController {
    /// SL SLGestureType parity (마스터 제외 항목).
    private struct GestureItem {
        let title: String
        let imageName: String
        let guidePrefix: String
        let guideSuffix: String
    }

    private static let items: [GestureItem] = [
        .init(title: "2배속 재생", imageName: "MyPlayerScreenGestureLongPress",
              guidePrefix: "롱 탭(꾹 누르기)", guideSuffix: "2배속 재생"),
        .init(title: "화면 확대/축소", imageName: "MyPlayerScreenGestureWide",
              guidePrefix: "두 손가락 벌리기/좁히기", guideSuffix: "확대/축소"),
        .init(title: "영상 미세 이동", imageName: "MyPlayerScreenGestureForwardBackward",
              guidePrefix: "좌 우 드래그", guideSuffix: "뒤/앞 이동"),
        .init(title: "밝기 조절", imageName: "MyPlayerScreenGestureBrightness",
              guidePrefix: "좌측 상/하 드래그", guideSuffix: "밝기 조절"),
        .init(title: "볼륨 조절", imageName: "MyPlayerScreenGestureVolume",
              guidePrefix: "우측 상/하 드래그", guideSuffix: "볼륨 조절")
    ]

    private enum Metric {
        static let masterRowHeight: CGFloat = 60
        static let doubleTapRowHeight: CGFloat = 180
        static let radioSize: CGFloat = 22
        static let gestureImageWidth: CGFloat = 81
        static let gestureImageHeight: CGFloat = 46
    }

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "플레이어 제스처"
        view.backgroundColor = SLPalette.paleGrey
        configureNavigation()
        configure()
    }

    private func configureNavigation() {
        let home = UIBarButtonItem(
            image: UIImage(systemName: "house"),
            style: .plain,
            target: self,
            action: #selector(didTapHome)
        )
        home.tintColor = .label
        navigationItem.rightBarButtonItem = home
    }

    @objc private func didTapHome() {
        navigationController?.popToRootViewController(animated: true)
    }

    private func configure() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.backgroundColor = SLPalette.cardWhite
        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.backgroundColor = SLPalette.cardWhite
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            // 상단 paleGrey 10pt 구분(스크롤뷰를 safeArea+10 아래로).
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])

        contentStack.addArrangedSubview(makeMasterRow())
        contentStack.addArrangedSubview(makeDoubleTapRow())
        for item in Self.items {
            contentStack.addArrangedSubview(makeItemRow(item))
        }
    }

    // MARK: - Rows

    /// 플레이 제스처 마스터 (60h): 제목 + 스위치.
    private func makeMasterRow() -> UIView {
        let row = UIView()
        row.backgroundColor = SLPalette.cardWhite
        let title = makeTitleLabel("플레이 제스처")
        let toggle = makeSwitch(isOn: PreferenceManager.useGesture)
        toggle.isOn = PreferenceManager.useGesture
        toggle.addAction(UIAction { _ in PreferenceManager.useGesture = toggle.isOn }, for: .valueChanged)
        let topLine = makeHairline()
        let line = makeHairline()
        [topLine, title, toggle, line].forEach { row.addSubview($0) }
        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: Metric.masterRowHeight),
            topLine.topAnchor.constraint(equalTo: row.topAnchor),
            topLine.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            topLine.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            topLine.heightAnchor.constraint(equalToConstant: 0.5),
            title.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 16),
            title.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            toggle.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -16),
            toggle.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            line.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            line.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            line.bottomAnchor.constraint(equalTo: row.bottomAnchor),
            line.heightAnchor.constraint(equalToConstant: 0.5)
        ])
        return row
    }

    /// 더블탭 전용 행 — 원본 SLDoubleTapGestureView와 동일한 2옵션 구성.
    /// Example 정책상 재생/일시정지는 선택 불가 안내, 좌/우 10초 이동만 선택 상태로 표시한다.
    private func makeDoubleTapRow() -> UIView {
        let row = UIView()
        row.backgroundColor = SLPalette.cardWhite
        let title = makeTitleLabel("더블탭")
        let toggle = makeSwitch(isOn: true)
        let playPauseOption = makeDoubleTapOptionRow(
            isSelected: false,
            isEnabled: false,
            imageName: "MyPlayerScreenGesturePlayPause",
            prefix: "중앙 더블 탭",
            suffix: "재생/일시정지"
        )
        let forwardBackwardOption = makeDoubleTapOptionRow(
            isSelected: true,
            isEnabled: true,
            imageName: "MyPlayerScreenGestureDoubleTap",
            prefix: "좌 우 더블 탭",
            suffix: "10초 뒤로/빨리 가기"
        )
        let line = makeHairline()
        [title, toggle, playPauseOption, forwardBackwardOption, line].forEach { row.addSubview($0) }
        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: Metric.doubleTapRowHeight),
            title.topAnchor.constraint(equalTo: row.topAnchor, constant: 16),
            title.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 16),
            toggle.topAnchor.constraint(equalTo: row.topAnchor, constant: 16),
            toggle.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -16),

            playPauseOption.topAnchor.constraint(equalTo: toggle.bottomAnchor, constant: 8),
            playPauseOption.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            playPauseOption.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            playPauseOption.heightAnchor.constraint(equalToConstant: Metric.gestureImageHeight),

            forwardBackwardOption.topAnchor.constraint(equalTo: playPauseOption.bottomAnchor, constant: 16),
            forwardBackwardOption.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            forwardBackwardOption.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            forwardBackwardOption.heightAnchor.constraint(equalToConstant: Metric.gestureImageHeight),

            line.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            line.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            line.bottomAnchor.constraint(equalTo: row.bottomAnchor),
            line.heightAnchor.constraint(equalToConstant: 0.5)
        ])
        return row
    }

    private func makeDoubleTapOptionRow(
        isSelected: Bool,
        isEnabled: Bool,
        imageName: String,
        prefix: String,
        suffix: String
    ) -> UIView {
        let option = UIView()
        option.translatesAutoresizingMaskIntoConstraints = false
        option.backgroundColor = SLPalette.cardWhite

        let radio = RadioIndicatorView(isSelected: isSelected, isEnabled: isEnabled)
        radio.translatesAutoresizingMaskIntoConstraints = false
        let image = makeGestureImageView(imageName)
        let guide = makeGuideLabel(prefix: prefix, suffix: suffix, isEnabled: isEnabled)
        [radio, image, guide].forEach { option.addSubview($0) }

        NSLayoutConstraint.activate([
            radio.widthAnchor.constraint(equalToConstant: Metric.radioSize),
            radio.heightAnchor.constraint(equalToConstant: Metric.radioSize),
            radio.leadingAnchor.constraint(equalTo: option.leadingAnchor, constant: 12),
            radio.centerYAnchor.constraint(equalTo: option.centerYAnchor),

            image.widthAnchor.constraint(equalToConstant: Metric.gestureImageWidth),
            image.heightAnchor.constraint(equalToConstant: Metric.gestureImageHeight),
            image.leadingAnchor.constraint(equalTo: radio.trailingAnchor, constant: 10),
            image.centerYAnchor.constraint(equalTo: option.centerYAnchor),

            guide.leadingAnchor.constraint(equalTo: image.trailingAnchor, constant: 12),
            guide.trailingAnchor.constraint(equalTo: option.trailingAnchor, constant: -12),
            guide.centerYAnchor.constraint(equalTo: option.centerYAnchor)
        ])
        return option
    }

    /// 제스처 항목 (SL SLGestureItemView parity): 제목 + 스위치 + 일러스트 81x46 + 안내문구 + 하단선.
    private func makeItemRow(_ item: GestureItem) -> UIView {
        let row = UIView()
        row.backgroundColor = SLPalette.cardWhite
        let title = makeTitleLabel(item.title)
        let toggle = makeSwitch(isOn: true)
        let image = makeGestureImageView(item.imageName)
        let guide = makeGuideLabel(prefix: item.guidePrefix, suffix: item.guideSuffix, isEnabled: true)
        let line = makeHairline()
        [title, toggle, image, guide, line].forEach { row.addSubview($0) }

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: row.topAnchor, constant: 16),
            title.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 16),
            toggle.topAnchor.constraint(equalTo: row.topAnchor, constant: 16),
            toggle.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -16),

            image.widthAnchor.constraint(equalToConstant: Metric.gestureImageWidth),
            image.heightAnchor.constraint(equalToConstant: Metric.gestureImageHeight),
            image.topAnchor.constraint(equalTo: toggle.bottomAnchor, constant: 10),
            image.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 48),
            image.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -16),

            guide.topAnchor.constraint(equalTo: image.topAnchor),
            guide.bottomAnchor.constraint(equalTo: image.bottomAnchor),
            guide.leadingAnchor.constraint(equalTo: image.trailingAnchor, constant: 10),
            guide.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -12),

            line.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            line.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            line.bottomAnchor.constraint(equalTo: row.bottomAnchor),
            line.heightAnchor.constraint(equalToConstant: 0.5)
        ])
        return row
    }

    // MARK: - Subview factories

    private func makeTitleLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = SLFont.title()
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    private func makeSwitch(isOn: Bool) -> UISwitch {
        let toggle = UISwitch()
        toggle.translatesAutoresizingMaskIntoConstraints = false
        toggle.isOn = isOn
        toggle.tintColor = SLPalette.hairline
        toggle.onTintColor = SLPalette.skyBlue
        toggle.thumbTintColor = SLPalette.cardWhite
        return toggle
    }

    private func makeGestureImageView(_ imageName: String) -> UIImageView {
        let image = UIImageView(image: UIImage(named: imageName))
        image.contentMode = .scaleAspectFit
        image.translatesAutoresizingMaskIntoConstraints = false
        return image
    }

    private func makeHairline() -> UIView {
        let line = UIView()
        line.backgroundColor = SLPalette.hairline
        line.translatesAutoresizingMaskIntoConstraints = false
        return line
    }

    /// "prefix [→] suffix" — SL firstGuideLabel.setAttributedTextWithImage parity (ic_arrow_ss 삽입).
    private func makeGuideLabel(prefix: String, suffix: String, isEnabled: Bool) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let color = isEnabled ? UIColor.label : SLPalette.grey58
        let attributes: [NSAttributedString.Key: Any] = [
            .font: SLFont.description(),
            .foregroundColor: color
        ]
        let result = NSMutableAttributedString(string: prefix + " ", attributes: attributes)
        if let arrow = UIImage(named: "ic_arrow_ss") {
            let attachment = NSTextAttachment()
            attachment.image = arrow
            attachment.bounds = CGRect(x: 0, y: 0, width: 11, height: 8)
            result.append(NSAttributedString(attachment: attachment))
        }
        result.append(NSAttributedString(string: " " + suffix, attributes: attributes))
        label.attributedText = result
        return label
    }
}

@MainActor
private final class RadioIndicatorView: UIView {
    private let isSelectedState: Bool
    private let isEnabledState: Bool

    init(isSelected: Bool, isEnabled: Bool) {
        self.isSelectedState = isSelected
        self.isEnabledState = isEnabled
        super.init(frame: .zero)
        backgroundColor = .clear
        isUserInteractionEnabled = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        let lineWidth: CGFloat = 4
        let outer = rect.insetBy(dx: lineWidth / 2, dy: lineWidth / 2)
        let strokeColor = isSelectedState && isEnabledState ? SLPalette.skyBlue : SLPalette.hairline
        strokeColor.setStroke()
        let path = UIBezierPath(ovalIn: outer)
        path.lineWidth = lineWidth
        path.stroke()

        guard isSelectedState else { return }
        let fillColor = isEnabledState ? SLPalette.skyBlue : SLPalette.grey58
        fillColor.setFill()
        UIBezierPath(ovalIn: rect.insetBy(dx: 7, dy: 7)).fill()
    }
}
