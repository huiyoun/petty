import AppKit

final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let onOpenChat: () -> Void
    private let onOpenSettings: () -> Void
    private let onReloadConfig: () -> Void
    private let onClearHistory: () -> Void
    private let onQuit: () -> Void

    init(
        onOpenChat: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void,
        onReloadConfig: @escaping () -> Void,
        onClearHistory: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.onOpenChat = onOpenChat
        self.onOpenSettings = onOpenSettings
        self.onReloadConfig = onReloadConfig
        self.onClearHistory = onClearHistory
        self.onQuit = onQuit
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        super.init()
        configureStatusItem()
    }

    private func configureStatusItem() {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "Petty")
            button.title = button.image == nil ? "Petty" : ""
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open Chat", action: #selector(openChat), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Reload Config", action: #selector(reloadConfig), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Clear Chat History", action: #selector(clearHistory), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Petty", action: #selector(quit), keyEquivalent: "q"))

        for item in menu.items {
            item.target = self
        }

        statusItem.menu = menu
    }

    @objc private func openChat() {
        onOpenChat()
    }

    @objc private func openSettings() {
        onOpenSettings()
    }

    @objc private func reloadConfig() {
        onReloadConfig()
    }

    @objc private func clearHistory() {
        onClearHistory()
    }

    @objc private func quit() {
        onQuit()
    }
}
