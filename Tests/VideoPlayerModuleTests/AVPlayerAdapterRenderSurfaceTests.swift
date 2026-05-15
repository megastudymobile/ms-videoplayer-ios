//
//  AVPlayerAdapterRenderSurfaceTests.swift
//  SmartPlayer
//
//  Created by 정준영 on 2026/04/20.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

#if canImport(UIKit)

import AVFoundation
import Foundation
import Testing
import UIKit
@testable import VideoPlayerModule

@Suite("AVPlayer adapter render surface")
struct AVPlayerAdapterRenderSurfaceTests {
    @Test("Bind attaches player layer to surface")
    @MainActor
    func bindAttachesPlayerLayerToSurface() async throws {
        let adapter = AVPlayerAdapter(player: AVPlayer())
        let surface = TestRenderSurface()

        await adapter.bind(renderSurface: surface)

        try await waitUntil {
            await MainActor.run {
                surface.attachCount == 1 &&
                surface.detachCount == 0 &&
                surface.playerLayerCount == 1
            }
        }
    }

    @Test("Rebind detaches previous surface and moves player layer")
    @MainActor
    func rebindDetachesPreviousSurfaceAndMovesPlayerLayer() async throws {
        let adapter = AVPlayerAdapter(player: AVPlayer())
        let firstSurface = TestRenderSurface()
        let secondSurface = TestRenderSurface()

        await adapter.bind(renderSurface: firstSurface)
        try await waitUntil {
            await MainActor.run { firstSurface.playerLayerCount == 1 }
        }

        await adapter.bind(renderSurface: secondSurface)

        try await waitUntil {
            await MainActor.run {
                firstSurface.attachCount == 1 &&
                firstSurface.detachCount == 1 &&
                firstSurface.playerLayerCount == 0 &&
                secondSurface.attachCount == 1 &&
                secondSurface.detachCount == 0 &&
                secondSurface.playerLayerCount == 1
            }
        }
    }

    @Test("Unbind detaches current surface and removes player layer")
    @MainActor
    func unbindDetachesCurrentSurfaceAndRemovesPlayerLayer() async throws {
        let adapter = AVPlayerAdapter(player: AVPlayer())
        let surface = TestRenderSurface()

        await adapter.bind(renderSurface: surface)
        try await waitUntil {
            await MainActor.run { surface.playerLayerCount == 1 }
        }

        await adapter.unbindRenderSurface()

        try await waitUntil {
            await MainActor.run {
                surface.attachCount == 1 &&
                surface.detachCount == 1 &&
                surface.playerLayerCount == 0
            }
        }
    }

    private func waitUntil(
        timeout: TimeInterval = 1.0,
        pollInterval: UInt64 = 10_000_000,
        condition: @escaping @Sendable () async -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if await condition() {
                return
            }

            try await Task.sleep(nanoseconds: pollInterval)
        }

        throw WaitUntilTimeoutError()
    }
}

private struct WaitUntilTimeoutError: Error, CustomStringConvertible {
    let description = "조건을 만족하지 못했습니다."
}

private final class TestRenderSurface: PlayerRenderSurface {
    let containerView: UIView = {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 180))
        view.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        return view
    }()

    private(set) var attachCount = 0
    private(set) var detachCount = 0

    var playerLayerCount: Int {
        containerView.layer.sublayers?.compactMap { $0 as? AVPlayerLayer }.count ?? 0
    }

    func engineDidAttach() {
        attachCount += 1
    }

    func engineDidDetach() {
        detachCount += 1
    }
}

#endif
