//
//  PlayerTestConsoleContainerViewController.swift
//  VideoPlayerExample
//
//  Created by JunyoungJung on 2026/06/08.
//
//  상단 영상(16:9) + 하단 탭 콘솔 분할 컨테이너.
//  smartlearning PlayerModule 의 LecturePlayerContainerViewController(verticalSplit) 레이아웃 참고.
//  - portrait: 영상 16:9 위 + 콘솔 아래
//  - landscape: 영상 풀스크린, 콘솔 숨김 (Lecture parity)
//

import UIKit
import VideoPlayerCore

@MainActor
final class PlayerTestConsoleContainerViewController: UIViewController {
    private enum LayoutMode: Equatable {
        case verticalSplit
        case fullScreen
    }

    /// dev 영상 letterbox 비율 16:9.
    private static let videoAspectRatio: CGFloat = 16.0 / 9.0

    private let playerViewController: PlayerViewController
    private let consoleViewController: PlayerConsoleViewController
    /// 콘솔 전용 nav 스택 — pane 의 push 가 컨테이너(앱) nav 가 아닌 하단 콘솔 영역 안에서 동작하도록 격리.
    private let consoleNavigationController: UINavigationController
    private let divider: UIView = {
        let view = UIView()
        view.backgroundColor = .separator
        return view
    }()

    private var layoutConstraints: [NSLayoutConstraint] = []
    private var currentMode: LayoutMode?

    // MARK: - Init

    init(source: PlaybackSource, moduleProvider: PlayerModuleProviding) {
        let player = PlayerViewController(source: source, moduleProvider: moduleProvider)
        self.playerViewController = player
        let console = PlayerConsoleViewController(
            channel: player,
            sourceDescription: Self.describe(source)
        )
        self.consoleViewController = console
        let consoleNav = UINavigationController(rootViewController: console)
        consoleNav.setNavigationBarHidden(true, animated: false)
        self.consoleNavigationController = consoleNav
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        configurePlayerWiring()
        embed(playerViewController)
        view.addSubview(divider)
        consoleNavigationController.delegate = self
        embed(consoleNavigationController)
        divider.translatesAutoresizingMaskIntoConstraints = false

        applyLayout(resolveMode(for: view.bounds.size))
    }

    override func viewWillTransition(
        to size: CGSize,
        with coordinator: UIViewControllerTransitionCoordinator
    ) {
        super.viewWillTransition(to: size, with: coordinator)
        let nextMode = resolveMode(for: size)
        coordinator.animate(alongsideTransition: { [weak self] _ in
            self?.applyLayout(nextMode)
        })
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        // landscape 풀스크린을 허용하려면 컨테이너가 가로를 막지 않아야 한다.
        .allButUpsideDown
    }

    override var prefersStatusBarHidden: Bool {
        currentMode == .fullScreen
    }

    // MARK: - Wiring

    private func configurePlayerWiring() {
        // 콜백을 먼저 연결한 뒤 child 를 붙여야, player.viewDidLoad 의 setUp/이벤트를 콘솔이 놓치지 않는다.
        playerViewController.isEmbeddedInSplit = true
        playerViewController.onClose = { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
        playerViewController.onSkinStateChanged = { [weak self] state in
            self?.consoleViewController.forwardSkinState(state)
        }
        playerViewController.onPlayerEvent = { [weak self] event in
            self?.consoleViewController.forwardEvent(event)
        }
    }

    private func embed(_ child: UIViewController) {
        addChild(child)
        view.addSubview(child.view)
        child.view.translatesAutoresizingMaskIntoConstraints = false
        child.didMove(toParent: self)
    }

    // MARK: - Layout

    private func resolveMode(for size: CGSize) -> LayoutMode {
        size.width > size.height ? .fullScreen : .verticalSplit
    }

    private func applyLayout(_ mode: LayoutMode) {
        guard currentMode != mode || layoutConstraints.isEmpty else { return }

        NSLayoutConstraint.deactivate(layoutConstraints)
        layoutConstraints.removeAll()

        let playerView = playerViewController.view!
        let consoleView = consoleNavigationController.view!
        let safeArea = view.safeAreaLayoutGuide

        switch mode {
        case .verticalSplit:
            divider.isHidden = false
            consoleView.isHidden = false
            layoutConstraints = [
                playerView.topAnchor.constraint(equalTo: safeArea.topAnchor),
                playerView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor),
                playerView.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor),
                playerView.heightAnchor.constraint(
                    equalTo: playerView.widthAnchor,
                    multiplier: 1.0 / Self.videoAspectRatio
                ),

                divider.topAnchor.constraint(equalTo: playerView.bottomAnchor),
                divider.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                divider.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                divider.heightAnchor.constraint(equalToConstant: 1),

                consoleView.topAnchor.constraint(equalTo: divider.bottomAnchor),
                consoleView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                consoleView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                consoleView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ]

        case .fullScreen:
            divider.isHidden = true
            consoleView.isHidden = true
            layoutConstraints = [
                playerView.topAnchor.constraint(equalTo: view.topAnchor),
                playerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                playerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                playerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ]
        }

        NSLayoutConstraint.activate(layoutConstraints)
        currentMode = mode

        // skin 모드는 컨테이너가 명시 주입 (player 자체 bounds 판단 금지 — 16:9 프레임 오인 방지).
        playerViewController.applySkinLayoutMode(mode == .fullScreen ? .fullScreen : .verticalSplit)
        setNeedsStatusBarAppearanceUpdate()
    }

    // MARK: - Helper

    private static func describe(_ source: PlaybackSource) -> String {
        switch source.kind {
        case .url(let url):
            return url.absoluteString
        case .mediaKey(let key):
            return "mediaKey: \(key)"
        }
    }
}

// MARK: - UINavigationControllerDelegate

extension PlayerTestConsoleContainerViewController: UINavigationControllerDelegate {
    /// 콘솔 루트(커스텀 tabBar 보유)에서는 nav bar 를 숨기고, push 된 상세 화면에서만 back 버튼용 nav bar 노출.
    func navigationController(
        _ navigationController: UINavigationController,
        willShow viewController: UIViewController,
        animated: Bool
    ) {
        // animated 토글은 바를 push 와 동시에 세로 슬라이드시켜 "위→아래로 내려오는" 잔상을 만든다.
        // embed nav 는 화면 상단에 닿지 않아 슬라이드 모션만 거슬리므로 즉시(non-animated) 전환.
        let isConsoleRoot = viewController === consoleViewController
        navigationController.setNavigationBarHidden(isConsoleRoot, animated: false)
    }
}
