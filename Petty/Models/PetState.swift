import SwiftUI

enum PetState: String {
    case idle
    case thinking
    case success
    case error
    case runningRight = "running-right"
    case runningLeft = "running-left"

    var bodyColor: Color {
        switch self {
        case .idle:
            Color(red: 0.38, green: 0.82, blue: 0.68)
        case .thinking:
            Color(red: 0.36, green: 0.58, blue: 0.94)
        case .success:
            Color(red: 0.94, green: 0.74, blue: 0.28)
        case .error:
            Color(red: 0.92, green: 0.34, blue: 0.36)
        case .runningRight, .runningLeft:
            Color(red: 0.48, green: 0.88, blue: 0.72)
        }
    }

    var face: String {
        switch self {
        case .idle:
            ":)"
        case .thinking:
            "..."
        case .success:
            "^_^"
        case .error:
            "x_x"
        case .runningRight:
            ">"
        case .runningLeft:
            "<"
        }
    }

    var animationState: PetAnimationState {
        switch self {
        case .idle:
            .idle
        case .thinking:
            .review
        case .success:
            .waving
        case .error:
            .failed
        case .runningRight:
            .runningRight
        case .runningLeft:
            .runningLeft
        }
    }
}
