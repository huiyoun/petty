import SwiftUI

struct MessageBubbleView: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 40)
            }

            Text(message.text)
                .font(.body)
                .foregroundStyle(foregroundColor)
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: 276, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .background(backgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .textSelection(.enabled)

            if message.role != .user {
                Spacer(minLength: 40)
            }
        }
    }

    private var backgroundColor: Color {
        switch message.role {
        case .user:
            Color.accentColor
        case .assistant:
            Color(NSColor.controlBackgroundColor)
        case .system:
            Color.orange.opacity(0.18)
        }
    }

    private var foregroundColor: Color {
        message.role == .user ? .white : .primary
    }
}
