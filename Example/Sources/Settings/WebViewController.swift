//
//  WebViewController.swift
//  VideoPlayerExample
//
//  Created by JunyoungJung on 2026/06/05.
//
//  FAQ 웹뷰 — 샘플 WebViewController parity (동일 FAQ URL).
//

import UIKit
import WebKit

@MainActor
final class WebViewController: UIViewController {
    private static let faqURL = URL(string: "https://kollus-service.github.io/kollus-player-faq/")

    private let webView = WKWebView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "FAQ"
        view.backgroundColor = .systemBackground

        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        if let url = Self.faqURL {
            webView.load(URLRequest(url: url))
        }
    }
}
