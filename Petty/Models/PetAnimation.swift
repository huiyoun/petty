import Foundation

enum PetAnimationState: String, CaseIterable, Codable {
    case idle
    case runningRight = "running-right"
    case runningLeft = "running-left"
    case waving
    case jumping
    case failed
    case waiting
    case running
    case review

    var defaultRow: Int {
        switch self {
        case .idle:
            0
        case .runningRight:
            1
        case .runningLeft:
            2
        case .waving:
            3
        case .jumping:
            4
        case .failed:
            5
        case .waiting:
            6
        case .running:
            7
        case .review:
            8
        }
    }

    var defaultFrameCount: Int {
        switch self {
        case .idle:
            6
        case .runningRight:
            8
        case .runningLeft:
            8
        case .waving:
            4
        case .jumping:
            5
        case .failed:
            8
        case .waiting:
            6
        case .running:
            6
        case .review:
            6
        }
    }
}

struct PetAnimation: Equatable {
    static let defaultFPS: Double = 8

    let state: PetAnimationState
    let row: Int
    let frameCount: Int
    let fps: Double

    static func defaults() -> [PetAnimationState: PetAnimation] {
        Dictionary(uniqueKeysWithValues: PetAnimationState.allCases.map { state in
            (
                state,
                PetAnimation(
                    state: state,
                    row: state.defaultRow,
                    frameCount: state.defaultFrameCount,
                    fps: defaultFPS
                )
            )
        })
    }
}

enum PetPackAtlas {
    static let columns = 8
    static let rows = 9
    static let cellWidth = 192
    static let cellHeight = 208
    static let width = columns * cellWidth
    static let height = rows * cellHeight
}
