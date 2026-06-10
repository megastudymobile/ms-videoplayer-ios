//
//  PlayerConsoleViewController.swift
//  VideoPlayerExample
//
//  Created by JunyoungJung on 2026/06/08.
//
//  하단 테스트 콘솔 — UITabBar(설정/북마크/자막/메타데이터) + 활성 pane child 교체.
//  UITabBarController 대신 경량 탭바를 쓰는 이유: 상단 영상과 split embed 된 단일 영역에서
//  탭만 전환하면 되기 때문 (별도 nav 스택/풀스크린 탭 컨테이너 불필요).
//

import UIKit
import VideoPlayerCore
import VideoPlayerSkin

/// 콘솔 pane 공통 — 활성 시 skin 상태/이벤트를 받아 갱신.
@MainActor
protocol PlayerConsolePane: UIViewController {
    func applySkinState(_ state: PlayerSkinState)
    func handleEvent(_ event: PlayerEvent)
}

extension PlayerConsolePane {
    func applySkinState(_ state: PlayerSkinState) {}
    func handleEvent(_ event: PlayerEvent) {}
}

/// 기존 설정 화면은 갱신이 필요 없으므로 기본 구현만으로 pane 자격을 얻는다.
extension SettingViewController: PlayerConsolePane {}

@MainActor
final class PlayerConsoleViewController: UIViewController {
    private let tabBar = UITabBar()
    private let containerView = UIView()
    private let panes: [PlayerConsolePane]
    private var activeIndex = 0

    // MARK: - Init

    init(channel: PlayerControlChannel, sourceDescription: String) {
        self.panes = [
            SettingViewController(channel: channel),
            BookmarkPaneViewController(channel: channel),
            CaptionPaneViewController(channel: channel),
            MetadataPaneViewController(channel: channel, sourceDescription: sourceDescription)
        ]
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        configureTabBar()
        configureContainer()
        showPane(at: 0)
    }

    // MARK: - 외부 fan-out 수신

    /// skin 상태는 빈번(0.5s)하므로 활성 pane 에만 전달 (불필요한 비활성 pane reload 방지).
    func forwardSkinState(_ state: PlayerSkinState) {
        guard panes.indices.contains(activeIndex) else { return }
        panes[activeIndex].applySkinState(state)
    }

    /// 이벤트는 드물고(북마크 로드/자막 갱신) 비활성 pane 도 최신 상태를 유지해야 하므로 전체 전달.
    func forwardEvent(_ event: PlayerEvent) {
        panes.forEach { $0.handleEvent(event) }
    }

    // MARK: - 구성

    private func configureTabBar() {
        tabBar.translatesAutoresizingMaskIntoConstraints = false
        tabBar.delegate = self
        tabBar.items = [
            UITabBarItem(title: "설정", image: UIImage(systemName: "gearshape"), tag: 0),
            UITabBarItem(title: "북마크", image: UIImage(systemName: "bookmark"), tag: 1),
            UITabBarItem(title: "자막", image: UIImage(systemName: "captions.bubble"), tag: 2),
            UITabBarItem(title: "정보", image: UIImage(systemName: "info.circle"), tag: 3)
        ]
        tabBar.selectedItem = tabBar.items?.first
        view.addSubview(tabBar)

        NSLayoutConstraint.activate([
            tabBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tabBar.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func configureContainer() {
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: view.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: tabBar.topAnchor)
        ])
    }

    // MARK: - pane 전환

    private func showPane(at index: Int) {
        guard panes.indices.contains(index) else { return }

        if let current = children.first(where: { $0 is PlayerConsolePane }) {
            current.willMove(toParent: nil)
            current.view.removeFromSuperview()
            current.removeFromParent()
        }

        let pane = panes[index]
        addChild(pane)
        pane.view.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(pane.view)
        NSLayoutConstraint.activate([
            pane.view.topAnchor.constraint(equalTo: containerView.topAnchor),
            pane.view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            pane.view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            pane.view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        pane.didMove(toParent: self)
        activeIndex = index
    }
}

// MARK: - UITabBarDelegate

extension PlayerConsoleViewController: UITabBarDelegate {
    func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        showPane(at: item.tag)
    }
}
