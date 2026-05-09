import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel

    @State private var mode: AgentSettingsMode
    @State private var command: String
    @State private var argumentsText: String
    @State private var telegramPythonPath: String
    @State private var telegramScriptPath: String
    @State private var telegramAPIID: String
    @State private var telegramAPIHash: String
    @State private var telegramSessionPath: String
    @State private var telegramChat: String
    @State private var telegramReplyFrom: String
    @State private var telegramPrefix: String
    @State private var telegramTimeout: String
    @State private var selectedPetID: String
    @State private var petPacks: [PetPack]
    @State private var statusText = ""

    init(model: AppModel) {
        self.model = model

        let config = model.appConfig
        let formState = SettingsFormState(config: config)
        _mode = State(initialValue: formState.mode)
        _command = State(initialValue: formState.command)
        _argumentsText = State(initialValue: formState.argumentsText)
        _telegramPythonPath = State(initialValue: formState.telegramPythonPath)
        _telegramScriptPath = State(initialValue: formState.telegramScriptPath)
        _telegramAPIID = State(initialValue: formState.telegramAPIID)
        _telegramAPIHash = State(initialValue: formState.telegramAPIHash)
        _telegramSessionPath = State(initialValue: formState.telegramSessionPath)
        _telegramChat = State(initialValue: formState.telegramChat)
        _telegramReplyFrom = State(initialValue: formState.telegramReplyFrom)
        _telegramPrefix = State(initialValue: formState.telegramPrefix)
        _telegramTimeout = State(initialValue: formState.telegramTimeout)
        _selectedPetID = State(initialValue: config.petId ?? "")
        _petPacks = State(initialValue: LocalPetPackStore.loadPetPacks())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()

            Form {
                Section {
                    Picker("Connection", selection: $mode) {
                        ForEach(AgentSettingsMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Agent")
                }

                if mode == .telegramUser {
                    telegramUserSection
                } else {
                    customCommandSection
                }

                Section {
                    Picker("Pet Pack", selection: $selectedPetID) {
                        Text("First available").tag("")
                        Text(LocalPetPackStore.builtInPetDisplayName).tag(LocalPetPackStore.builtInPetID)
                        ForEach(selectablePetPacks) { pack in
                            Text(pack.displayName).tag(pack.id)
                        }
                    }

                    Button("Rescan Pet Packs") {
                        petPacks = LocalPetPackStore.loadPetPacks()
                        statusText = "Pet packs rescanned."
                    }
                } header: {
                    Text("Pet")
                }

                Section {
                    Text(ConfigurationStore.configURL.path)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Config File")
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(statusText.hasPrefix("Failed") ? .red : .secondary)
                    .lineLimit(1)

                Spacer()

                Button("Reload") {
                    reloadFromDisk()
                }

                Button("Save") {
                    save()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
            .padding(16)
        }
        .frame(width: 600, height: 620)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Petty Settings")
                .font(.title2.weight(.semibold))

            Text("Connect Petty to Telegram or a custom local command.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(16)
    }

    private var telegramUserSection: some View {
        Group {
            Section {
                HStack {
                    TextField("API ID", text: $telegramAPIID)
                    SecureField("API Hash", text: $telegramAPIHash)
                }

                HStack {
                    TextField("OpenClaw bot @username or list-chats bot/group ID", text: $telegramChat)
                    TextField("Reply From username or id", text: $telegramReplyFrom)
                }

                TextField("Prefix", text: $telegramPrefix)

                HStack {
                    TextField("Timeout", text: $telegramTimeout)
                        .frame(maxWidth: 96)

                    Text(sessionStatusText)
                        .font(.caption)
                        .foregroundStyle(sessionExists ? .green : .orange)

                    Spacer()
                }

                HStack {
                    Button("Telegram API") {
                        NSWorkspace.shared.open(URL(string: "https://my.telegram.org/apps")!)
                    }

                    Button("Copy Setup Command") {
                        copySetupCommand()
                    }
                    .disabled(telegramAPIID.isEmpty || telegramAPIHash.isEmpty)

                    Button("Copy Chat List Command") {
                        copyChatListCommand()
                    }
                    .disabled(telegramAPIID.isEmpty || telegramAPIHash.isEmpty)
                }
            } header: {
                Text("Telegram User Relay")
            }

            Section {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("One-time login")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(setupCommand)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Find chat ID")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(chatListCommand)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                }
            } header: {
                Text("Terminal Commands")
            }
        }
    }

    private var customCommandSection: some View {
        Section {
            TextField("Command", text: $command)

            Button("Choose Command...") {
                chooseCommand()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Arguments")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextEditor(text: $argumentsText)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 104)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(.secondary.opacity(0.25), lineWidth: 1)
                    )

                Text("One argument per line. The user message is appended as the final argument.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Custom Command")
        }
    }

    private var canSave: Bool {
        switch mode {
        case .telegramUser:
            return !telegramPythonPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !telegramScriptPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !telegramAPIID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !telegramAPIHash.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !telegramSessionPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !telegramChat.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && Int(telegramTimeout.trimmingCharacters(in: .whitespacesAndNewlines)) != nil
        case .custom:
            return !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private var selectablePetPacks: [PetPack] {
        petPacks.filter { !LocalPetPackStore.isBuiltInPetID($0.id) }
    }

    private var sessionExists: Bool {
        let path = NSString(string: telegramSessionPath).expandingTildeInPath
        return FileManager.default.fileExists(atPath: path)
            || FileManager.default.fileExists(atPath: "\(path).session")
    }

    private var sessionStatusText: String {
        sessionExists ? "Session ready" : "Session missing"
    }

    private var setupCommand: String {
        [
            telegramPythonPath,
            telegramScriptPath,
            "setup",
            telegramAPIID.isEmpty ? "<api-id>" : telegramAPIID,
            telegramAPIHash.isEmpty ? "<api-hash>" : telegramAPIHash,
            telegramSessionPath
        ]
            .map(Self.shellQuoted)
            .joined(separator: " ")
    }

    private var chatListCommand: String {
        [
            telegramPythonPath,
            telegramScriptPath,
            "list-chats",
            telegramAPIID.isEmpty ? "<api-id>" : telegramAPIID,
            telegramAPIHash.isEmpty ? "<api-hash>" : telegramAPIHash,
            telegramSessionPath,
            "--limit",
            "40"
        ]
            .map(Self.shellQuoted)
            .joined(separator: " ")
    }

    private func chooseCommand() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.title = "Choose Agent Command"

        if panel.runModal() == .OK, let url = panel.url {
            command = url.path
        }
    }

    private func copySetupCommand() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(setupCommand, forType: .string)
        statusText = "Setup command copied."
    }

    private func copyChatListCommand() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(chatListCommand, forType: .string)
        statusText = "Chat list command copied."
    }

    private func save() {
        let config = AppConfig(
            agent: agentConfiguration(),
            petId: selectedPetID.isEmpty ? nil : selectedPetID
        )

        do {
            try ConfigurationStore.save(config)
            model.applyConfiguration(config)
            statusText = "Saved."
        } catch {
            statusText = "Failed to save: \(error.localizedDescription)"
        }
    }

    private func reloadFromDisk() {
        let config = ConfigurationStore.reloadOrDefault()
        apply(SettingsFormState(config: config))
        selectedPetID = config.petId ?? ""
        petPacks = LocalPetPackStore.loadPetPacks()
        model.applyConfiguration(config)
        statusText = "Reloaded."
    }

    private func apply(_ formState: SettingsFormState) {
        mode = formState.mode
        command = formState.command
        argumentsText = formState.argumentsText
        telegramPythonPath = formState.telegramPythonPath
        telegramScriptPath = formState.telegramScriptPath
        telegramAPIID = formState.telegramAPIID
        telegramAPIHash = formState.telegramAPIHash
        telegramSessionPath = formState.telegramSessionPath
        telegramChat = formState.telegramChat
        telegramReplyFrom = formState.telegramReplyFrom
        telegramPrefix = formState.telegramPrefix
        telegramTimeout = formState.telegramTimeout
    }

    private func agentConfiguration() -> AgentCommandConfiguration {
        switch mode {
        case .telegramUser:
            return AgentCommandConfiguration(
                command: telegramPythonPath.trimmingCharacters(in: .whitespacesAndNewlines),
                arguments: telegramArguments
            )
        case .custom:
            return AgentCommandConfiguration(
                command: command.trimmingCharacters(in: .whitespacesAndNewlines),
                arguments: parsedArguments
            )
        }
    }

    private var telegramArguments: [String] {
        var arguments = [
            telegramScriptPath.trimmingCharacters(in: .whitespacesAndNewlines),
            "send",
            telegramAPIID.trimmingCharacters(in: .whitespacesAndNewlines),
            telegramAPIHash.trimmingCharacters(in: .whitespacesAndNewlines),
            telegramSessionPath.trimmingCharacters(in: .whitespacesAndNewlines),
            telegramChat.trimmingCharacters(in: .whitespacesAndNewlines),
            "--timeout",
            telegramTimeout.trimmingCharacters(in: .whitespacesAndNewlines),
            "--settle",
            "3.0"
        ]

        let replyFrom = telegramReplyFrom.trimmingCharacters(in: .whitespacesAndNewlines)
        if !replyFrom.isEmpty {
            arguments.append(contentsOf: ["--reply-from", replyFrom])
        }

        if !telegramPrefix.isEmpty {
            arguments.append(contentsOf: ["--prefix", telegramPrefix])
        }

        return arguments
    }

    private var parsedArguments: [String] {
        argumentsText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}

private enum AgentSettingsMode: String, CaseIterable, Identifiable {
    case telegramUser
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .telegramUser:
            "Telegram"
        case .custom:
            "Custom"
        }
    }
}

private struct SettingsFormState {
    var mode: AgentSettingsMode
    var command: String
    var argumentsText: String
    var telegramPythonPath: String
    var telegramScriptPath: String
    var telegramAPIID: String
    var telegramAPIHash: String
    var telegramSessionPath: String
    var telegramChat: String
    var telegramReplyFrom: String
    var telegramPrefix: String
    var telegramTimeout: String

    init(config: AppConfig) {
        command = config.agent.command
        argumentsText = config.agent.arguments.joined(separator: "\n")

        let parsedTelegram = Self.parseTelegramUserConfig(config.agent)
        mode = parsedTelegram == nil ? .custom : .telegramUser
        telegramPythonPath = parsedTelegram?.pythonPath ?? Self.defaultPythonPath()
        telegramScriptPath = parsedTelegram?.scriptPath ?? Self.defaultTelegramScriptPath()
        telegramAPIID = parsedTelegram?.apiID ?? ""
        telegramAPIHash = parsedTelegram?.apiHash ?? ""
        telegramSessionPath = parsedTelegram?.sessionPath ?? Self.defaultTelegramSessionPath()
        telegramChat = parsedTelegram?.chat ?? ""
        telegramReplyFrom = parsedTelegram?.replyFrom ?? ""
        telegramPrefix = parsedTelegram?.prefix ?? ""
        telegramTimeout = parsedTelegram?.timeout ?? "90"
    }

    private static func parseTelegramUserConfig(_ config: AgentCommandConfiguration) -> TelegramUserFields? {
        let commandURL = URL(fileURLWithPath: config.command)
        let commandName = commandURL.lastPathComponent
        let arguments = config.arguments

        let scriptPath: String
        let pythonPath: String
        let sendIndex: Int

        if commandName.contains("python"), arguments.first?.hasSuffix("telegram-user-agent.py") == true {
            scriptPath = arguments[0]
            pythonPath = config.command
            sendIndex = 1
        } else if commandName == "telegram-user-agent.py" {
            scriptPath = config.command
            pythonPath = defaultPythonPath()
            sendIndex = 0
        } else {
            return nil
        }

        guard arguments.indices.contains(sendIndex), arguments[sendIndex] == "send" else {
            return nil
        }

        let baseIndex = sendIndex + 1
        guard arguments.count >= baseIndex + 4 else {
            return nil
        }

        var timeout = "90"
        var replyFrom = ""
        var prefix = ""
        var index = baseIndex + 4
        while index < arguments.count {
            let option = arguments[index]
            if option == "--timeout", arguments.indices.contains(index + 1) {
                timeout = arguments[index + 1]
                index += 2
            } else if option == "--reply-from", arguments.indices.contains(index + 1) {
                replyFrom = arguments[index + 1]
                index += 2
            } else if option == "--prefix", arguments.indices.contains(index + 1) {
                prefix = arguments[index + 1]
                index += 2
            } else {
                index += 1
            }
        }

        return TelegramUserFields(
            pythonPath: pythonPath,
            scriptPath: scriptPath,
            apiID: arguments[baseIndex],
            apiHash: arguments[baseIndex + 1],
            sessionPath: arguments[baseIndex + 2],
            chat: arguments[baseIndex + 3],
            timeout: timeout,
            replyFrom: replyFrom,
            prefix: prefix
        )
    }

    private static func defaultPythonPath() -> String {
        let venvPython = projectRoot()
            .appendingPathComponent(".venv/bin/python")
            .path

        if FileManager.default.isExecutableFile(atPath: venvPython) {
            return venvPython
        }

        return "/usr/bin/python3"
    }

    private static func defaultTelegramScriptPath() -> String {
        if let bundled = Bundle.main.path(forResource: "telegram-user-agent", ofType: "py") {
            return bundled
        }

        return projectRoot()
            .appendingPathComponent("scripts/telegram-user-agent.py")
            .path
    }

    private static func defaultTelegramSessionPath() -> String {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".petty/telegram-user")
            .path
    }

    private static func projectRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}

private struct TelegramUserFields {
    var pythonPath: String
    var scriptPath: String
    var apiID: String
    var apiHash: String
    var sessionPath: String
    var chat: String
    var timeout: String
    var replyFrom: String
    var prefix: String
}
