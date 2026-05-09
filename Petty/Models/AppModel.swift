import Foundation
import CoreGraphics

@MainActor
final class AppModel: ObservableObject {
    @Published var petState: PetState = .idle
    @Published var messages: [ChatMessage] = [] {
        didSet {
            ChatHistoryStore.save(messages)
        }
    }
    @Published var errorText: String?
    @Published var petSpeech: String?
    @Published var isSending = false
    @Published private(set) var chatTitle = "Petty"
    @Published private(set) var appConfig: AppConfig
    @Published private(set) var petPack: PetPack?
    @Published private(set) var petRenderToken = UUID()
    @Published private(set) var isChatPanelVisible = false

    private var bridge: AgentBridge
    private var telegramBridge: TelegramUserAgentBridge?
    private var automaticChatTitle = "Petty"
    private var speechToken: UUID?
    private var stateBeforeDrag: PetState?

    init(configuration: AppConfig) {
        appConfig = configuration
        let history = ChatHistoryStore.load()
        messages = history.isEmpty ? [Self.readyMessage()] : history
        bridge = LocalCommandAgentBridge(configuration: configuration.agent)
        petPack = LocalPetPackStore.loadSelectedPetPack(preferredID: configuration.petId)
        configureAgentBridge(configuration.agent)
    }

    deinit {
        telegramBridge?.stop()
    }

    func applyConfiguration(_ configuration: AppConfig) {
        appConfig = configuration
        petPack = LocalPetPackStore.loadSelectedPetPack(preferredID: configuration.petId)
        petRenderToken = UUID()
        errorText = nil
        dismissPetSpeech()
        configureAgentBridge(configuration.agent)
        messages.append(ChatMessage(role: .system, text: "Settings updated."))
    }

    func setChatDisplayName(_ rawName: String) {
        let trimmedName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        var updatedConfig = appConfig
        updatedConfig.chatDisplayName = trimmedName.isEmpty ? nil : trimmedName

        do {
            try ConfigurationStore.save(updatedConfig)
            appConfig = updatedConfig
            updateChatTitle()
            errorText = nil
            messages.append(ChatMessage(role: .system, text: "Chat name updated."))
        } catch {
            errorText = "Failed to save chat name: \(error.localizedDescription)"
        }
    }

    func chatPanelDidOpen() {
        isChatPanelVisible = true
    }

    func chatPanelDidClose() {
        isChatPanelVisible = false
        dismissPetSpeech()
    }

    func petDragDidMove(deltaX: CGFloat) {
        if stateBeforeDrag == nil {
            stateBeforeDrag = petState
        }

        if deltaX > 0 {
            petState = .runningRight
        } else if deltaX < 0 {
            petState = .runningLeft
        }
    }

    func petDragDidEnd() {
        petState = stateBeforeDrag ?? .idle
        stateBeforeDrag = nil
    }

    func send(_ rawText: String) {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        messages.append(ChatMessage(role: .user, text: text))
        errorText = nil
        petSpeech = nil
        petState = .thinking
        stateBeforeDrag = nil
        isSending = true

        Task {
            defer {
                isSending = false
            }

            do {
                let reply = try await bridge.send(text)
                receiveAgentMessage(reply, externalID: nil, updateExisting: false)
            } catch {
                let description = error.localizedDescription
                receiveAgentError(description)
            }
        }
    }

    func clearHistory() {
        ChatHistoryStore.clear()
        messages = [Self.readyMessage()]
        errorText = nil
        dismissPetSpeech()
    }

    private func configureAgentBridge(_ configuration: AgentCommandConfiguration) {
        telegramBridge?.stop()
        telegramBridge = nil

        guard let telegramConfiguration = TelegramUserAgentConfiguration.parse(configuration) else {
            automaticChatTitle = "Petty"
            updateChatTitle()
            bridge = LocalCommandAgentBridge(configuration: configuration)
            return
        }

        automaticChatTitle = telegramConfiguration.displayName
        updateChatTitle()

        do {
            let bridge = try TelegramUserAgentBridge(
                configuration: telegramConfiguration,
                onIncoming: { [weak self] event in
                    Task { @MainActor in
                        self?.receiveAgentMessage(
                            event.text,
                            externalID: event.externalID,
                            updateExisting: event.isUpdate
                        )
                    }
                },
                onError: { [weak self] description in
                    Task { @MainActor in
                        self?.receiveAgentError(description)
                    }
                }
            )
            telegramBridge = bridge
            self.bridge = bridge
        } catch {
            bridge = LocalCommandAgentBridge(configuration: configuration)
            receiveAgentError(error.localizedDescription)
        }
    }

    private func updateChatTitle() {
        let customTitle = appConfig.chatDisplayName?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let customTitle, !customTitle.isEmpty {
            chatTitle = customTitle
        } else {
            chatTitle = automaticChatTitle
        }
    }

    private func receiveAgentMessage(_ rawText: String, externalID: String?, updateExisting: Bool) {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        errorText = nil
        isSending = false
        stateBeforeDrag = nil

        if updateExisting,
           let externalID,
           let index = messages.firstIndex(where: { $0.role == .assistant && $0.externalID == externalID }) {
            let existing = messages[index]
            messages[index] = ChatMessage(
                id: existing.id,
                role: .assistant,
                text: text,
                createdAt: existing.createdAt,
                externalID: externalID
            )
        } else {
            messages.append(ChatMessage(role: .assistant, text: text, externalID: externalID))
        }

        showPetSpeech(text)
        petState = .success
        returnToIdleSoon()
    }

    private func receiveAgentError(_ description: String) {
        errorText = description
        isSending = false
        stateBeforeDrag = nil
        messages.append(ChatMessage(role: .system, text: description))
        showPetSpeech(description)
        petState = .error
    }

    private func returnToIdleSoon() {
        Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard petState == .success else { return }
            petState = .idle
        }
    }

    private func showPetSpeech(_ text: String) {
        let token = UUID()
        speechToken = token
        petSpeech = text

        Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard speechToken == token else { return }
            petSpeech = nil
            speechToken = nil
        }
    }

    private func dismissPetSpeech() {
        speechToken = nil
        petSpeech = nil
    }

    private static func readyMessage() -> ChatMessage {
        ChatMessage(role: .system, text: "Petty is ready.")
    }
}
