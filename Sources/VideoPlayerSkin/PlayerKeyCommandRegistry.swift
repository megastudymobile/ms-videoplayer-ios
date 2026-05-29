//
//  PlayerKeyCommandRegistry.swift
//  SmartPlayer
//
//  Created by 모바일팀_정준영 on 2026/05/19.
//  Copyright © 2026 megastudyedu. All rights reserved.
//

import UIKit

public enum PlayerKeyCommandAction: Equatable {
    case togglePlayPause
    case skipBackward
    case skipForward
    case increaseVolume
    case decreaseVolume
    case toggleDisplayScaling
    case decreasePlaybackRate
    case increasePlaybackRate
    case toggleScreenMode
    case decreaseCaptionFontSize
    case increaseCaptionFontSize
    case openSettings
}

public enum PlayerKeyCommandRegistry {
    public static func commands(action selector: Selector) -> [UIKeyCommand] {
        descriptors.map { descriptor in
            let command = UIKeyCommand(
                title: descriptor.title,
                action: selector,
                input: descriptor.input,
                modifierFlags: descriptor.modifierFlags
            )
            command.discoverabilityTitle = descriptor.title
            command.wantsPriorityOverSystemBehavior = true
            return command
        }
    }

    public static func action(for command: UIKeyCommand) -> PlayerKeyCommandAction? {
        descriptors.first {
            $0.input == command.input && $0.modifierFlags == command.modifierFlags
        }?.action
    }
}

private extension PlayerKeyCommandRegistry {
    struct Descriptor {
        let input: String
        let modifierFlags: UIKeyModifierFlags
        let title: String
        let action: PlayerKeyCommandAction
    }

    static let descriptors: [Descriptor] = [
        Descriptor(input: " ", modifierFlags: [], title: "재생/일시정지", action: .togglePlayPause),
        Descriptor(input: UIKeyCommand.inputLeftArrow, modifierFlags: [], title: "10초 뒤로", action: .skipBackward),
        Descriptor(input: UIKeyCommand.inputRightArrow, modifierFlags: [], title: "10초 앞으로", action: .skipForward),
        Descriptor(input: UIKeyCommand.inputUpArrow, modifierFlags: [], title: "음량 올리기", action: .increaseVolume),
        Descriptor(input: UIKeyCommand.inputDownArrow, modifierFlags: [], title: "음량 내리기", action: .decreaseVolume),
        Descriptor(input: "f", modifierFlags: [], title: "화면 비율 전환", action: .toggleDisplayScaling),
        Descriptor(input: "[", modifierFlags: [], title: "재생 속도 내리기", action: .decreasePlaybackRate),
        Descriptor(input: "]", modifierFlags: [], title: "재생 속도 올리기", action: .increasePlaybackRate),
        Descriptor(input: "s", modifierFlags: [], title: "전체화면 전환", action: .toggleScreenMode),
        Descriptor(input: ",", modifierFlags: [], title: "자막 작게", action: .decreaseCaptionFontSize),
        Descriptor(input: ".", modifierFlags: [], title: "자막 크게", action: .increaseCaptionFontSize),
        Descriptor(input: "/", modifierFlags: [], title: "설정", action: .openSettings)
    ]
}
