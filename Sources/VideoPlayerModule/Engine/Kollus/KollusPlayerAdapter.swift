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

public actor KollusPlayerAdapter:
    PlayerEngineAdapter,
    PlayerPlaybackRateEngine,
    PlayerTitledBookmarkEngine,
    PlayerSubtitleEngine,
    PlayerExternalSubtitleEngine,
    PlayerDisplayScalingEngine,
    PlayerZoomEngine,
    PlayerScrollEngine,
    PlayerAdaptiveStreamingEngine,
    PlayerPiPCapability {
    public nonisolated static let capabilities: EngineCapabilities = []

    public var currentState: PlaybackState {
        state
    }

    public let eventStream: AsyncStream<PlayerEvent>

    private let eventContinuation: AsyncStream<PlayerEvent>.Continuation
    private let bootstrapper: KollusSessionBootstrapper?
    private let environment: KollusEnvironment?
    private let observer: KollusObserver?
    private let diagnostics: KollusDiagnosticsSink?
    private let legacyStorage: KollusStorage?
    private let playerType: KollusPlayerType

    private var state: PlaybackState
    private weak var renderSurface: PlayerRenderSurface?
    private var isDisplayScaled = false
    @MainActor private var playerView: KollusPlayerView?
    @MainActor private var bridge: KollusDelegateBridge?
    /// `setSubTitlePath`에 전달한 C-string의 backing storage.
    /// SDK가 path를 비동기 보관할 가능성에 대비해 NSString을 actor가 retain한다.
    /// utf8String 포인터는 NSString lifetime 동안 유효.
    @MainActor private var subtitlePathBuffer: NSString?
    private var lastKnownBookmarks: [Bookmark] = []
    private var isSubtitleVisible: Bool = true
    private var currentZoom: CGFloat = 0
    private var hasEmittedNextEpisode: Bool = false
    private var isPiPRunning: Bool = false

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
        self.bootstrapper = bootstrapper
        self.environment = environment
        self.observer = observer
        self.diagnostics = diagnostics
        self.legacyStorage = nil
        self.playerType = playerType
        self.state = .idle
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
        self.bootstrapper = nil
        self.environment = nil
        self.observer = nil
        self.diagnostics = nil
        self.legacyStorage = storage
        self.playerType = playerType
        self.state = .idle
    }

    deinit {
        eventContinuation.finish()
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
        await MainActor.run {
            self.playerView?.currentPlaybackTime = clampedTime
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
        isSubtitleVisible = isVisible
        // KollusSDK는 자막 가시성 직접 API를 노출하지 않는다. 정책 다운그레이드 이벤트로 surfacing.
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
        guard playerType.rawValue == 1 else {
            throw PlayerError.engineError("PIP는 KollusPlayerType.native 한정으로 지원됩니다.")
        }
        // KollusSDK는 PIP 직접 API를 노출하지 않음 — 실 구현은 host의 AVPictureInPictureController가 KollusPlayerView 내부 AVPlayer를 사용.
        // 현재 단계에서는 환경 적격성만 검사하고 not-implemented signal을 발행.
        isPiPRunning = true
        publish(event: .policyDowngraded(reason: .custom("PIP 시작 — host AVPictureInPictureController 통합 필요")))
    }

    public func stopPiP() async throws {
        try await MainActor.run {
            guard playerView != nil else {
                throw PlayerError.engineError("Kollus playerView가 준비되지 않았습니다.")
            }
        }
        guard playerType.rawValue == 1 else {
            throw PlayerError.engineError("PIP는 KollusPlayerType.native 한정으로 지원됩니다.")
        }
        isPiPRunning = false
        publish(event: .policyDowngraded(reason: .custom("PIP 중지 — host AVPictureInPictureController 통합 필요")))
    }

    public var isPiPActive: Bool {
        get async {
            isPiPRunning
        }
    }

    // MARK: - PlayerDisplayScalingEngine

    public func setDisplayScaled(_ isScaled: Bool) async throws {
        self.isDisplayScaled = isScaled
        await MainActor.run {
            self.playerView?.scalingMode = Self.scalingMode(isScaled: isScaled)
        }
    }

    public func toggleDisplayScaling() async throws {
        let fallbackValue = !isDisplayScaled
        let nextValue = await MainActor.run {
            if let playerView {
                return playerView.scalingMode != .scaleAspectFill
            }
            return fallbackValue
        }
        try await setDisplayScaled(nextValue)
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
        let isDisplayScaled = self.isDisplayScaled
        let playerType = self.playerType
        let observer = self.observer
        let diagnostics = self.diagnostics

        try await MainActor.run { [weak self] in
            guard let self else { return }
            self.playerView?.removeFromSuperview()

            guard let playerView = Self.makePlayerView(for: source) else {
                throw PlayerError.engineError("KollusPlayerView 초기화에 실패했습니다.")
            }

            // 1) bridge 생성 + 4종 delegate 부착 (prepareToPlay 호출 전 필수)
            let bridge = KollusDelegateBridge(
                onSignal: { signal in
                    Task { [weak self] in
                        await self?.handleSignal(signal)
                    }
                },
                onBookmarks: { bookmarks in
                    Task { [weak self] in
                        await self?.handleBookmarks(bookmarks)
                    }
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
            playerView.scalingMode = Self.scalingMode(isScaled: isDisplayScaled)
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
        }

        // 신규 path에서는 상태 전이를 SDK delegate(prepareToPlayCompleted)에 의존.
        transition(to: state.updating(status: .preparing, isBuffering: false))

        try await MainActor.run {
            guard let playerView else {
                throw PlayerError.engineError("Kollus playerView가 준비되지 않았습니다.")
            }
            // 4) prepareToPlay 호출 — 이후 SDK가 prepareToPlayWithError delegate 호출
            try playerView.prepareToPlay(withMode: playerType)
        }
    }

    private func prepareWithLegacyStorage(source: PlaybackSource) async throws {
        guard let storage = legacyStorage else {
            throw PlayerError.engineError("legacy storage 누락")
        }

        let boundSurface = renderSurface
        let isDisplayScaled = self.isDisplayScaled
        let playerType = self.playerType
        let preparedState = try await MainActor.run { () throws -> PlaybackState in
            self.playerView?.removeFromSuperview()

            guard let playerView = Self.makePlayerView(for: source) else {
                throw PlayerError.engineError("KollusPlayerView 초기화에 실패했습니다.")
            }
            playerView.storage = storage
            playerView.debug = false
            if let proxyPort = environment?.proxyPort, proxyPort > 0 {
                playerView.proxyPort = UInt(proxyPort)
            }
            playerView.scalingMode = Self.scalingMode(isScaled: isDisplayScaled)

            if let boundSurface {
                self.attach(playerView: playerView, to: boundSurface)
            }

            try playerView.prepareToPlay(withMode: playerType)

            self.playerView = playerView

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

    func handleSignal(_ signal: KollusEngineSignal) async {
        switch signal {
        case .prepareToPlayCompleted(let error):
            if let error {
                let pe = PlayerError.engineError("Kollus prepareToPlay 실패: \(error.localizedDescription)")
                transition(to: state.updating(status: .failed(pe), isBuffering: false))
                publish(event: .didFail(pe))
            } else {
                let snapshot = await readyStateSnapshot()
                transition(to: snapshot)
            }

        case .playStarted(_, let error):
            if let error {
                handleFailure(.engineError("Kollus play 실패: \(error.localizedDescription)"))
                return
            }
            transition(to: state.updating(status: .playing, isBuffering: false))

        case .pauseStarted(_, let error):
            if let error {
                handleFailure(.engineError("Kollus pause 실패: \(error.localizedDescription)"))
                return
            }
            transition(to: state.updating(status: .paused, isBuffering: false))

        case .bufferingChanged(let buffering, _, let error):
            if let error {
                handleFailure(.engineError("Kollus buffering 실패: \(error.localizedDescription)"))
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
                handleFailure(.engineError("Kollus stop 실패: \(error.localizedDescription)"))
                return
            }
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
            // T056 — 다음 회차 진입 시간 도달 검사 (컨텐츠당 1회).
            await emitNextEpisodeIfNeeded(currentTime: time)

        case .unknownError(let error):
            let pe = PlayerError.engineError("Kollus unknown error: \(error.localizedDescription)")
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
    }

    private func emitNextEpisodeIfNeeded(currentTime: TimeInterval) async {
        guard !hasEmittedNextEpisode else { return }
        struct NextEpisodeSnapshot {
            let showAt: TimeInterval
            let callbackURLString: String?
            let params: [String: String]
            let showsButton: Bool
        }
        let snapshot = await MainActor.run { () -> NextEpisodeSnapshot? in
            guard let view = playerView else { return nil }
            let showAt = TimeInterval(view.nextEpisodeShowTime)
            guard showAt > 0 else { return nil }
            let rawParams = view.nextEpisodeCallbackParams as? [String: Any] ?? [:]
            let params: [String: String] = Dictionary(uniqueKeysWithValues: rawParams.compactMap { key, value in
                guard let v = value as? String else { return nil }
                return (key, v)
            })
            return NextEpisodeSnapshot(
                showAt: showAt,
                callbackURLString: view.nextEpisodeCallbackURL,
                params: params,
                showsButton: view.nextEpisodeShowButton
            )
        }
        guard let snapshot,
              currentTime >= snapshot.showAt,
              let urlString = snapshot.callbackURLString,
              let url = URL(string: urlString) else {
            return
        }
        hasEmittedNextEpisode = true
        let info = NextEpisodeInfo(
            showAt: snapshot.showAt,
            callbackURL: url,
            callbackParameters: snapshot.params,
            showsButton: snapshot.showsButton
        )
        publish(event: .nextEpisodeAvailable(info))
    }

    private func readyStateSnapshot() async -> PlaybackState {
        struct ReadySnapshot {
            let position: TimeInterval
            let duration: TimeInterval
            let isLive: Bool
            let liveDuration: TimeInterval
        }
        let snap = await MainActor.run { () -> ReadySnapshot in
            ReadySnapshot(
                position: playerView?.content?.position ?? 0,
                duration: playerView?.content?.duration ?? 0,
                isLive: playerView?.isLive ?? false,
                liveDuration: playerView?.liveDuration ?? 0
            )
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
        try await MainActor.run {
            if let playerView {
                try playerView.stop()
                playerView.removeFromSuperview()
            }
            self.playerView = nil
            self.bridge = nil
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

    private func handleFailure(_ error: PlayerError) {
        let nextState = state.updating(status: .failed(error), isBuffering: false)
        transition(to: nextState)
        publish(event: .didFail(error))
    }

    private func publish(event: PlayerEvent) {
        eventContinuation.yield(event)
    }

    private func mapToPlayerError(_ error: Error) -> PlayerError {
        if let playerError = error as? PlayerError {
            return playerError
        }
        return .unknown((error as NSError).localizedDescription)
    }

    private static func scalingMode(isScaled: Bool) -> KollusPlayerContentMode {
        isScaled ? .scaleAspectFill : .scaleAspectFit
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
