import Foundation

public enum PlayerDisplayScaleMode: Int, CaseIterable, Equatable, Sendable {
    case aspectFit
    case aspectFill
    case fill

    public var next: PlayerDisplayScaleMode {
        switch self {
        case .aspectFit:
            return .aspectFill
        case .aspectFill:
            return .fill
        case .fill:
            return .aspectFit
        }
    }

    public var isScaled: Bool {
        self != .aspectFit
    }
}
