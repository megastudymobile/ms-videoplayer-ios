#if canImport(UIKit)
//
//  PlayerSkinFeatureGatingTests.swift
//  VideoPlayerModuleTests
//
//  Created by JunyoungJung on 2026/06/11.
//

import Testing
import UIKit
import VideoPlayerCore
@testable import VideoPlayerSkin

/// 조건 신고 probe — requiredFeatures 를 주입받아 override 한다.
@MainActor
private final class GatedProbeBlock: PlayerSkinBlock {
    let view = UIView()
    var onAction: ((PlayerSkinAction) -> Void)?
    let requiredFeatures: Set<PlayerFeature>

    init(requiredFeatures: Set<PlayerFeature>) {
        self.requiredFeatures = requiredFeatures
    }

    func render(_ state: PlayerSkinState, theme: PlayerSkinTheme) {}
}

/// 기본값 [] probe — override 안 함. 게이팅 대상이 아니어야 한다.
@MainActor
private final class PlainProbeBlock: PlayerSkinBlock {
    let view = UIView()
    var onAction: ((PlayerSkinAction) -> Void)?
    func render(_ state: PlayerSkinState, theme: PlayerSkinTheme) {}
}

@MainActor
struct PlayerSkinFeatureGatingTests {
    private func makeSkin(appending block: PlayerSkinBlock) -> AssembledPlayerSkin {
        var blueprint = PlayerSkinBlueprint.default
        blueprint.blocks[.topTrailing, default: []].append { block }
        return AssembledPlayerSkin(blueprint: blueprint)
    }

    @Test("조건 블록은 apply 호출 전까지 숨김 — 깜빡임 방지")
    func gatedBlockHiddenBeforeApply() {
        let probe = GatedProbeBlock(requiredFeatures: [.bookmarks])
        _ = makeSkin(appending: probe)
        #expect(probe.view.isHidden)
    }

    @Test("feature 충족 시 노출, 재호출로 미충족되면 다시 숨김")
    func applyTogglesVisibility() {
        let probe = GatedProbeBlock(requiredFeatures: [.bookmarks])
        let skin = makeSkin(appending: probe)

        skin.apply(availableFeatures: [.bookmarks, .playbackRate])
        #expect(probe.view.isHidden == false)

        skin.apply(availableFeatures: [.playbackRate])
        #expect(probe.view.isHidden)
    }

    @Test("복수 feature 조건은 전부 충족해야 노출")
    func multipleRequiredFeaturesNeedAll() {
        let probe = GatedProbeBlock(requiredFeatures: [.bookmarks, .titledBookmarks])
        let skin = makeSkin(appending: probe)

        skin.apply(availableFeatures: [.bookmarks])
        #expect(probe.view.isHidden)

        skin.apply(availableFeatures: [.bookmarks, .titledBookmarks])
        #expect(probe.view.isHidden == false)
    }

    @Test("기본값 [] 블록은 조립 직후부터 항상 노출 — apply 가 isHidden 을 만지지 않는다")
    func plainBlockUnaffected() {
        let probe = PlainProbeBlock()
        let skin = makeSkin(appending: probe)
        #expect(probe.view.isHidden == false)

        skin.apply(availableFeatures: [])
        #expect(probe.view.isHidden == false)
    }
}
#endif
