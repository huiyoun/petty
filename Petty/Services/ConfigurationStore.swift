import Foundation

enum ConfigurationStore {
    static func load() -> AppConfig {
        if let config = loadUserConfig() {
            return config
        }

        let fallback = AppConfig(agent: AgentCommandConfiguration(command: defaultMockAgentPath()))
        writeDefaultConfigIfNeeded(fallback)
        return fallback
    }

    static func save(_ config: AppConfig) throws {
        let url = configURL
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.write(to: url, options: .atomic)
    }

    static func reloadOrDefault() -> AppConfig {
        loadUserConfig() ?? AppConfig(agent: AgentCommandConfiguration(command: defaultMockAgentPath()))
    }

    static var configURL: URL {
        let supportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return supportDirectory
            .appendingPathComponent("Petty", isDirectory: true)
            .appendingPathComponent("config.json")
    }

    private static func loadUserConfig() -> AppConfig? {
        let url = configURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(AppConfig.self, from: data)
        } catch {
            return nil
        }
    }

    private static func writeDefaultConfigIfNeeded(_ config: AppConfig) {
        let url = configURL
        guard !FileManager.default.fileExists(atPath: url.path) else {
            return
        }

        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(config)
            try data.write(to: url, options: .atomic)
        } catch {
            // Config creation is best-effort; the bundled mock remains the runtime fallback.
        }
    }

    private static func defaultMockAgentPath() -> String {
        if let bundled = Bundle.main.path(forResource: "mock-agent", ofType: "sh") {
            return bundled
        }

        let workingDirectoryPath = FileManager.default.currentDirectoryPath
        let localScript = URL(fileURLWithPath: workingDirectoryPath)
            .appendingPathComponent("scripts/mock-agent.sh")
            .path

        return localScript
    }
}
