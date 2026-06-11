//
//  ToastPresenter.swift
//  VideoPlayerExample
//
//  Created by JunyoungJung on 2026/06/11.
//
//  레거시 host 앱 토스트와 동일한 룩/위치를 재현하는 Example 공용 토스트.
//  window 전체 기준 하단 중앙에 표시되어 플레이어가 화면 일부에 embed 돼도
//  화면 전체를 기준으로 뜬다.
//

import UIKit

/// 새 메시지가 오면 기존 토스트를 즉시 교체하고, 표시 시간이 지나면 페이드아웃 후 제거한다.
@MainActor
final class ToastPresenter {
    private enum Metric {
        static let cornerRadius: CGFloat = 8
        static let textHorizontalInset: CGFloat = 16
        static let textVerticalInset: CGFloat = 10
        static let edgeInset: CGFloat = 20
        static let displayDurationNanoseconds: UInt64 = 3_000_000_000
        static let fadeOutDuration: TimeInterval = 0.3

        @MainActor static var bottomInset: CGFloat { isPad ? 60 : 56 }
        @MainActor static var fontSize: CGFloat { isPad ? 17 : 14 }

        @MainActor private static var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
    }

    private weak var currentToast: UIView?
    private var dismissTask: Task<Void, Never>?

    func show(_ message: String, from anchorView: UIView) {
        // window 기준 배치 — anchorView(플레이어 등)가 화면 일부만 차지해도 토스트는 화면 전체 하단에 둔다.
        let container = anchorView.window ?? anchorView

        currentToast?.removeFromSuperview()
        dismissTask?.cancel()

        let toast = Self.makeToastView(message: message)
        currentToast = toast

        toast.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(toast)
        NSLayoutConstraint.activate([
            toast.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            toast.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: Metric.edgeInset),
            toast.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -Metric.edgeInset),
            toast.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -Metric.bottomInset)
        ])

        // presenter 가 먼저 해제돼도 토스트가 window 에 남지 않도록 view 만 약하게 붙잡는다.
        dismissTask = Task { [weak toast] in
            try? await Task.sleep(nanoseconds: Metric.displayDurationNanoseconds)
            guard Task.isCancelled == false, let toast else { return }
            UIView.animate(withDuration: Metric.fadeOutDuration, animations: {
                toast.alpha = 0
            }, completion: { _ in
                toast.removeFromSuperview()
            })
        }
    }

    private static func makeToastView(message: String) -> UIView {
        let toast = UIView()
        toast.backgroundColor = UIColor(red: 0x42 / 255.0, green: 0x42 / 255.0, blue: 0x42 / 255.0, alpha: 1)
        toast.layer.cornerRadius = Metric.cornerRadius
        toast.clipsToBounds = true

        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = UIFont(name: "AppleSDGothicNeo-Regular", size: Metric.fontSize)
            ?? .systemFont(ofSize: Metric.fontSize)
        label.textColor = UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0xE3 / 255.0, green: 0xE5 / 255.0, blue: 0xE5 / 255.0, alpha: 1)
                : .white
        }
        label.text = message

        label.translatesAutoresizingMaskIntoConstraints = false
        toast.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: toast.leadingAnchor, constant: Metric.textHorizontalInset),
            label.trailingAnchor.constraint(equalTo: toast.trailingAnchor, constant: -Metric.textHorizontalInset),
            label.topAnchor.constraint(equalTo: toast.topAnchor, constant: Metric.textVerticalInset),
            label.bottomAnchor.constraint(equalTo: toast.bottomAnchor, constant: -Metric.textVerticalInset)
        ])

        return toast
    }
}
