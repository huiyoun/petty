import AppKit
import Combine
import SwiftUI

final class PetWindowController: NSWindowController {
    private let collapsedSize = NSSize(width: 96, height: 96)
    private let onToggleChat: (NSRect) -> Void
    private let speechPanel: SpeechBubbleWindowController
    private var speechCancellable: AnyCancellable?

    init(model: AppModel, onToggleChat: @escaping (NSRect) -> Void) {
        self.onToggleChat = onToggleChat
        let speechPanel = SpeechBubbleWindowController()
        self.speechPanel = speechPanel

        let window = NSPanel(
            contentRect: NSRect(origin: .zero, size: collapsedSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        window.level = .floating
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.hidesOnDeactivate = false
        window.isReleasedWhenClosed = false

        let contentView = PetHostingView(
            rootView: PetView(model: model),
            onDrag: { deltaX in
                model.petDragDidMove(deltaX: deltaX)
            },
            onDragEnd: {
                model.petDragDidEnd()
            },
            onMove: { [weak window] in
                guard let frame = window?.frame else { return }
                speechPanel.reposition(relativeTo: Self.petFrame(in: frame))
            },
            onClick: { [weak window] in
                guard let frame = window?.frame else { return }
                onToggleChat(Self.petFrame(in: frame))
            }
        )
        contentView.frame = window.contentView?.bounds ?? NSRect(origin: .zero, size: collapsedSize)
        contentView.autoresizingMask = [.width, .height]
        window.contentView = contentView

        if let screenFrame = NSScreen.main?.visibleFrame {
            let origin = NSPoint(
                x: screenFrame.maxX - 132,
                y: screenFrame.minY + 96
            )
            window.setFrameOrigin(origin)
        }

        super.init(window: window)

        speechCancellable = model.$petSpeech
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] speech in
                self?.setSpeech(speech)
            }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var currentPetFrame: NSRect? {
        guard let window else { return nil }
        return Self.petFrame(in: window.frame)
    }

    private func setSpeech(_ speech: String?) {
        guard let speech, let petFrame = currentPetFrame else {
            speechPanel.hide()
            return
        }

        window?.orderFrontRegardless()
        speechPanel.show(text: speech, relativeTo: petFrame)
    }

    private static func petFrame(in windowFrame: NSRect) -> NSRect {
        NSRect(
            x: windowFrame.midX - 48,
            y: windowFrame.minY,
            width: 96,
            height: 96
        )
    }
}

private final class SpeechBubbleWindowController: NSWindowController {
    private let bubbleSize = NSSize(width: 276, height: 86)

    init() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 276, height: 86),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.isReleasedWhenClosed = false

        super.init(window: panel)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(text: String, relativeTo petFrame: NSRect) {
        guard let window else { return }

        window.contentView = NSHostingView(
            rootView: PetSpeechBubbleView(text: text)
                .frame(width: bubbleSize.width, height: bubbleSize.height, alignment: .bottom)
        )
        reposition(relativeTo: petFrame)
        window.orderFrontRegardless()
    }

    func hide() {
        window?.orderOut(nil)
    }

    func reposition(relativeTo petFrame: NSRect) {
        guard let window else { return }

        var origin = NSPoint(
            x: petFrame.midX - bubbleSize.width / 2,
            y: petFrame.maxY + 4
        )

        if let screenFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame {
            origin.x = min(max(origin.x, screenFrame.minX + 8), screenFrame.maxX - bubbleSize.width - 8)
            origin.y = min(max(origin.y, screenFrame.minY + 8), screenFrame.maxY - bubbleSize.height - 8)
        }

        window.setFrame(NSRect(origin: origin, size: bubbleSize), display: true)
    }
}

private final class PetHostingView<Content: View>: NSHostingView<Content> {
    private let onClick: () -> Void
    private let onDrag: (CGFloat) -> Void
    private let onDragEnd: () -> Void
    private let onMove: () -> Void
    private var mouseDownLocation: NSPoint?
    private var windowOriginAtMouseDown: NSPoint?
    private var didDrag = false

    init(
        rootView: Content,
        onDrag: @escaping (CGFloat) -> Void,
        onDragEnd: @escaping () -> Void,
        onMove: @escaping () -> Void,
        onClick: @escaping () -> Void
    ) {
        self.onClick = onClick
        self.onDrag = onDrag
        self.onDragEnd = onDragEnd
        self.onMove = onMove
        super.init(rootView: rootView)
    }

    @available(*, unavailable)
    required init(rootView: Content) {
        fatalError("init(rootView:) has not been implemented")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownLocation = NSEvent.mouseLocation
        windowOriginAtMouseDown = window?.frame.origin
        didDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard
            let start = mouseDownLocation,
            let origin = windowOriginAtMouseDown,
            let window
        else {
            return
        }

        let current = NSEvent.mouseLocation
        let delta = NSPoint(x: current.x - start.x, y: current.y - start.y)

        if abs(delta.x) > 2 || abs(delta.y) > 2 {
            didDrag = true
            onDrag(delta.x)
        }

        window.setFrameOrigin(NSPoint(x: origin.x + delta.x, y: origin.y + delta.y))
        onMove()
    }

    override func mouseUp(with event: NSEvent) {
        if didDrag {
            onDragEnd()
        } else {
            onClick()
        }

        mouseDownLocation = nil
        windowOriginAtMouseDown = nil
        didDrag = false
    }
}
