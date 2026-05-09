import SwiftUI

struct PetView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.clear

            Group {
                if let petPack = model.petPack {
                    SpritePetView(
                        petPack: petPack,
                        petState: model.petState,
                        reloadToken: model.petRenderToken
                    )
                } else {
                    PixelPetView(state: model.petState)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct PetSpeechBubbleView: View {
    let text: String

    private var previewText: String {
        let compactText = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard compactText.count > 96 else {
            return compactText
        }

        return String(compactText.prefix(96)).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(previewText)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.black.opacity(0.82))
                .lineLimit(2)
                .truncationMode(.tail)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: 244, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.white)
                        .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 3)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.black.opacity(0.65), lineWidth: 2)
                )

            SpeechTail()
                .fill(.white)
                .frame(width: 16, height: 9)
                .overlay(
                    SpeechTail()
                        .stroke(.black.opacity(0.65), lineWidth: 2)
                )
                .offset(y: -1)
        }
        .padding(.horizontal, 8)
    }
}

private struct SpeechTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

struct PixelPetView: View {
    let state: PetState

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(.black.opacity(0.18))
                .frame(width: 70, height: 64)
                .offset(x: 4, y: 7)

            VStack(spacing: 0) {
                ears
                face
                feet
            }
        }
        .animation(.spring(response: 0.24, dampingFraction: 0.76), value: state.rawValue)
    }

    private var ears: some View {
        HStack(spacing: 30) {
            Rectangle()
                .fill(state.bodyColor)
                .frame(width: 14, height: 14)
            Rectangle()
                .fill(state.bodyColor)
                .frame(width: 14, height: 14)
        }
        .offset(y: 6)
    }

    private var face: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(state.bodyColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(.black.opacity(0.72), lineWidth: 4)
                )
                .frame(width: 70, height: 56)

            Text(state.face)
                .font(.system(size: state == .thinking ? 18 : 19, weight: .heavy, design: .monospaced))
                .foregroundStyle(.black.opacity(0.8))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: 54)
        }
    }

    private var feet: some View {
        HStack(spacing: 26) {
            Rectangle()
                .fill(.black.opacity(0.72))
                .frame(width: 14, height: 8)
            Rectangle()
                .fill(.black.opacity(0.72))
                .frame(width: 14, height: 8)
        }
        .offset(y: -2)
    }
}
