//
//  KollusPositionPoller.swift
//  VideoPlayerModule
//
//  Created by 모바일팀_정준영 on 2026/06/10.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import Foundation

/// 재생 위치 주기 폴러.
///
/// Kollus `kollusPlayerView:position:error:` delegate는 **seek 시에만** 호출되고 재생 중
/// 주기 통지를 하지 않는다 — 재생바 currentTime 갱신을 위해 주기 폴링으로 보완한다.
///
/// adapter actor가 소유하는 actor-isolated 상태로 사용한다 — start/stop은 동기라
/// 신호 처리 순서(playStarted 시작, pause/stop 중지)가 결정적으로 유지된다.
final class KollusPositionPoller {
    private var task: Task<Void, Never>?
    private let interval: UInt64
    private let tick: @Sendable () async -> Void

    init(
        interval: UInt64 = 500_000_000, // 0.5s
        tick: @escaping @Sendable () async -> Void
    ) {
        self.interval = interval
        self.tick = tick
    }

    deinit {
        task?.cancel()
    }

    func start() {
        guard task == nil else { return }
        task = Task { [interval, tick] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: interval)
                if Task.isCancelled { return }
                await tick()
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}
