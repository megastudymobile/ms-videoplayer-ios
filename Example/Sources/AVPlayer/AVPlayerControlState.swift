//
//  AVPlayerControlState.swift
//  VideoPlayerExample
//
//  Created by 모바일팀_정준영 on 2026/05/17.
//

import Foundation
import VideoPlayerCore

struct AVPlayerControlState: Equatable {
    let status: PlaybackState.Status
    let statusText: String
    let timeText: String
    let progress: Double
    let selectedRate: Double
    let allowedRates: [Double]
    let playPauseTitle: String
    let isPlayPauseEnabled: Bool
    let isStopEnabled: Bool
    let isSeekEnabled: Bool
    let isRateSelectionEnabled: Bool
    let isDisplayScaled: Bool
    let errorMessage: String?

    static let idle = AVPlayerControlState(
        status: .idle,
        statusText: "대기",
        timeText: "00:00 / 00:00",
        progress: 0,
        selectedRate: 1.0,
        allowedRates: [0.75, 1.0, 1.25, 1.5, 2.0],
        playPauseTitle: "Play",
        isPlayPauseEnabled: false,
        isStopEnabled: false,
        isSeekEnabled: false,
        isRateSelectionEnabled: false,
        isDisplayScaled: false,
        errorMessage: nil
    )
}
