//
//  ControlPlaybackUseCase.swift
//  VideoPlayerModule
//
//  Created by 모바일개발팀_정준영 on 2026/04/17.
//  Copyright © 2026 VideoPlayerModule contributors. All rights reserved.
//

import Foundation

@MainActor
public protocol ControlPlaybackUseCaseProtocol {
    func execute(command: PlaybackCommand) async throws
}

@MainActor
public final class DefaultControlPlaybackUseCase: ControlPlaybackUseCaseProtocol {
    private let core: PlayerCore

    public init(core: PlayerCore) {
        self.core = core
    }

    public func execute(command: PlaybackCommand) async throws {
        try await core.execute(command: command)
    }
}
