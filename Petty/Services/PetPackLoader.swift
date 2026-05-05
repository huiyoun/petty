import AppKit
import Foundation

enum PetPackLoaderError: LocalizedError {
    case manifestMissing(URL)
    case invalidManifest(URL)
    case spritesheetMissing(URL)
    case invalidSpritesheetSize(URL, Int, Int)

    var errorDescription: String? {
        switch self {
        case .manifestMissing(let url):
            "Missing pet.json at \(url.path)"
        case .invalidManifest(let url):
            "Invalid pet.json at \(url.path)"
        case .spritesheetMissing(let url):
            "Missing spritesheet at \(url.path)"
        case .invalidSpritesheetSize(let url, let width, let height):
            "Invalid spritesheet size at \(url.path): \(width)x\(height)"
        }
    }
}

enum PetPackLoader {
    static func load(from directoryURL: URL) throws -> PetPack {
        let manifestURL = directoryURL.appendingPathComponent("pet.json")
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            throw PetPackLoaderError.manifestMissing(manifestURL)
        }

        let manifest: PetPackManifest
        do {
            let data = try Data(contentsOf: manifestURL)
            manifest = try JSONDecoder().decode(PetPackManifest.self, from: data)
        } catch {
            throw PetPackLoaderError.invalidManifest(manifestURL)
        }

        let spritesheetPath = manifest.spritesheetPath ?? "spritesheet.webp"
        let spritesheetURL = directoryURL.appendingPathComponent(spritesheetPath)
        guard FileManager.default.fileExists(atPath: spritesheetURL.path) else {
            throw PetPackLoaderError.spritesheetMissing(spritesheetURL)
        }

        try validateSpritesheet(at: spritesheetURL)

        return PetPack(
            id: manifest.id,
            displayName: manifest.displayName ?? manifest.name ?? manifest.id,
            description: manifest.description ?? "",
            creator: manifest.creator ?? manifest.author,
            directoryURL: directoryURL,
            spritesheetURL: spritesheetURL,
            animations: animations(from: manifest)
        )
    }

    private static func validateSpritesheet(at url: URL) throws {
        guard let image = NSImage(contentsOf: url) else {
            throw PetPackLoaderError.spritesheetMissing(url)
        }

        guard
            let representation = image.representations.first,
            representation.pixelsWide == PetPackAtlas.width,
            representation.pixelsHigh == PetPackAtlas.height
        else {
            let representation = image.representations.first
            throw PetPackLoaderError.invalidSpritesheetSize(
                url,
                representation?.pixelsWide ?? Int(image.size.width),
                representation?.pixelsHigh ?? Int(image.size.height)
            )
        }
    }

    private static func animations(from manifest: PetPackManifest) -> [PetAnimationState: PetAnimation] {
        var animations = PetAnimation.defaults()
        let manifestAnimations = manifest.animations ?? manifest.states ?? [:]

        for (key, value) in manifestAnimations {
            guard let state = PetAnimationState(rawValue: key) else {
                continue
            }

            animations[state] = PetAnimation(
                state: state,
                row: value.row ?? state.defaultRow,
                frameCount: min(max(value.frames ?? value.frameCount ?? state.defaultFrameCount, 1), PetPackAtlas.columns),
                fps: min(max(value.fps ?? PetAnimation.defaultFPS, 1), 24)
            )
        }

        return animations
    }
}
