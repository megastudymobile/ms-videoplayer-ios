//
//  PlayerSkinOverlaySlot.swift
//  VideoPlayerSkin
//  Copyright © 2026 megastudyedu. All rights reserved.
//

/// control block 과 별도로 skin 위에 고정 배치되는 overlay 영역.
public enum PlayerSkinOverlaySlot: Hashable, Sendable, CaseIterable {
    case caption
    case loading
    case gestureHUD
}

/// overlay 는 slot 별 역할이 다르므로 factory 는 공통 base overlay 로 보관하고,
/// AssembledPlayerSkin 이 slot 에 맞는 세부 protocol 을 검증한다.
public typealias PlayerSkinOverlayFactory = @MainActor () -> PlayerSkinOverlay

public extension Dictionary where Key == PlayerSkinOverlaySlot, Value == PlayerSkinOverlayFactory {
    static var `default`: Self {
        [
            .caption: { PlayerCaptionView() },
            .loading: { PlayerLoadingIndicatorView() },
            .gestureHUD: { PlayerGestureHUDView() }
        ]
    }
}

extension Dictionary where Key == PlayerSkinOverlaySlot, Value == PlayerSkinOverlayFactory {
    @MainActor
    func makeCaptionOverlay() -> PlayerSkinCaptionOverlay {
        guard let overlay = makeOverlay(.caption) as? PlayerSkinCaptionOverlay else {
            preconditionFailure("PlayerSkin overlay factory returned invalid type. slot=caption, expected=PlayerSkinCaptionOverlay")
        }
        return overlay
    }

    @MainActor
    func makeLoadingOverlay() -> PlayerSkinLoadingOverlay {
        guard let overlay = makeOverlay(.loading) as? PlayerSkinLoadingOverlay else {
            preconditionFailure("PlayerSkin overlay factory returned invalid type. slot=loading, expected=PlayerSkinLoadingOverlay")
        }
        return overlay
    }

    @MainActor
    func makeGestureHUDOverlay() -> PlayerSkinGestureHUDOverlay {
        guard let overlay = makeOverlay(.gestureHUD) as? PlayerSkinGestureHUDOverlay else {
            preconditionFailure("PlayerSkin overlay factory returned invalid type. slot=gestureHUD, expected=PlayerSkinGestureHUDOverlay")
        }
        return overlay
    }

    @MainActor
    private func makeOverlay(_ slot: PlayerSkinOverlaySlot) -> PlayerSkinOverlay {
        guard let make = self[slot] else {
            preconditionFailure("PlayerSkin overlay factory missing. slot=\(slot)")
        }
        return make()
    }
}
