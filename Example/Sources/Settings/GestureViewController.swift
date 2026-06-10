//
//  GestureViewController.swift
//  VideoPlayerExample
//
//  Created by JunyoungJung on 2026/06/05.
//
//  화면 제스처 설정 — SLGestureSettingViewController 디자인 parity.
//  흰 스크롤뷰(paleGrey 배경) + 상단 10pt 구분 + "플레이 제스처" 마스터 행 + 제스처별 항목
//  (제목 SemiBold17 / 우측 스위치 / 일러스트 81x46 / 안내문구 + 화살표 / 하단 0.5 hairline).
//  마스터 스위치는 PreferenceManager.useGesture(라이브 detail 표시)와 연동, 개별 항목은 데모상 시각 parity.
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
        .init(title: "더블탭", imageName: "MyPlayerScreenGestureDoubleTap",
              guidePrefix: "화면 양쪽 더블탭", guideSuffix: "10초 뒤로/앞으로 이동"),
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

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "플레이어 제스처"
        view.backgroundColor = SLPalette.paleGrey
        configure()
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

        // 마스터 "플레이 제스처" 행 — useGesture 연동.
        contentStack.addArrangedSubview(makeMasterRow())
        for item in Self.items {
            contentStack.addArrangedSubview(makeItemRow(item))
        }
    }

    // MARK: - Rows

    /// 플레이 제스처 마스터 (60h): 제목 + 스위치.
    private func makeMasterRow() -> UIView {
        let row = UIView()
        let title = makeTitleLabel("플레이 제스처")
        let toggle = UISwitch()
        toggle.translatesAutoresizingMaskIntoConstraints = false
        toggle.isOn = PreferenceManager.useGesture
        toggle.addAction(UIAction { _ in PreferenceManager.useGesture = toggle.isOn }, for: .valueChanged)
        let line = makeHairline()
        [title, toggle, line].forEach { row.addSubview($0) }
        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 60),
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

    /// 제스처 항목 (SL SLGestureItemView parity): 제목 + 스위치 + 일러스트 81x46 + 안내문구 + 하단선.
    private func makeItemRow(_ item: GestureItem) -> UIView {
        let row = UIView()
        let title = makeTitleLabel(item.title)
        let toggle = UISwitch()
        toggle.translatesAutoresizingMaskIntoConstraints = false
        toggle.isOn = true   // 데모상 시각 parity(개별 제스처 제어 미지원) — persist 안 함.
        let image = UIImageView(image: UIImage(named: item.imageName))
        image.contentMode = .scaleAspectFit
        image.translatesAutoresizingMaskIntoConstraints = false
        let guide = makeGuideLabel(prefix: item.guidePrefix, suffix: item.guideSuffix)
        let line = makeHairline()
        [title, toggle, image, guide, line].forEach { row.addSubview($0) }

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: row.topAnchor, constant: 16),
            title.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 16),
            toggle.topAnchor.constraint(equalTo: row.topAnchor, constant: 16),
            toggle.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -16),

            image.widthAnchor.constraint(equalToConstant: 81),
            image.heightAnchor.constraint(equalToConstant: 46),
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

    private func makeHairline() -> UIView {
        let line = UIView()
        line.backgroundColor = SLPalette.hairline
        line.translatesAutoresizingMaskIntoConstraints = false
        return line
    }

    /// "prefix [→] suffix" — SL firstGuideLabel.setAttributedTextWithImage parity (ic_arrow_ss 삽입).
    private func makeGuideLabel(prefix: String, suffix: String) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        let attributes: [NSAttributedString.Key: Any] = [
            .font: SLFont.description(),
            .foregroundColor: SLPalette.grey58
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
