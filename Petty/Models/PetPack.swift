import Foundation

struct PetPack: Identifiable, Equatable {
    let id: String
    let displayName: String
    let description: String
    let creator: String?
    let directoryURL: URL
    let spritesheetURL: URL
    let animations: [PetAnimationState: PetAnimation]

    func animation(for petState: PetState) -> PetAnimation {
        let animationState = petState.animationState
        return animations[animationState] ?? PetAnimation(
            state: animationState,
            row: animationState.defaultRow,
            frameCount: animationState.defaultFrameCount,
            fps: PetAnimation.defaultFPS
        )
    }
}

struct PetPackManifest: Decodable {
    let id: String
    let displayName: String?
    let name: String?
    let description: String?
    let creator: String?
    let author: String?
    let spritesheetPath: String?
    let animations: [String: PetAnimationManifest]?
    let states: [String: PetAnimationManifest]?
}

struct PetAnimationManifest: Decodable {
    let row: Int?
    let frames: Int?
    let frameCount: Int?
    let fps: Double?
}
