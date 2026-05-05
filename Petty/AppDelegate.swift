import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var appModel: AppModel?
    private var petWindowController: PetWindowController?
    private var chatPanelController: ChatPanelController?
    private var settingsWindowController: SettingsWindowController?
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let configuration = ConfigurationStore.load()
        let model = AppModel(configuration: configuration)
        let chatController = ChatPanelController(model: model)
        let petController = PetWindowController(model: model) { [weak chatController] petFrame in
            chatController?.toggle(relativeTo: petFrame)
        }
        let settingsController = SettingsWindowController(model: model)
        let statusController = StatusBarController(
            onOpenChat: { [weak petController, weak chatController] in
                guard let petFrame = petController?.currentPetFrame else { return }
                chatController?.show(relativeTo: petFrame)
            },
            onOpenSettings: { [weak settingsController] in
                settingsController?.show()
            },
            onReloadConfig: { [weak model] in
                model?.applyConfiguration(ConfigurationStore.reloadOrDefault())
            },
            onClearHistory: { [weak model] in
                model?.clearHistory()
            },
            onQuit: {
                NSApp.terminate(nil)
            }
        )

        appModel = model
        chatPanelController = chatController
        petWindowController = petController
        settingsWindowController = settingsController
        statusBarController = statusController
        petController.showWindow(nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationDidResignActive(_ notification: Notification) {
        chatPanelController?.hide()
    }
}
