//
//  KollusObserverLog.swift
//  VideoPlayerExample
//
//  Created by 모바일팀_정준영 on 2026/05/17.
//
//  Stage 3: KollusObserver와 KollusDiagnosticsSink를 같은 in-memory 버퍼에 합쳐
//  ObserverLogViewController가 보여줄 수 있도록 한다.
//

import Foundation
import VideoPlayerEngineKollus

struct KollusObserverLogEntry: Identifiable, Hashable {
    enum Kind: String {
        case drm
        case lms
        case storedLMS
        case signal
        case marker
    }

    let id = UUID()
    let timestamp: Date
    let kind: Kind
    let title: String
    let detail: String
}

@MainActor
final class KollusObserverLog {
    private(set) var entries: [KollusObserverLogEntry] = []
    private(set) var listeners: [UUID: ([KollusObserverLogEntry]) -> Void] = [:]

    func append(_ entry: KollusObserverLogEntry) {
        entries.append(entry)
        if entries.count > 500 {
            entries.removeFirst(entries.count - 500)
        }
        for listener in listeners.values {
            listener(entries)
        }
    }

    func clear() {
        entries.removeAll()
        for listener in listeners.values {
            listener(entries)
        }
    }

    @discardableResult
    func observe(_ listener: @escaping ([KollusObserverLogEntry]) -> Void) -> UUID {
        let id = UUID()
        listeners[id] = listener
        listener(entries)
        return id
    }

    func cancel(_ id: UUID) {
        listeners.removeValue(forKey: id)
    }
}

final class KollusObserverRecorder: KollusObserver, @unchecked Sendable {
    private let logBox: WeakLogBox

    init(log: KollusObserverLog) {
        self.logBox = WeakLogBox(log)
    }

    private func push(_ entry: KollusObserverLogEntry) {
        let box = logBox
        Task { @MainActor in
            box.value?.append(entry)
        }
    }

    func kollus(didResolveDRM request: [String: Any], response: [String: Any], error: Error?) {
        let detail = """
        request=\(request)
        response=\(response)
        error=\(error.map { String(describing: $0) } ?? "nil")
        """
        push(.init(
            timestamp: Date(),
            kind: .drm,
            title: "DRM resolved",
            detail: detail
        ))
    }

    func kollus(didPostLMS data: String, result: [String: Any]) {
        push(.init(
            timestamp: Date(),
            kind: .lms,
            title: "LMS posted",
            detail: "data=\(data)\nresult=\(result)"
        ))
    }

    func kollusStorage(didCompleteStoredLMS success: Int, failure: Int) {
        push(.init(
            timestamp: Date(),
            kind: .storedLMS,
            title: "Stored LMS flushed",
            detail: "success=\(success) failure=\(failure)"
        ))
    }
}

final class KollusDiagnosticsRecorder: KollusDiagnosticsSink, @unchecked Sendable {
    private let logBox: WeakLogBox

    init(log: KollusObserverLog) {
        self.logBox = WeakLogBox(log)
    }

    func kollus(_ signal: KollusEngineSignal) {
        let entry = KollusObserverLogEntry(
            timestamp: Date(),
            kind: .signal,
            title: Self.title(for: signal),
            detail: String(describing: signal)
        )
        let box = logBox
        Task { @MainActor in
            box.value?.append(entry)
        }
    }

    private static func title(for signal: KollusEngineSignal) -> String {
        switch signal {
        case .prepareToPlayCompleted: return "prepareToPlayCompleted"
        case .playStarted: return "playStarted"
        case .pauseStarted: return "pauseStarted"
        case .bufferingChanged: return "bufferingChanged"
        case .stopStarted: return "stopStarted"
        case .positionChanged: return "positionChanged"
        case .scrollChanged: return "scrollChanged"
        case .zoomChanged: return "zoomChanged"
        case .naturalSizeResolved: return "naturalSizeResolved"
        case .contentModeChanged: return "contentModeChanged"
        case .contentFrameChanged: return "contentFrameChanged"
        case .playbackRateChanged: return "playbackRateChanged"
        case .repeatChanged: return "repeatChanged"
        case .externalOutputEnabledChanged: return "externalOutputEnabledChanged"
        case .unknownError: return "unknownError"
        case .framerateResolved: return "framerateResolved"
        case .devicePolicyLocked: return "devicePolicyLocked"
        case .captionUpdated: return "captionUpdated"
        case .subCaptionUpdated: return "subCaptionUpdated"
        case .thumbnailReady: return "thumbnailReady"
        case .mediaContentKeyResolved: return "mediaContentKeyResolved"
        case .hlsHeightChanged: return "hlsHeightChanged"
        case .hlsBitrateChanged: return "hlsBitrateChanged"
        }
    }
}

private final class WeakLogBox: @unchecked Sendable {
    weak var value: KollusObserverLog?

    init(_ value: KollusObserverLog) {
        self.value = value
    }
}
