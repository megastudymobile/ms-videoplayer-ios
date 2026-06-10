//
//  ScreenPlaybackSettingViewController.swift
//  VideoPlayerExample
//
//  Created by JunyoungJung on 2026/06/09.
//
//  화면/재생 설정 — SLSettingPlayerScreenPlaybackViewController parity.
//  배속/자막은 변경 즉시 재생에 반영(PlayerControlChannel). 시크 간격은 매 skip 시 PreferenceManager 를 읽어 라이브.
//  persist-only(재생 효과 없음): 화면 제스처 사용 / 다음 강의 자동 재생 / 무음모드 소리 강제 재생 / 백그라운드(다음 재생).
//

import UIKit

@MainActor
final class ScreenPlaybackSettingViewController: SettingsListViewController {
    override var screenTitle: String { "화면/재생 설정" }

    override func buildSections() -> [SettingSection] {
        var screenItems: [SettingItem] = [
            // 설명 전용 — useGesture 는 detail("사용 중/안함") 표시용 persist-only.
            SettingItem(
                title: "플레이어 제스처",
                isNew: true,
                accessory: .navigation(
                    detail: { PreferenceManager.useGesture ? "사용 중" : "사용 안함" },
                    makeViewController: { GestureViewController() }
                )
            ),
            // persist-only: 데모에 다음 강의 없음.
            SettingItem(
                title: "다음 강의 자동 재생",
                description: "다음 강의가 있는 경우 자동 재생됩니다.",
                isNew: true,
                accessory: .toggle(
                    get: { PreferenceManager.nextLectureAutoPlayMode },
                    set: { PreferenceManager.nextLectureAutoPlayMode = $0 }
                )
            )
        ]
        // 백그라운드 재생 — 다음 재생 시 반영. SL 과 동일하게 iOS 17+ 한정.
        if #available(iOS 17.0, *) {
            screenItems.append(
                SettingItem(
                    title: "백그라운드 재생",
                    description: "앱이 백그라운드에서 실행 중이거나, 잠금 화면인 경우에도 강의가 재생됩니다.",
                    isNew: true,
                    accessory: .toggle(
                        get: { PreferenceManager.isBackgroundAudioPlay },
                        set: { PreferenceManager.isBackgroundAudioPlay = $0 }
                    )
                )
            )
        }
        screenItems.append(contentsOf: [
            // 다음 재생 시 반영 — 플레이어 생성 시 PlayerFeaturePolicy.allowsSeekPreview 로 주입.
            SettingItem(
                title: "시킹 미리보기 썸네일",
                description: "재생바 드래그 중 썸네일 미리보기를 표시합니다. 다음 재생부터 적용됩니다.",
                isNew: true,
                accessory: .toggle(
                    get: { PreferenceManager.useSeekPreview },
                    set: { PreferenceManager.useSeekPreview = $0 }
                )
            ),
            // persist-only: AppDelegate 가 이미 .playback 고정.
            SettingItem(
                title: "무음 모드에서 소리 강제 재생",
                accessory: .toggle(
                    get: { PreferenceManager.playSoundInSilentMode },
                    set: { PreferenceManager.playSoundInSilentMode = $0 }
                )
            ),
            // 라이브: 매 skip 시 PreferenceManager.seekRangeSeconds 를 읽어 적용.
            SettingItem(
                title: "앞으로 이동/뒤로 이동",
                accessory: .stepper(
                    value: { (SeekRange(rawValue: PreferenceManager.seekRange) ?? .r10).title },
                    canDecrement: { Self.seekIndex() > 0 },
                    canIncrement: { Self.seekIndex() < SeekRange.allCases.count - 1 },
                    onDecrement: { [weak self] in self?.stepSeek(-1) },
                    onIncrement: { [weak self] in self?.stepSeek(+1) }
                )
            ),
            // 라이브: setCaptionFontSize 즉시 적용. SL parity — "메가스터디" 샘플을 선택 크기로 미리보기.
            SettingItem(
                title: "자막",
                attributedDescription: Self.captionSample(),
                accessory: .stepper(
                    value: { "\((SubtitleSize(rawValue: PreferenceManager.subtitleSize) ?? .normal).fontSize)P" },
                    canDecrement: { Self.subtitleIndex() > 0 },
                    canIncrement: { Self.subtitleIndex() < SubtitleSize.allCases.count - 1 },
                    onDecrement: { [weak self] in self?.stepSubtitle(-1) },
                    onIncrement: { [weak self] in self?.stepSubtitle(+1) }
                )
            )
        ])

        return [
            SettingSection(title: "화면/재생", items: screenItems),
            SettingSection(title: "배속", items: [
                // 라이브: setPlaybackRate 즉시 적용.
                SettingItem(
                    title: "기본 배속",
                    description: "설정한 기본 배속으로 재생되며, 플레이어에서 배속 변경 시 자동 반영됩니다.",
                    accessory: .stepper(
                        value: { PlaybackRate.title(PreferenceManager.playbackRate) },
                        canDecrement: { PreferenceManager.playbackRate > PlaybackRate.min + 0.001 },
                        canIncrement: { PreferenceManager.playbackRate < PlaybackRate.max - 0.001 },
                        onDecrement: { [weak self] in self?.stepRate(-1) },
                        onIncrement: { [weak self] in self?.stepRate(+1) }
                    )
                )
            ]),
            SettingSection(title: "고급 설정", items: [
                // 다음 재생 시 반영(hardwareDecoderPreferred → KollusEnvironment).
                SettingItem(
                    title: "디코딩 방식 선택",
                    description: "기기 최적 플레이어로 배터리 소모 및 발열 증상이 완화됩니다.",
                    accessory: .navigation(
                        detail: { (PlayerCodec(rawValue: PreferenceManager.playerCodec) ?? .nativePlayer).title },
                        makeViewController: { PlayerCodecViewController() }
                    )
                )
            ])
        ]
    }

    /// SL kSLPlayerSettingCaptionExample = "메가스터디", skyBlue(#3daed6), kern -1.0, 선택 크기.
    private static func captionSample() -> NSAttributedString {
        let size = CGFloat((SubtitleSize(rawValue: PreferenceManager.subtitleSize) ?? .normal).fontSize)
        return NSAttributedString(string: "메가스터디", attributes: [
            .font: SLFont.captionSample(size: size),
            .foregroundColor: SLPalette.skyBlue,
            .kern: -1.0
        ])
    }

    // MARK: - 스테퍼 인덱스/변경

    private static func seekIndex() -> Int {
        SeekRange.allCases.firstIndex(of: SeekRange(rawValue: PreferenceManager.seekRange) ?? .r10) ?? 0
    }

    private static func subtitleIndex() -> Int {
        SubtitleSize.allCases.firstIndex(of: SubtitleSize(rawValue: PreferenceManager.subtitleSize) ?? .normal) ?? 0
    }

    private func stepSeek(_ delta: Int) {
        let cases = SeekRange.allCases
        let next = min(max(Self.seekIndex() + delta, 0), cases.count - 1)
        PreferenceManager.seekRange = cases[next].rawValue
        reloadSections()   // 시크 간격은 다음 skip 부터 PreferenceManager 를 읽어 즉시 반영.
    }

    private func stepSubtitle(_ delta: Int) {
        let cases = SubtitleSize.allCases
        let next = min(max(Self.subtitleIndex() + delta, 0), cases.count - 1)
        PreferenceManager.subtitleSize = cases[next].rawValue
        channel?.setCaptionFontSize(PreferenceManager.captionFontSize)   // 라이브 적용
        reloadSections()
    }

    private func stepRate(_ delta: Int) {
        let next = PlaybackRate.clamped(((PreferenceManager.playbackRate * 10).rounded() + Double(delta)) / 10)
        PreferenceManager.playbackRate = next
        channel?.setPlaybackRate(next)   // 라이브 적용
        reloadSections()
    }
}
