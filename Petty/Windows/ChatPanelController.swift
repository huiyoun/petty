import AppKit
import SwiftUI

final class ChatPanelController: NSWindowController, NSWindowDelegate {
    private let model: AppModel

    init(model: AppModel) {
        self.model = model

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 430),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.level = .normal
        panel.title = "Petty"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = true
        panel.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.96)
        panel.contentView = NSHostingView(rootView: ChatView(model: model))

        super.init(window: panel)
        panel.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func toggle(relativeTo petFrame: NSRect) {
        guard let window else { return }

        if window.isVisible {
            hide()
            return
        }

        show(relativeTo: petFrame)
    }

    func show(relativeTo petFrame: NSRect) {
        guard let window else { return }
        position(relativeTo: petFrame)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        model.chatPanelDidOpen()
        NotificationCenter.default.post(name: .pettyChatPanelDidOpen, object: nil)
    }

    func hide() {
        model.chatPanelDidClose()
        window?.orderOut(nil)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        hide()
        return false
    }

    private func position(relativeTo petFrame: NSRect) {
        guard let window else { return }

        let panelSize = window.frame.size
        let spacing: CGFloat = 12
        let proposed = NSPoint(
            x: petFrame.minX - panelSize.width - spacing,
            y: petFrame.maxY + spacing
        )

        guard let screenFrame = NSScreen.main?.visibleFrame else {
            window.setFrameOrigin(proposed)
            return
        }

        let x = min(max(proposed.x, screenFrame.minX + spacing), screenFrame.maxX - panelSize.width - spacing)
        let y = min(max(proposed.y, screenFrame.minY + spacing), screenFrame.maxY - panelSize.height - spacing)
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
