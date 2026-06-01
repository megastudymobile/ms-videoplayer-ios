//
//  StartPlaybackUseCase.swift
//  VideoPlayerModule
//
//  Created by 모바일개발팀_정준영 on 2026/04/17.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

import Foundation

@MainActor
public protocol StartPlaybackUseCaseProtocol {
    func execute(source: PlaybackSource, policy: PlayerFeaturePolicy) async throws
}

@MainActor
public final class DefaultStartPlaybackUseCase: StartPlaybackUseCaseProtocol {
    private let core: PlayerCore

    public init(core: PlayerCore) {
        self.core = core
    }

    public func execute(source: PlaybackSource, policy: PlayerFeaturePolicy) async throws {
        try await core.start(source: source, policy: policy)
    }
}
