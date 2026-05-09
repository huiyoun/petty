import Foundation

enum ChatHistoryStore {
    private static let maxMessages = 300
    private static let ephemeralSystemMessages = Set([
        "Petty is ready.",
        "Settings updated."
    ])

    static func load() -> [ChatMessage] {
        let url = historyURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([ChatMessage].self, from: data)
                .filter { message in
                    !(message.role == .system && ephemeralSystemMessages.contains(message.text))
                }
        } catch {
            return []
        }
    }

    static func save(_ messages: [ChatMessage]) {
        let persistentMessages = messages
            .filter { message in
                !(message.role == .system && ephemeralSystemMessages.contains(message.text))
            }
            .suffix(maxMessages)

        guard !persistentMessages.isEmpty else {
            try? FileManager.default.removeItem(at: historyURL)
            return
        }

        do {
            try FileManager.default.createDirectory(
                at: historyURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(Array(persistentMessages))
            try data.write(to: historyURL, options: .atomic)
        } catch {
            // History persistence is best-effort; chat should keep working in memory.
        }
    }

    static func clear() {
        try? FileManager.default.removeItem(at: historyURL)
    }

    static var historyURL: URL {
        let supportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return supportDirectory
            .appendingPathComponent("Petty", isDirectory: true)
            .appendingPathComponent("history.json")
    }
}
