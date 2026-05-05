import Foundation

enum LocalPetPackStore {
    static var petsDirectoryURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex", isDirectory: true)
            .appendingPathComponent("pets", isDirectory: true)
    }

    static func loadPetPacks() -> [PetPack] {
        guard
            let directories = try? FileManager.default.contentsOfDirectory(
                at: petsDirectoryURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
        else {
            return []
        }

        return directories
            .filter { url in
                (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            }
            .compactMap { try? PetPackLoader.load(from: $0) }
            .sorted { lhs, rhs in
                lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
    }

    static func loadSelectedPetPack(preferredID: String?) -> PetPack? {
        let packs = loadPetPacks()

        if let preferredID, let selected = packs.first(where: { $0.id == preferredID }) {
            return selected
        }

        return packs.first
    }
}
