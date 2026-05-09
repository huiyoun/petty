import AppKit
import SwiftUI

extension Notification.Name {
    static let pettyChatPanelDidOpen = Notification.Name("PettyChatPanelDidOpen")
}

struct ChatView: View {
    @ObservedObject var model: AppModel
    @State private var draft = ""
    @State private var titleDraft = ""
    @State private var isEditingTitle = false
    @FocusState private var isTitleFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            messages
            Divider()
            composer
        }
        .frame(minWidth: 340, minHeight: 400)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(model.petState.bodyColor)
                .frame(width: 12, height: 12)

            titleControl

            Spacer()

            Text(model.petState.rawValue)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var titleControl: some View {
        HStack(spacing: 6) {
            if isEditingTitle {
                TextField("Chat name", text: $titleDraft)
                    .font(.headline)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 180)
                    .focused($isTitleFieldFocused)
                    .onSubmit(saveTitle)

                titleIconButton(systemName: "checkmark", accessibilityLabel: "Save chat name") {
                    saveTitle()
                }

                titleIconButton(systemName: "xmark", accessibilityLabel: "Cancel chat name edit") {
                    cancelTitleEdit()
                }
            } else {
                Text(model.chatTitle)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.tail)

                titleIconButton(systemName: "pencil", accessibilityLabel: "Edit chat name") {
                    beginTitleEdit()
                }
            }
        }
        .onChange(of: model.chatTitle) { _, newValue in
            guard !isEditingTitle else { return }
            titleDraft = newValue
        }
    }

    private func titleIconButton(
        systemName: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .accessibilityLabel(accessibilityLabel)
    }

    private var messages: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(model.messages) { message in
                        MessageBubbleView(message: message)
                            .id(message.id)
                    }
                }
                .padding(14)
            }
            .onAppear {
                scrollToLatest(proxy, animated: false)
            }
            .onReceive(NotificationCenter.default.publisher(for: .pettyChatPanelDidOpen)) { _ in
                scrollToLatest(proxy, animated: false)
            }
            .onChange(of: model.messages) { _, messages in
                guard let last = messages.last else { return }
                withAnimation {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    private func scrollToLatest(_ proxy: ScrollViewProxy, animated: Bool) {
        guard let last = model.messages.last else { return }

        let scroll = {
            if animated {
                withAnimation {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            } else {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }

        scroll()
        DispatchQueue.main.async(execute: scroll)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: scroll)
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let errorText = model.errorText {
                Text(errorText)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }

            HStack(spacing: 8) {
                ZStack(alignment: .topLeading) {
                    ChatInputView(
                        text: $draft,
                        isDisabled: model.isSending,
                        onSubmit: send
                    )
                    .frame(minHeight: 34, maxHeight: 84)

                    if draft.isEmpty {
                        Text("Message your agent")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                    }
                }

                Button("Send", action: send)
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(!canSend)
            }
        }
        .padding(12)
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !model.isSending
    }

    private func send() {
        guard canSend else { return }
        let message = draft
        draft = ""
        model.send(message)
    }

    private func beginTitleEdit() {
        titleDraft = model.chatTitle
        isEditingTitle = true
        DispatchQueue.main.async {
            isTitleFieldFocused = true
        }
    }

    private func saveTitle() {
        model.setChatDisplayName(titleDraft)
        isEditingTitle = false
        isTitleFieldFocused = false
    }

    private func cancelTitleEdit() {
        titleDraft = model.chatTitle
        isEditingTitle = false
        isTitleFieldFocused = false
    }
}

private struct ChatInputView: NSViewRepresentable {
    @Binding var text: String
    let isDisabled: Bool
    let onSubmit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = SubmitTextView()
        textView.delegate = context.coordinator
        textView.onSubmit = onSubmit
        textView.font = NSFont.systemFont(ofSize: 13)
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 8, height: 7)
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 34)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: 84)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )

        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.documentView = textView
        scrollView.wantsLayer = true
        scrollView.layer?.cornerRadius = 6
        scrollView.layer?.borderWidth = 1
        scrollView.layer?.borderColor = NSColor.separatorColor.cgColor
        scrollView.layer?.backgroundColor = NSColor.textBackgroundColor.cgColor

        context.coordinator.textView = textView
        context.coordinator.focus()
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = scrollView.documentView as? SubmitTextView else { return }

        textView.onSubmit = onSubmit
        textView.isEditable = !isDisabled
        textView.alphaValue = isDisabled ? 0.58 : 1.0

        if textView.string != text {
            textView.string = text
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ChatInputView
        weak var textView: NSTextView?
        private var observer: NSObjectProtocol?

        init(_ parent: ChatInputView) {
            self.parent = parent
            super.init()

            observer = NotificationCenter.default.addObserver(
                forName: .pettyChatPanelDidOpen,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.focus()
            }
        }

        deinit {
            if let observer {
                NotificationCenter.default.removeObserver(observer)
            }
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }

        func focus() {
            DispatchQueue.main.async { [weak self] in
                guard let self, let textView = self.textView, !parent.isDisabled else { return }
                textView.window?.makeFirstResponder(textView)
            }
        }
    }
}

private final class SubmitTextView: NSTextView {
    var onSubmit: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        let isReturn = event.keyCode == 36 || event.keyCode == 76
        let usesShift = event.modifierFlags.contains(.shift)

        if isReturn && !usesShift {
            onSubmit?()
            return
        }

        super.keyDown(with: event)
    }
}
