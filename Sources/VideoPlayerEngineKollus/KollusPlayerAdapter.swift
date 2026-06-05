//
//  KollusPlayerAdapter.swift
//  VideoPlayerModule
//
//  Created by 모바일개발팀_정준영 on 2026/05/11.
//  Updated by 모바일개발팀_정준영 on 2026/05/15 (Phase 3 T025).
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

import Foundation
import KollusSDKBinary
import UIKit
import VideoPlayerCore
import VideoPlayerShellSupport

// MARK: - KollusPlayerType Swift alias
// NS_ENUM(KollusPlayerType) 케이스명(PlayerType*)이 타입명(KollusPlayerType)의 prefix와 달라
// Swift automatic prefix stripping이 적용되지 않는다. rawValue로 안전하게 wrap.
// swiftlint:disable force_unwrapping
extension KollusPlayerType {
    /// PlayerTypeNative (rawValue 1) — PiP 가능 여부 판단에 사용.
    static let native = KollusPlayerType(rawValue: 1)! // PlayerTypeNative
}
// swiftlint:enable force_unwrapping

public actor KollusPlayerAdapter:
    PlayerEngineAdapter,
    PlayerPlaybackRateEngine,
    PlayerTitledBookmarkEngine,
    PlayerSubtitleEngine,
    PlayerExternalSubtitleEngine,
    PlayerDisplayScalingEngine,
    PlayerZoomEngine,
    PlayerSynchronousZoomEngine,
    PlayerScrollEngine,
    PlayerAdaptiveStreamingEngine,
    PlayerEngineOutputProducing,
    PlayerPiPCapability {
    // emitsObservedCommandState: Kollus는 playStarted/pauseStarted/stopStarted 권위 콜백을 낸다.
    // 따라서 Core는 play/pause/seek 명령 후 command-origin을 적용하지 않고 outputStream의
    // .stateInput만 신뢰한다(이중 적용 방지). (설계 §5.2.1)
    public nonisolated static let capabilities: EngineCapabilities = [.emitsObservedCommandState]

    public var currentState: PlaybackState {
        state
    }

    public let eventStream: AsyncStream<PlayerEvent>

    /// B안 권위 경로. Core는 이 스트림을 소비해 reducer로 상태를 만든다.
    /// `eventStream`/`currentState`는 전환기 deprecated mirror로만 유지된다. (설계 §8 4단계)
    public let outputStream: AsyncStream<PlayerEngineOutput>

    private let eventContinuation: AsyncStream<PlayerEvent>.Continuation
    private let outputContinuation: AsyncStream<PlayerEngineOutput>.Continuation
    private let bootstrapper: KollusSessionBootstrapper?
    private let environment: KollusEnvironment?
    private let observer: KollusObserver?
    private let diagnostics: KollusDiagnosticsSink?
    private let legacyStorage: KollusStorage?
    private let playerType: KollusPlayerType

    private var state: PlaybackState
    private weak var renderSurface: PlayerRenderSurface?
    private var displayScaleMode: PlayerDisplayScaleMode = .aspectFit
    @MainActor private var playerView: KollusPlayerView?
    @MainActor private var bridge: KollusDelegateBridge?
    /// PlayerTypeNative 백그라운드 오디오 keeper — playerView 생성 시 재생성, teardown 시 해제.
    @MainActor private var backgroundKeeper: KollusBackgroundAudioKeeper?
    /// `setSubTitlePath`에 전달한 C-string의 backing storage.
    /// SDK가 path를 비동기 보관할 가능성에 대비해 NSString을 actor가 retain한다.
    /// utf8String 포인터는 NSString lifetime 동안 유효.
    @MainActor private var subtitlePathBuffer: NSString?
    private var lastKnownBookmarks: [Bookmark] = []
    private var currentZoom: CGFloat = 0
    private var hasEmittedNextEpisode: Bool = false
    /// 다음 회차 메타데이터 — `.readyToPlay` 시 MainActor에서 1회 캐시.
    /// positionChanged hot path가 매 신호마다 MainActor를 왕복하면(단일 FIFO consumer가
    /// 그 왕복에 막혀) currentTime 발행이 실시간보다 지연된다. 캐시 후 hot path는 산술 비교만 한다.
    /// 엔진 next-episode가 없으면(showTime<=0) nil → hot path 즉시 단락.
    private struct NextEpisodeMeta: Sendable {
        let showAt: TimeInterval
        let callbackURL: URL?
        let params: [String: String]
        let showsButton: Bool
    }
    private var nextEpisodeMeta: NextEpisodeMeta?
    private var pendingPrepareContinuation: CheckedContinuation<Void, Error>?

    /// H1 — SDK delegate(bridge) 신호를 단일 FIFO 스트림으로 직렬 소비한다.
    /// 매 신호마다 `Task`를 새로 만들면 actor 도달 순서가 비결정적이라 `stopStarted` 뒤
    /// 늦게 도착한 `positionChanged`가 상태를 되살리는 등 상태 꼬임이 발생한다.
    /// bridge 콜백은 MainActor에서 continuation에 동기 yield만 하고, 단일 consumer가 순서대로 소비.
    private enum BridgeEvent: Sendable {
        case signal(KollusEngineSignal)
        case bookmarks([Bookmark])
    }
    private nonisolated let bridgeEventStream: AsyncStream<BridgeEvent>
    private nonisolated let bridgeEventContinuation: AsyncStream<BridgeEvent>.Continuation
    private var signalConsumerTask: Task<Void, Never>?

    /// 재생 위치 주기 폴링 Task.
    /// Kollus `kollusPlayerView:position:error:` delegate는 **seek 시에만** 호출되고 재생 중 주기 통지를
    /// 하지 않는다. 따라서 재생바 currentTime이 갱신되지 않는다. 레거시(`playbackProgressTimer`,
    /// `LegacyMoviePlayerController.m:5593`, 1.0s)처럼 재생 중 `currentPlaybackTime`을 주기적으로 읽어
    /// `.timeDidChange`를 발행한다. playStarted에 시작, pause/stop에 중지.
    private var positionPollTask: Task<Void, Never>?
    private static let positionPollInterval: UInt64 = 500_000_000 // 0.5s

    // MARK: - Initializers

    /// 신규 권장 진입점 — bootstrapper와 environment를 받아 26 raw callback wiring을 자동 구성한다.
    public init(
        bootstrapper: KollusSessionBootstrapper,
        environment: KollusEnvironment,
        observer: KollusObserver? = nil,
        diagnostics: KollusDiagnosticsSink? = nil,
        playerType: KollusPlayerType = KollusPlayerType(rawValue: 1)!
    ) {
        var continuation: AsyncStream<PlayerEvent>.Continuation?
        self.eventStream = AsyncStream<PlayerEvent>(bufferingPolicy: .bufferingNewest(8)) {
            continuation = $0
        }
        self.eventContinuation = continuation!
        var bridgeContinuation: AsyncStream<BridgeEvent>.Continuation?
        self.bridgeEventStream = AsyncStream<BridgeEvent>(bufferingPolicy: .unbounded) {
            bridgeContinuation = $0
        }
        self.bridgeEventContinuation = bridgeContinuation!
        var outputContinuation: AsyncStream<PlayerEngineOutput>.Continuation?
        self.outputStream = AsyncStream<PlayerEngineOutput>(bufferingPolicy: .unbounded) {
            outputContinuation = $0
        }
        self.outputContinuation = outputContinuation!
        self.bootstrapper = bootstrapper
        self.environment = environment
        self.observer = observer
        self.diagnostics = diagnostics
        self.legacyStorage = nil
        self.playerType = playerType
        self.state = .idle
        self.signalConsumerTask = nil
        startSignalConsumerIfNeeded()
    }

    /// Test-only init: 외부 공개 표면에서 제거됨(T062, gate 0.3.0).
    /// `@testable import`로만 접근. 새 wiring(인증/26 콜백) 미사용.
    internal init() {
        self.init(
            storage: KollusStorage(),
            playerType: KollusPlayerType(rawValue: 1)!
        )
    }

    /// Test-only direct-storage init. 외부 공개 표면 아님. 새 wiring 미사용.
    init(
        storage: KollusStorage,
        playerType: KollusPlayerType = KollusPlayerType(rawValue: 1)!
    ) {
        var continuation: AsyncStream<PlayerEvent>.Continuation?
        self.eventStream = AsyncStream<PlayerEvent>(bufferingPolicy: .bufferingNewest(8)) {
            continuation = $0
        }
        self.eventContinuation = continuation!
        var bridgeContinuation: AsyncStream<BridgeEvent>.Continuation?
        self.bridgeEventStream = AsyncStream<BridgeEvent>(bufferingPolicy: .unbounded) {
            bridgeContinuation = $0
        }
        self.bridgeEventContinuation = bridgeContinuation!
        var outputContinuation: AsyncStream<PlayerEngineOutput>.Continuation?
        self.outputStream = AsyncStream<PlayerEngineOutput>(bufferingPolicy: .unbounded) {
            outputContinuation = $0
        }
        self.outputContinuation = outputContinuation!
        self.bootstrapper = nil
        self.environment = nil
        self.observer = nil
        self.diagnostics = nil
        self.legacyStorage = storage
        self.playerType = playerType
        self.state = .idle
        self.signalConsumerTask = nil
        startSignalConsumerIfNeeded()
    }

    deinit {
        signalConsumerTask?.cancel()
        positionPollTask?.cancel()
        bridgeEventContinuation.finish()
        eventContinuation.finish()
        outputContinuation.finish()
    }

    /// H1 — bridge 신호를 단일 Task에서 FIFO로 소비. self를 약하게 잡아 deinit을 막지 않는다.
    private func startSignalConsumerIfNeeded() {
        guard signalConsumerTask == nil else { return }
        signalConsumerTask = Task { [weak self] in
            guard let stream = self?.bridgeEventStream else { return }
            for await event in stream {
                guard let self else { return }
                switch event {
                case .signal(let signal):
                    await self.handleSignal(signal)
                case .bookmarks(let bookmarks):
                    await self.handleBookmarks(bookmarks)
                }
            }
        }
    }

    // MARK: - PlayerEngineAdapter

    public func prepare(source: PlaybackSource) async throws {
        if bootstrapper != nil {
            try await prepareWithBootstrappedStorage(source: source)
        } else if legacyStorage != nil {
            try await prepareWithLegacyStorage(source: source)
        } else {
            throw PlayerError.engineError("KollusPlayerAdapter에 storage가 구성되지 않았습니다.")
        }
    }

    public func play() async throws {
        try await performPlay()
    }

    public func pause() async throws {
        try await performPause()
    }

    public func seek(to time: TimeInterval) async throws {
        let clampedTime = max(0, time)
        // H6 — playerView가 없으면(idle 등) 옵셔널 체이닝으로 조용히 무시하지 않고 throw한다.
        // 과거엔 seek가 무시되고도 가짜 timeDidChange를 emit해 상태를 오염시켰다.
        try await MainActor.run {
            guard let playerView else {
                throw PlayerError.engineError("Kollus playerView가 준비되지 않았습니다.")
            }
            playerView.currentPlaybackTime = clampedTime
        }
        let nextState = state.updating(currentTime: clampedTime)
        transition(to: nextState, emitStateEvent: false)
        publish(event: .timeDidChange(currentTime: clampedTime, duration: nextState.duration))
    }

    public func stop(reason: PlayerStopReason) async throws {
        try await performStop()
        let nextState = stateAfterStop(reason: reason)
        transition(to: nextState)
        if reason == .finished {
            publish(event: .didFinish)
        }
    }

    // MARK: - PlayerPlaybackRateEngine

    public func setPlaybackRate(_ rate: Double) async throws {
        guard rate > 0 else {
            throw PlayerError.engineError("Kollus playback rate must be greater than 0. rate=\(rate)")
        }
        try await MainActor.run {
            guard let playerView else {
                throw PlayerError.engineError("Kollus playerView가 준비되지 않았습니다.")
            }
            guard playerView.disablePlayRate == false else {
                throw PlayerError.engineError("Kollus 컨텐츠가 배속 제어를 지원하지 않습니다.")
            }
            playerView.currentPlaybackRate = Float(rate)
        }
    }

    // MARK: - PlayerBookmarkEngine / PlayerTitledBookmarkEngine

    public func addBookmark(at time: TimeInterval) async throws {
        try await addBookmark(at: time, title: "")
    }

    public func addBookmark(at time: TimeInterval, title: String) async throws {
        guard time >= 0 else {
            throw PlayerError.engineError("Kollus bookmark time must be greater than or equal to 0. time=\(time)")
        }
        try await MainActor.run {
            guard let playerView else {
                throw PlayerError.engineError("Kollus playerView가 준비되지 않았습니다.")
            }
            guard playerView.bookmarkModifyEnabled else {
                throw PlayerError.engineError("Kollus 컨텐츠가 북마크 추가를 지원하지 않습니다.")
            }
            try playerView.addBookmark(time, value: title)
        }
        // Kollus SDK 는 로컬 add 를 playerView.bookmarks 에 즉시 반영하지 않는다(서버 동기화 후 reload
        // 시점에만 갱신). 따라서 SDK 재조회(currentBookmarks)는 직전 낙관적 추가분을 포함하지 못해 매번
        // 첫 항목만 덮어쓴다. 누적이 유지되도록 마지막으로 발행한 목록(lastKnownBookmarks)을 base 로 쓴다.
        // 다음 실제 reload 시 권위 목록으로 자연 수렴한다.
        var updated = lastKnownBookmarks
        if !updated.contains(where: { abs($0.position - time) < 0.5 }) {
            updated.append(Bookmark(position: time, title: title, kind: .user))
            updated.sort { $0.position < $1.position }
        }
        handleBookmarks(updated)
    }

    public func removeBookmark(at time: TimeInterval) async throws {
        guard time >= 0 else {
            throw PlayerError.engineError("Kollus bookmark time must be greater than or equal to 0. time=\(time)")
        }
        try await MainActor.run {
            guard let playerView else {
                throw PlayerError.engineError("Kollus playerView가 준비되지 않았습니다.")
            }
            guard playerView.bookmarkModifyEnabled else {
                throw PlayerError.engineError("Kollus 컨텐츠가 북마크 삭제를 지원하지 않습니다.")
            }
            try playerView.removeBookmark(time)
        }
        // add 와 동일 — 마지막 발행 목록에서 낙관적으로 제거해 재발행(SDK 즉시 미반영 대응).
        var updated = lastKnownBookmarks
        updated.removeAll { abs($0.position - time) < 0.5 }
        handleBookmarks(updated)
    }

    public func currentBookmarks() async -> [Bookmark] {
        await MainActor.run { [weak self] () -> [Bookmark] in
            guard let playerView = self?.playerView,
                  let raw = playerView.bookmarks else {
                return []
            }
            return raw.compactMap { item -> Bookmark? in
                guard let kb = item as? KollusBookmark else { return nil }
                let title: String
                switch kb.kind {
                case .user: title = kb.value ?? ""
                case .index: title = kb.title ?? ""
                @unknown default: title = kb.value ?? kb.title ?? ""
                }
                return Bookmark(
                    position: kb.position,
                    title: title,
                    kind: kb.kind == .index ? .index : .user,
                    createdAt: kb.time as Date?
                )
            }
        }
    }

    // MARK: - PlayerSubtitleEngine / PlayerExternalSubtitleEngine

    public func setSubtitleVisible(_ isVisible: Bool) async throws {
        // KollusSDK는 자막 가시성 직접 API를 노출하지 않는다. 정책 다운그레이드 이벤트로 surfacing.
        // (M12 — 과거 저장만 하고 읽지 않던 isSubtitleVisible 필드 제거.)
        publish(event: .policyDowngraded(reason: .custom("Kollus SDK는 자막 가시성 토글을 지원하지 않습니다. isVisible=\(isVisible)")))
    }

    public func selectSubtitleTrack(_ trackID: PlayerSubtitleTrackID?) async throws {
        // trackID.rawValue를 자막 파일 path로 해석한다(외부 자막 path 기반 모델).
        try await applySubtitlePath(trackID?.rawValue)
    }

    public func setCaptionFontSize(_ fontSize: Int) async throws {
        guard fontSize > 0 else {
            throw PlayerError.engineError("Kollus caption font size must be > 0. size=\(fontSize)")
        }
        // KollusSDK는 자막 폰트 크기 직접 API를 노출하지 않는다. 정책 다운그레이드 이벤트로 surfacing.
        publish(event: .policyDowngraded(reason: .custom("Kollus SDK는 자막 폰트 크기 조절을 지원하지 않습니다. requested=\(fontSize)pt")))
    }

    public func selectSubtitleFile(_ fileURL: URL?) async throws {
        try await applySubtitlePath(fileURL?.path)
    }

    private func applySubtitlePath(_ path: String?) async throws {
        try await MainActor.run { [weak self] in
            guard let self else { return }
            guard let playerView = self.playerView else {
                throw PlayerError.engineError("Kollus playerView가 준비되지 않았습니다.")
            }
            let resolved = (path ?? "") as NSString
            // SDK가 path 포인터를 비동기 보관하더라도 use-after-free가 발생하지 않도록
            // NSString backing storage를 actor가 retain한다. 다음 호출 시 교체될 때까지 유효.
            self.subtitlePathBuffer = resolved
            guard let cstr = resolved.utf8String else {
                throw PlayerError.engineError("자막 파일 경로 인코딩 실패.")
            }
            _ = playerView.setSubTitlePath(UnsafeMutablePointer(mutating: cstr))
        }
    }

    // MARK: - PlayerZoomEngine

    public func zoom(_ recognizer: UIPinchGestureRecognizer) async throws {
        try await MainActor.run {
            guard let playerView else {
                throw PlayerError.engineError("Kollus playerView가 준비되지 않았습니다.")
            }
            try playerView.zoom(recognizer)
        }
        currentZoom = recognizer.scale
    }

    // MARK: - PlayerSynchronousZoomEngine

    /// 핀치 `.changed` 마다 main thread 에서 동기 적용 — actor async hop 없이 연속 추적.
    /// dev `MegaKollusMoviePlayerController.zoomScreen:` → `playerView.zoom:recognizer` 동기 호출 parity.
    /// host(shell)가 main thread 에서만 호출하므로 `MainActor.assumeIsolated` 로 @MainActor playerView 에
    /// 동기 접근한다(actor 격리/init MainActor 전파 회피 위해 nonisolated).
    public nonisolated func applyZoomGesture(_ recognizer: UIPinchGestureRecognizer) {
        MainActor.assumeIsolated {
            try? playerView?.zoom(recognizer)
        }
    }

    public func setZoomOutDisabled(_ disabled: Bool) async {
        await MainActor.run {
            playerView?.setDisableZoomOut(disabled)
        }
    }

    public func zoomValue() async -> CGFloat {
        currentZoom
    }

    public var isZoomedIn: Bool {
        get async {
            await MainActor.run {
                playerView?.isZoomedIn ?? false
            }
        }
    }

    // MARK: - PlayerScrollEngine

    public func scroll(by distance: CGPoint) async throws {
        try await MainActor.run {
            guard let playerView else {
                throw PlayerError.engineError("Kollus playerView가 준비되지 않았습니다.")
            }
            try playerView.scroll(distance)
        }
    }

    public func stopScroll() async throws {
        try await MainActor.run {
            guard let playerView else {
                throw PlayerError.engineError("Kollus playerView가 준비되지 않았습니다.")
            }
            try playerView.scrollStop()
        }
    }

    // MARK: - PlayerAdaptiveStreamingEngine

    public func changeBandwidth(_ bps: Int) async throws {
        try await MainActor.run {
            guard let playerView else {
                throw PlayerError.engineError("Kollus playerView가 준비되지 않았습니다.")
            }
            playerView.changeBandWidth(Int32(bps))
        }
    }

    public func streamInfoList() async -> [StreamInfo] {
        await MainActor.run {
            guard let raw = playerView?.streamInfoList as? [Any] else { return [] }
            return raw.compactMap { item -> StreamInfo? in
                // SDK가 노출하는 stream info 객체의 형태가 헤더에 명시되어 있지 않아 일반화 매핑.
                // SDK가 새 wrapper를 추가하면 본 매핑을 갱신해야 한다(현재 비어 있는 배열은 안전).
                guard let dict = item as? [String: Any],
                      let bitrate = dict["bitrate"] as? Int,
                      let width = dict["width"] as? Int,
                      let height = dict["height"] as? Int else {
                    return nil
                }
                return StreamInfo(bitrate: bitrate, width: width, height: height)
            }
        }
    }

    // MARK: - PlayerPiPCapability (KollusPlayerType.native 한정)

    public func startPiP() async throws {
        try await MainActor.run {
            guard playerView != nil else {
                throw PlayerError.engineError("Kollus playerView가 준비되지 않았습니다.")
            }
        }
        guard playerType == .native else {
            throw PlayerError.engineError("PIP는 KollusPlayerType.native 한정으로 지원됩니다.")
        }
        // H9 — KollusSDK는 PiP 직접 API가 없고 실 구현은 host AVPictureInPictureController 통합이 필요하다.
        // 과거엔 isPiPRunning 플래그를 토글해 isPiPActive가 실제 PiP 상태와 무관하게 true로 거짓 보고됐다.
        // 미구현 동안 내부 상태를 바꾸지 않고(=isPiPActive 항상 false) 통지 이벤트만 발행한다.
        publish(event: .policyDowngraded(reason: .custom("PIP 미구현 — host AVPictureInPictureController 통합 필요")))
    }

    public func stopPiP() async throws {
        try await MainActor.run {
            guard playerView != nil else {
                throw PlayerError.engineError("Kollus playerView가 준비되지 않았습니다.")
            }
        }
        guard playerType == .native else {
            throw PlayerError.engineError("PIP는 KollusPlayerType.native 한정으로 지원됩니다.")
        }
        publish(event: .policyDowngraded(reason: .custom("PIP 미구현 — host AVPictureInPictureController 통합 필요")))
    }

    /// H9 — 실제 PiP 미구현이므로 항상 false. startPiP가 내부 플래그를 토글하지 않아 거짓 활성 보고가 없다.
    public var isPiPActive: Bool {
        get async {
            false
        }
    }

    // MARK: - PlayerDisplayScalingEngine

    public func setDisplayScaled(_ isScaled: Bool) async throws {
        try await setDisplayScaleMode(isScaled ? .aspectFill : .aspectFit)
    }

    public func setDisplayScaleMode(_ mode: PlayerDisplayScaleMode) async throws {
        self.displayScaleMode = mode
        await MainActor.run {
            guard let playerView = self.playerView else { return }
            playerView.scalingMode = Self.scalingMode(mode: mode)
            if let containerView = playerView.superview {
                playerView.frame = containerView.bounds
                containerView.setNeedsLayout()
                containerView.layoutIfNeeded()
            }
            playerView.setNeedsLayout()
            playerView.layoutIfNeeded()
        }
    }

    public func toggleDisplayScaling() async throws {
        try await toggleDisplayScaleMode()
    }

    public func toggleDisplayScaleMode() async throws {
        let fallbackMode = displayScaleMode.next
        let nextMode = await MainActor.run {
            if let playerView {
                return Self.displayScaleMode(for: playerView.scalingMode).next
            }
            return fallbackMode
        }
        try await setDisplayScaleMode(nextMode)
    }

    // MARK: - Render surface binding

    public func bind(renderSurface: PlayerRenderSurface) {
        let previousSurface = self.renderSurface
        self.renderSurface = renderSurface

        Task { @MainActor in
            previousSurface?.engineDidDetach()
            if let playerView = self.playerView {
                attach(playerView: playerView, to: renderSurface)
            }
            renderSurface.engineDidAttach()
        }
    }

    public func unbindRenderSurface() {
        let detachedSurface = renderSurface
        renderSurface = nil

        Task { @MainActor in
            detachedSurface?.engineDidDetach()
            self.playerView?.removeFromSuperview()
        }
    }

    // MARK: - Prepare paths

    private func prepareWithBootstrappedStorage(source: PlaybackSource) async throws {
        guard let bootstrapper, let environment else {
            throw PlayerError.engineError("KollusPlayerAdapter: bootstrapper/environment 누락")
        }

        let storageProto = try await bootstrapper.resolveStorage()
        guard let storageAdapter = storageProto as? KollusStorageAdapter else {
            throw PlayerError.engineError("KollusPlayerAdapter: KollusStorageAdapter가 아닌 storage protocol 구현은 미지원.")
        }

        let boundSurface = renderSurface
        let displayScaleMode = self.displayScaleMode
        let playerType = self.playerType
        let observer = self.observer
        let diagnostics = self.diagnostics

        try await MainActor.run { [weak self] in
            guard let self else { return }
            // 재진입(다음 강의/강의 선택) 시 이전 playerView 를 stop 없이 폐기하면 KollusProxyPlayerView 의
            // releaseServerAndStop(NSTimer) 가 해제 메모리에서 발화해 크래시한다. discard 전 stop 으로
            // proxy 를 동기 해제한다(dev `stop` 후 재 prepareToPlay 정렬).
            if let previous = self.playerView {
                try? previous.stop()
                previous.removeFromSuperview()
            }
            self.playerView = nil

            guard let playerView = Self.makePlayerView(for: source) else {
                throw PlayerError.engineError("KollusPlayerView 초기화에 실패했습니다.")
            }

            // 1) bridge 생성 + 4종 delegate 부착 (prepareToPlay 호출 전 필수)
            // H1 — 콜백은 단일 FIFO 스트림에 동기 yield만. 순서 보장은 consumer가 담당.
            let bridgeEventContinuation = self.bridgeEventContinuation
            let bridge = KollusDelegateBridge(
                onSignal: { signal in
                    bridgeEventContinuation.yield(.signal(signal))
                },
                onBookmarks: { bookmarks in
                    bridgeEventContinuation.yield(.bookmarks(bookmarks))
                },
                observer: observer,
                diagnostics: diagnostics
            )
            playerView.delegate = bridge
            playerView.drmDelegate = bridge
            playerView.lmsDelegate = bridge
            playerView.bookmarkDelegate = bridge

            // 2) storage / DRM 설정 주입 (KollusStorageAdapter는 @MainActor — 본 블록 안에서 안전 접근)
            playerView.storage = storageAdapter.storage
            playerView.debug = false
            if let proxyPort = environment.proxyPort, proxyPort > 0 {
                playerView.proxyPort = UInt(proxyPort)
            }
            playerView.scalingMode = Self.scalingMode(mode: displayScaleMode)
            if let cert = environment.drm.fpsCertificateURL {
                playerView.fpsCertURL = cert.absoluteString
            }
            if let drmURL = environment.drm.fpsDRMURL {
                playerView.fpsDrmURL = drmURL.absoluteString
            }
            if !environment.drm.extraParameters.isEmpty,
               let data = try? JSONSerialization.data(withJSONObject: environment.drm.extraParameters),
               let json = String(data: data, encoding: .utf8) {
                playerView.extraDrmParam = json
            }

            // 2b) T053 — 확장 환경 옵션 주입 (Phase 7).
            playerView.aiRateEnable = environment.aiPlaybackRateEnabled
            playerView.setDecoder(environment.hardwareDecoderPreferred)
            if let skin = environment.customSkinJSON {
                playerView.customSkin = skin
            }
            playerView.setPauseOnForeground(environment.pauseOnForeground)
            playerView.audioBackgroundPlay = environment.audioBackgroundPlayPolicy

            // 3) render surface 부착 (있을 때만)
            if let boundSurface {
                self.attach(playerView: playerView, to: boundSurface)
            }

            self.playerView = playerView
            self.bridge = bridge
            self.backgroundKeeper = KollusBackgroundAudioKeeper(
                playerView: playerView,
                isEnabled: environment.audioBackgroundPlayPolicy
            )
        }

        // 신규 path에서는 상태 전이를 SDK delegate(prepareToPlayCompleted)에 의존한다.
        // prepare(source:) 자체도 delegate 완료까지 반환하지 않아야 PlayerCore autoplay가
        // 레거시와 동일하게 준비 완료 이후에 play를 호출한다.
        transition(to: state.updating(status: .preparing, isBuffering: false))

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                Task { [weak self] in
                    guard let self else {
                        continuation.resume(throwing: CancellationError())
                        return
                    }

                    await self.installPrepareContinuation(continuation)

                    do {
                        try await MainActor.run {
                            guard let playerView else {
                                throw PlayerError.engineError("Kollus playerView가 준비되지 않았습니다.")
                            }
                            // 4) prepareToPlay 호출 — 이후 SDK가 prepareToPlayWithError delegate 호출
                            try playerView.prepareToPlay(withMode: playerType)
                        }
                    } catch {
                        await self.completePendingPrepare(with: .failure(error))
                    }
                }
            }
        } onCancel: {
            Task { [weak self] in
                await self?.completePendingPrepare(with: .failure(CancellationError()))
            }
        }
    }

    /// H2/M13 — **test-only 경로**. `init(storage:)`/`internal init()`로만 진입하며 bridge/delegate를
    /// 배선하지 않는다(SDK `prepareToPlayWithError` 완료 콜백을 받지 못함). 따라서 프로덕션
    /// 완료-대기 계약을 의도적으로 지키지 않고 `prepareToPlay` 동기 호출 직후 `.readyToPlay`로 전이한다.
    /// 이는 SDK 콜백 없이 동작하는 단위 테스트 스캐폴딩 전용이며, **프로덕션은 반드시 bootstrapped 경로**
    /// (`init(bootstrapper:environment:)`)를 사용한다 — 그 경로는 `installPrepareContinuation` +
    /// `prepareToPlayCompleted` delegate 완료까지 대기해 autoplay가 준비 완료 이후에만 play를 호출한다.
    private func prepareWithLegacyStorage(source: PlaybackSource) async throws {
        guard let storage = legacyStorage else {
            throw PlayerError.engineError("legacy storage 누락")
        }

        let boundSurface = renderSurface
        let displayScaleMode = self.displayScaleMode
        let playerType = self.playerType
        let preparedState = try await MainActor.run { () throws -> PlaybackState in
            // 재진입 시 이전 playerView stop 후 폐기(proxy releaseServerAndStop 타이머 크래시 방지).
            if let previous = self.playerView {
                try? previous.stop()
                previous.removeFromSuperview()
            }
            self.playerView = nil

            guard let playerView = Self.makePlayerView(for: source) else {
                throw PlayerError.engineError("KollusPlayerView 초기화에 실패했습니다.")
            }
            playerView.storage = storage
            playerView.debug = false
            if let proxyPort = environment?.proxyPort, proxyPort > 0 {
                playerView.proxyPort = UInt(proxyPort)
            }
            playerView.scalingMode = Self.scalingMode(mode: displayScaleMode)

            if let boundSurface {
                self.attach(playerView: playerView, to: boundSurface)
            }

            try playerView.prepareToPlay(withMode: playerType)

            self.playerView = playerView
            self.backgroundKeeper = KollusBackgroundAudioKeeper(
                playerView: playerView,
                isEnabled: environment?.audioBackgroundPlayPolicy ?? false
            )

            return PlaybackState(
                status: .readyToPlay,
                currentTime: playerView.content?.position ?? 0,
                duration: playerView.content?.duration ?? 0,
                isBuffering: false
            )
        }

        transition(to: preparedState)
    }

    // MARK: - Signal handling (bootstrapped path)

    // MARK: - Position polling (재생바 시간 주기 갱신)

    private func startPositionPolling() {
        guard positionPollTask == nil else { return }
        positionPollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: Self.positionPollInterval)
                guard let self else { return }
                if Task.isCancelled { return }
                await self.pollCurrentPlaybackTime()
            }
        }
    }

    private func stopPositionPolling() {
        positionPollTask?.cancel()
        positionPollTask = nil
    }

    private func pollCurrentPlaybackTime() async {
        let snapshot = await MainActor.run { () -> (time: TimeInterval, isSeeking: Bool)? in
            guard let playerView else { return nil }
            return (playerView.currentPlaybackTime, playerView.isSeeking)
        }
        guard let snapshot, !snapshot.isSeeking else { return }
        let polled = snapshot.time
        // 레거시 주석(LegacyMoviePlayerController.m:5603/5627) — play 직후/pause 시 SDK가
        // currentPlaybackTime을 0으로 반환하는 이슈. 기존 위치가 있으면 0 회귀를 무시한다.
        if polled <= 0, state.currentTime > 0 { return }
        guard polled != state.currentTime else { return }
        let nextState = state.updating(currentTime: polled)
        transition(to: nextState, emitStateEvent: false)
        publish(event: .timeDidChange(currentTime: polled, duration: nextState.duration))
        // Core 권위 경로: polling 위치는 handleSignal 밖이라 별도로 outputStream에 발행해야
        // Core(outputStream 소비)가 재생바를 갱신한다. (device QA B2에서 발견)
        outputContinuation.yield(.stateInput(.positionChanged(time: polled, duration: nextState.duration)))
        #if DEBUG
        NSLog("[Kollus.out] poll positionChanged time=%.3f", polled)
        #endif
        emitNextEpisodeIfNeeded(currentTime: polled)
    }

    func handleSignal(_ signal: KollusEngineSignal) async {
        // B안 권위 경로: 신호를 매퍼로 정규화해 outputStream에 발행한다(Core가 reducer로 소비).
        // 아래 switch는 전환기 mirror(eventStream/state) + 부수효과(polling/prepare continuation/
        // next-episode)를 그대로 유지한다.
        await emitOutput(signal)

        switch signal {
        case .prepareToPlayCompleted(let error):
            if let error {
                let pe = playerError(from: error, operation: "prepareToPlay")
                transition(to: state.updating(status: .failed(pe), isBuffering: false))
                if pendingPrepareContinuation != nil {
                    completePendingPrepare(with: .failure(pe))
                } else {
                    publish(event: .didFail(pe))
                }
            } else {
                // 레거시 `MegaStudyMoviePlayerController.completePreparationToPlay` parity —
                // Kollus SDK 는 prepare 완료 시점에 audioBackgroundPlay 를 내부 player 에 latch 한다.
                // view-config(prepare 진입) 시점 1회 설정은 SDK 내부 player 준비 전이라 누락되어
                // 백그라운드 진입 시 SDK 가 강제 pause(userInteraction:false) 를 낸다.
                // 준비 완료 콜백에서 재적용해 백그라운드 오디오 재생을 유지한다.
                let allowsBackgroundAudio = environment?.audioBackgroundPlayPolicy ?? false
                await MainActor.run { [weak self] in
                    self?.playerView?.audioBackgroundPlay = allowsBackgroundAudio
                }
                let snapshot = await readyStateSnapshot()
                transition(to: snapshot)
                completePendingPrepare(with: .success(()))
            }

        case .playStarted(_, let error):
            if let error {
                handleFailure(playerError(from: error, operation: "play"))
                return
            }
            transition(to: state.updating(status: .playing, isBuffering: false))
            startPositionPolling()

        case .pauseStarted(_, let error):
            if let error {
                handleFailure(playerError(from: error, operation: "pause"))
                return
            }
            stopPositionPolling()
            transition(to: state.updating(status: .paused, isBuffering: false))

        case .bufferingChanged(let buffering, _, let error):
            if let error {
                handleFailure(playerError(from: error, operation: "buffering"))
                return
            }
            // M3 — terminal 상태(.finished/.failed)는 늦은 buffering 이벤트로 되살리지 않는다.
            if case .finished = state.status {
                publish(event: .bufferingDidChange(isBuffering: buffering))
                return
            }
            if case .failed = state.status {
                publish(event: .bufferingDidChange(isBuffering: buffering))
                return
            }
            let nextStatus: PlaybackState.Status
            if buffering {
                nextStatus = .buffering
            } else if case .readyToPlay = state.status {
                nextStatus = .readyToPlay
            } else {
                nextStatus = .playing
            }
            transition(to: state.updating(status: nextStatus, isBuffering: buffering), emitStateEvent: false)
            publish(event: .bufferingDidChange(isBuffering: buffering))

        case .stopStarted(let userInteraction, let error):
            if let error {
                handleFailure(playerError(from: error, operation: "stop"))
                return
            }
            stopPositionPolling()
            let nextStatus: PlaybackState.Status = userInteraction ? .idle : .finished
            transition(to: state.updating(status: nextStatus, isBuffering: false))
            if nextStatus == .finished {
                publish(event: .didFinish)
            }

        case .positionChanged(let time, let isSeeking):
            guard !isSeeking else { return }
            let nextState = state.updating(currentTime: time)
            transition(to: nextState, emitStateEvent: false)
            publish(event: .timeDidChange(currentTime: time, duration: nextState.duration))
            // T056 — 다음 회차 진입 시간 도달 검사 (컨텐츠당 1회). 캐시된 메타로 산술 비교만 — MainActor 왕복 없음.
            emitNextEpisodeIfNeeded(currentTime: time)

        case .unknownError(let error):
            let pe = playerError(from: error, operation: "unknown")
            transition(to: state.updating(status: .failed(pe), isBuffering: false))
            publish(event: .didFail(pe))

        case .captionUpdated(_, let caption):
            publish(event: .captionDidUpdate(text: caption, isSecondary: false))

        case .subCaptionUpdated(_, let caption):
            publish(event: .captionDidUpdate(text: caption, isSecondary: true))

        case .naturalSizeResolved(let size):
            publish(event: .naturalSizeDidResolve(size))

        case .framerateResolved(let framerate):
            publish(event: .framerateDidResolve(framerate))

        case .externalOutputEnabledChanged(let enabled):
            publish(event: .externalOutputDidChange(enabled: enabled))

        case .devicePolicyLocked:
            publish(event: .deviceLockPolicyChanged(locked: true))

        case .hlsHeightChanged(let height):
            publish(event: .heightDidChange(height))

        case .hlsBitrateChanged(let bitrate):
            publish(event: .bitrateDidChange(bitrate))

        case .scrollChanged,
             .zoomChanged,
             .contentModeChanged,
             .contentFrameChanged,
             .playbackRateChanged,
             .repeatChanged,
             .thumbnailReady,
             .mediaContentKeyResolved:
            // 도메인 중립 PlayerEvent로 표현되지 않는 vendor-specific 신호.
            // diagnostics sink는 KollusDelegateBridge에서 이미 forward됨.
            break
        }
    }

    private func handleBookmarks(_ bookmarks: [Bookmark]) {
        lastKnownBookmarks = bookmarks
        publish(event: .bookmarksDidLoad(bookmarks))
        // Core 권위 경로 (handleSignal 밖 emit — bookmarks 로드).
        outputContinuation.yield(.event(.bookmarksDidLoad(bookmarks)))
    }

    /// 신호를 매퍼로 정규화해 outputStream에 발행한다(Core 권위 경로).
    /// 부수효과(polling/prepare continuation/next-episode)는 `handleSignal`의 switch가 담당한다.
    private func emitOutput(_ signal: KollusEngineSignal) async {
        guard let output = await KollusSignalMapper.normalize(
            signal,
            preparedSnapshot: { await self.makePlaybackPreparedSnapshot() },
            mapError: { self.playerError(from: $0, operation: $1) }
        ) else {
            return
        }
        #if DEBUG
        // device QA: Kollus 신호 → outputStream 발행 추적. (followup-spec §6)
        NSLog("[Kollus.out] %@ -> %@", String(describing: signal), String(describing: output))
        #endif
        outputContinuation.yield(output)
    }

    /// prepare 완료 스냅샷 — SDK에서 position/duration/live만 조회한다(부수효과 없음).
    /// next-episode 메타 캐시/`hasEmittedNextEpisode` 리셋은 `readyStateSnapshot`이 계속 담당한다.
    private func makePlaybackPreparedSnapshot() async -> PlaybackPreparedSnapshot {
        await MainActor.run {
            let view = playerView
            let liveDuration = view?.liveDuration ?? 0
            return PlaybackPreparedSnapshot(
                position: view?.content?.position ?? 0,
                duration: view?.content?.duration ?? 0,
                isLive: view?.isLive ?? false,
                liveDuration: liveDuration > 0 ? liveDuration : nil
            )
        }
    }

    private func installPrepareContinuation(_ continuation: CheckedContinuation<Void, Error>) {
        pendingPrepareContinuation?.resume(throwing: CancellationError())
        pendingPrepareContinuation = continuation
    }

    private func completePendingPrepare(with result: Result<Void, Error>) {
        guard let continuation = pendingPrepareContinuation else { return }
        pendingPrepareContinuation = nil

        switch result {
        case .success:
            continuation.resume()
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }

    /// T056 — 다음 회차 진입 시간 도달 검사. **동기·산술 전용**(MainActor 왕복 없음).
    /// 메타는 `readyStateSnapshot`에서 1회 캐시되므로 positionChanged마다 호출돼도 consumer를 막지 않는다.
    private func emitNextEpisodeIfNeeded(currentTime: TimeInterval) {
        guard !hasEmittedNextEpisode, let meta = nextEpisodeMeta else { return }
        guard currentTime >= meta.showAt else { return }
        guard let url = meta.callbackURL else { return }
        hasEmittedNextEpisode = true
        let info = NextEpisodeInfo(
            showAt: meta.showAt,
            callbackURL: url,
            callbackParameters: meta.params,
            showsButton: meta.showsButton
        )
#if DEBUG
        NSLog("[KollusNextEpisode] publish nextEpisodeAvailable showAt=%.3f", info.showAt)
        NSLog("[Kollus.out] event nextEpisodeAvailable showAt=%.3f", info.showAt)
#endif
        publish(event: .nextEpisodeAvailable(info))
        // Core 권위 경로 (device QA B6에서 발견 — handleSignal 밖 emit).
        outputContinuation.yield(.event(.nextEpisodeAvailable(info)))
    }

    private func readyStateSnapshot() async -> PlaybackState {
        struct ReadySnapshot {
            let position: TimeInterval
            let duration: TimeInterval
            let isLive: Bool
            let liveDuration: TimeInterval
            let nextEpisodeShowAt: TimeInterval
            let nextEpisodeCallbackURLString: String?
            let nextEpisodeParams: [String: String]
            let nextEpisodeShowsButton: Bool
        }
        let snap = await MainActor.run { () -> ReadySnapshot in
            let view = playerView
            let rawParams = view?.nextEpisodeCallbackParams as? [String: Any] ?? [:]
            let params: [String: String] = Dictionary(uniqueKeysWithValues: rawParams.compactMap { key, value in
                guard let v = value as? String else { return nil }
                return (key, v)
            })
            return ReadySnapshot(
                position: view?.content?.position ?? 0,
                duration: view?.content?.duration ?? 0,
                isLive: view?.isLive ?? false,
                liveDuration: view?.liveDuration ?? 0,
                nextEpisodeShowAt: TimeInterval(view?.nextEpisodeShowTime ?? 0),
                nextEpisodeCallbackURLString: view?.nextEpisodeCallbackURL,
                nextEpisodeParams: params,
                nextEpisodeShowsButton: view?.nextEpisodeShowButton ?? false
            )
        }
        // 다음 회차 메타 1회 캐시 + 재진입 시 재-probe 위해 emit 플래그 리셋.
        // 엔진 next-episode가 없으면(showAt<=0) nil → positionChanged hot path 즉시 단락.
        hasEmittedNextEpisode = false
        if snap.nextEpisodeShowAt > 0 {
            nextEpisodeMeta = NextEpisodeMeta(
                showAt: snap.nextEpisodeShowAt,
                callbackURL: snap.nextEpisodeCallbackURLString.flatMap { URL(string: $0) },
                params: snap.nextEpisodeParams,
                showsButton: snap.nextEpisodeShowsButton
            )
        } else {
            nextEpisodeMeta = nil
        }
        // T055 — isLive/liveDuration 캡처. liveDuration 0이면 nil 표기(타임쉬프트 길이 unknown).
        let liveDurationValue: TimeInterval? = snap.liveDuration > 0 ? snap.liveDuration : nil
        return state.updating(
            status: .readyToPlay,
            currentTime: snap.position,
            duration: snap.duration,
            isBuffering: false,
            isLive: snap.isLive,
            liveDuration: .some(liveDurationValue)
        )
    }

    /// T057 — 현재 컨텐츠 메타데이터 스냅샷.
    public func currentContent() async -> KollusContentSnapshot? {
        await MainActor.run {
            guard let content = playerView?.content else { return nil }
            return Self.snapshot(from: content)
        }
    }

    @MainActor
    private static func snapshot(from content: KollusContent) -> KollusContentSnapshot {
        KollusContentSnapshot.fromSDKContent(content)
    }

    // MARK: - Performers

    private func performPlay() async throws {
        try await MainActor.run {
            guard let playerView else {
                throw PlayerError.engineError("Kollus playerView가 준비되지 않았습니다.")
            }
            try playerView.play()
        }
    }

    private func performPause() async throws {
        try await MainActor.run {
            guard let playerView else {
                throw PlayerError.engineError("Kollus playerView가 준비되지 않았습니다.")
            }
            try playerView.pause()
        }
    }

    private func performStop() async throws {
        stopPositionPolling()
        try await MainActor.run {
            if let playerView {
                try playerView.stop()
                playerView.removeFromSuperview()
            }
            self.playerView = nil
            self.bridge = nil
            self.backgroundKeeper = nil
        }
    }

    private func stateAfterStop(reason: PlayerStopReason) -> PlaybackState {
        switch reason {
        case .finished:
            state.updating(status: .finished, isBuffering: false)
        case .userClosed, .replacedSource, .appLifecycle:
            .idle
        }
    }

    @MainActor
    private func attach(playerView: KollusPlayerView, to renderSurface: PlayerRenderSurface) {
        playerView.removeFromSuperview()
        playerView.frame = renderSurface.containerView.bounds
        playerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        renderSurface.containerView.addSubview(playerView)
    }

    private func transition(to nextState: PlaybackState, emitStateEvent: Bool = true) {
        state = nextState
        if emitStateEvent {
            publish(event: .stateDidChange(nextState))
        }
    }

    /// SDK 신호 에러 → PlayerError. 사용자 메시지는 SDK `localizedDescription`을 그대로 노출한다
    /// (레거시 `SLKollusManager.errorMessageWithError:` parity — "Kollus X 실패:" 같은 dev 접두 없음).
    /// 네트워크/인증/디코딩은 classify가 분류(NSURLErrorDomain 등), 그 외는 접두 없는 engineError.
    /// 실패한 작업(operation)은 DEBUG 로그에만 남긴다.
    private func playerError(from error: Error, operation: String) -> PlayerError {
        if let playerError = error as? PlayerError {
            return playerError
        }
        let classified = PlayerError.classify(error)
        if case .unknown(let message) = classified {
#if DEBUG
            NSLog("[KollusEngine] %@ 실패: %@", operation, message)
#endif
            return .engineError(message)
        }
        return classified
    }

    private func handleFailure(_ error: PlayerError) {
        stopPositionPolling()
        let nextState = state.updating(status: .failed(error), isBuffering: false)
        transition(to: nextState)
        publish(event: .didFail(error))
    }

    private func publish(event: PlayerEvent) {
        eventContinuation.yield(event)
    }

    private static func scalingMode(mode: PlayerDisplayScaleMode) -> KollusPlayerContentMode {
        switch mode {
        case .aspectFit:
            return .scaleAspectFit
        case .aspectFill:
            return .scaleAspectFill
        case .fill:
            return .scaleFill
        }
    }

    private static func displayScaleMode(for scalingMode: KollusPlayerContentMode) -> PlayerDisplayScaleMode {
        switch scalingMode {
        case .scaleAspectFit:
            return .aspectFit
        case .scaleAspectFill:
            return .aspectFill
        case .scaleFill:
            return .fill
        @unknown default:
            return .aspectFit
        }
    }

    @MainActor
    private static func makePlayerView(for source: PlaybackSource) -> KollusPlayerView? {
        switch source {
        case .kollus(let key):
            return KollusPlayerView(mediaContentKey: key)
        case .url(let url):
            return KollusPlayerView(contentURL: url.absoluteString)
        }
    }
}
