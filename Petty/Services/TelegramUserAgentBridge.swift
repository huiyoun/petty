import Foundation

struct TelegramUserAgentConfiguration {
    let command: String
    let scriptPath: String?
    let apiID: String
    let apiHash: String
    let sessionPath: String
    let chat: String
    let replyFrom: String
    let prefix: String

    var bridgeArguments: [String] {
        var arguments: [String] = []
        if let scriptPath {
            arguments.append(scriptPath)
        }

        arguments.append(contentsOf: [
            "bridge",
            apiID,
            apiHash,
            sessionPath,
            chat
        ])

        if !prefix.isEmpty {
            arguments.append(contentsOf: ["--prefix", prefix])
        }

        if !replyFrom.isEmpty {
            arguments.append(contentsOf: ["--reply-from", replyFrom])
        }

        return arguments
    }

    var displayName: String {
        let preferred = replyFrom.isEmpty ? chat : replyFrom
        return Self.cleanDisplayName(preferred)
    }

    static func parse(_ config: AgentCommandConfiguration) -> TelegramUserAgentConfiguration? {
        let commandName = URL(fileURLWithPath: config.command).lastPathComponent
        let arguments = config.arguments

        let scriptPath: String?
        let modeIndex: Int

        if commandName.contains("python"),
           arguments.first?.hasSuffix("telegram-user-agent.py") == true {
            scriptPath = arguments[0]
            modeIndex = 1
        } else if commandName == "telegram-user-agent.py" {
            scriptPath = nil
            modeIndex = 0
        } else {
            return nil
        }

        guard arguments.indices.contains(modeIndex), arguments[modeIndex] == "send" else {
            return nil
        }

        let baseIndex = modeIndex + 1
        guard arguments.count >= baseIndex + 4 else {
            return nil
        }

        var replyFrom = ""
        var prefix = ""
        var index = baseIndex + 4
        while index < arguments.count {
            let option = arguments[index]
            if option == "--reply-from", arguments.indices.contains(index + 1) {
                replyFrom = arguments[index + 1]
                index += 2
            } else if option == "--prefix", arguments.indices.contains(index + 1) {
                prefix = arguments[index + 1]
                index += 2
            } else if option == "--timeout" || option == "--settle" {
                index += arguments.indices.contains(index + 1) ? 2 : 1
            } else {
                index += 1
            }
        }

        return TelegramUserAgentConfiguration(
            command: config.command,
            scriptPath: scriptPath,
            apiID: arguments[baseIndex],
            apiHash: arguments[baseIndex + 1],
            sessionPath: arguments[baseIndex + 2],
            chat: arguments[baseIndex + 3],
            replyFrom: replyFrom,
            prefix: prefix
        )
    }

    private static func cleanDisplayName(_ value: String) -> String {
        var cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in ["telegram:", "tg:", "chat:"] {
            if cleaned.lowercased().hasPrefix(prefix) {
                cleaned = String(cleaned.dropFirst(prefix.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        if cleaned.hasPrefix("@") {
            cleaned.removeFirst()
        }

        return cleaned.isEmpty ? "Telegram Agent" : cleaned
    }
}

final class TelegramUserAgentBridge: AgentBridge {
    struct IncomingEvent {
        let text: String
        let externalID: String?
        let isUpdate: Bool
    }

    private struct BridgeLine: Decodable {
        let ok: Bool
        let type: String?
        let message: String?
        let error: String?
        let messageID: Int?
        let edited: Bool?

        enum CodingKeys: String, CodingKey {
            case ok
            case type
            case message
            case error
            case messageID = "message_id"
            case edited
        }
    }

    private let configuration: TelegramUserAgentConfiguration
    private let onIncoming: (IncomingEvent) -> Void
    private let onError: (String) -> Void
    private let outputQueue = DispatchQueue(label: "dev.petty.telegram-user-agent.output")

    private var process: Process?
    private var inputPipe: Pipe?
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?
    private var outputBuffer = ""
    private var isStopping = false

    init(
        configuration: TelegramUserAgentConfiguration,
        onIncoming: @escaping (IncomingEvent) -> Void,
        onError: @escaping (String) -> Void
    ) throws {
        self.configuration = configuration
        self.onIncoming = onIncoming
        self.onError = onError
        try start()
    }

    deinit {
        stop()
    }

    func send(_ message: String) async throws -> String {
        guard let process, process.isRunning, let inputPipe else {
            throw AgentBridgeError.agentFailed("Telegram bridge is not running. Save settings again or restart Petty.")
        }

        let payload: Data
        do {
            payload = try JSONSerialization.data(withJSONObject: ["message": message], options: [])
        } catch {
            throw AgentBridgeError.agentFailed("Failed to encode Telegram message: \(error.localizedDescription)")
        }

        var line = payload
        line.append(0x0A)

        do {
            try inputPipe.fileHandleForWriting.write(contentsOf: line)
        } catch {
            throw AgentBridgeError.agentFailed("Failed to write to Telegram bridge: \(error.localizedDescription)")
        }

        return ""
    }

    func stop() {
        isStopping = true
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        errorPipe?.fileHandleForReading.readabilityHandler = nil

        try? inputPipe?.fileHandleForWriting.close()

        if process?.isRunning == true {
            process?.terminate()
        }

        process = nil
        inputPipe = nil
        outputPipe = nil
        errorPipe = nil
    }

    private func start() throws {
        guard let executablePath = LocalCommandAgentBridge.resolveExecutablePath(configuration.command) else {
            throw AgentBridgeError.commandNotFound(configuration.command)
        }

        let process = Process()
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = configuration.bridgeArguments
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            self?.outputQueue.async {
                self?.consumeOutput(data)
            }
        }

        errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard
                !data.isEmpty,
                let text = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                !text.isEmpty
            else {
                return
            }

            self?.onError(text)
        }

        process.terminationHandler = { [weak self] process in
            guard let self, !self.isStopping else { return }
            self.onError("Telegram bridge stopped with status \(process.terminationStatus).")
        }

        do {
            try process.run()
        } catch {
            throw AgentBridgeError.launchFailed(error.localizedDescription)
        }

        self.process = process
        self.inputPipe = inputPipe
        self.outputPipe = outputPipe
        self.errorPipe = errorPipe
    }

    private func consumeOutput(_ data: Data) {
        guard let text = String(data: data, encoding: .utf8) else {
            return
        }

        outputBuffer.append(text)

        while let newline = outputBuffer.firstIndex(of: "\n") {
            let line = String(outputBuffer[..<newline])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            outputBuffer.removeSubrange(...newline)

            guard !line.isEmpty else {
                continue
            }

            handleLine(line)
        }
    }

    private func handleLine(_ line: String) {
        guard
            let data = line.data(using: .utf8),
            let event = try? JSONDecoder().decode(BridgeLine.self, from: data)
        else {
            onError("Telegram bridge returned invalid event: \(line)")
            return
        }

        if !event.ok {
            onError(event.error ?? "Telegram bridge failed.")
            return
        }

        guard event.type == "message", let message = event.message, !message.isEmpty else {
            return
        }

        let externalID = event.messageID.map { "telegram:\($0)" }
        onIncoming(
            IncomingEvent(
                text: message,
                externalID: externalID,
                isUpdate: event.edited ?? false
            )
        )
    }
}
