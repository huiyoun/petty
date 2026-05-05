import Foundation

final class LocalCommandAgentBridge: AgentBridge {
    private let configuration: AgentCommandConfiguration
    private let fileManager: FileManager

    init(configuration: AgentCommandConfiguration, fileManager: FileManager = .default) {
        self.configuration = configuration
        self.fileManager = fileManager
    }

    func send(_ message: String) async throws -> String {
        let configuration = self.configuration
        let fileManager = self.fileManager

        let response = try await Self.run(
            command: configuration.command,
            arguments: configuration.arguments + [message],
            fileManager: fileManager
        )

        if response.ok {
            return response.message ?? ""
        }

        throw AgentBridgeError.agentFailed(response.error ?? "Agent returned an error.")
    }

    static func run(
        command: String,
        arguments: [String],
        fileManager: FileManager = .default
    ) async throws -> AgentCommandResponse {
        return try await Task.detached(priority: .userInitiated) {
            guard let executablePath = Self.resolveExecutablePath(command, fileManager: fileManager) else {
                throw AgentBridgeError.commandNotFound(command)
            }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = arguments

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            do {
                try process.run()
            } catch {
                throw AgentBridgeError.launchFailed(error.localizedDescription)
            }

            process.waitUntilExit()

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

            guard process.terminationStatus == 0 else {
                let stderr = String(data: errorData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                throw AgentBridgeError.agentFailed(stderr?.isEmpty == false ? stderr! : "Agent exited with status \(process.terminationStatus).")
            }

            guard
                let response = try? JSONDecoder().decode(AgentCommandResponse.self, from: outputData)
            else {
                throw AgentBridgeError.invalidResponse(Self.outputPreview(stdout: outputData, stderr: errorData))
            }

            return response
        }.value
    }

    private static func outputPreview(stdout: Data, stderr: Data) -> String {
        let stdoutText = String(data: stdout, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let stderrText = String(data: stderr, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let label = stdoutText.isEmpty ? "stderr" : "stdout"
        let rawPreview = stdoutText.isEmpty ? stderrText : stdoutText
        guard !rawPreview.isEmpty else {
            return "stdout was empty."
        }

        let limit = 240
        let truncated = rawPreview.count > limit
            ? "\(rawPreview.prefix(limit))..."
            : rawPreview

        return "\(label): \(truncated)"
    }

    static func resolveExecutablePath(_ command: String, fileManager: FileManager = .default) -> String? {
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCommand.isEmpty else { return nil }

        if trimmedCommand.contains("/") {
            return fileManager.isExecutableFile(atPath: trimmedCommand) ? trimmedCommand : nil
        }

        let pathValue = ProcessInfo.processInfo.environment["PATH"] ?? ""
        let fallbackPaths = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin"
        ]
        let searchPaths = (pathValue.split(separator: ":").map(String.init) + fallbackPaths)

        for directory in searchPaths {
            let candidate = URL(fileURLWithPath: directory).appendingPathComponent(trimmedCommand).path
            if fileManager.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }

        return nil
    }
}
