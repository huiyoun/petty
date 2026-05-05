import AppKit
import SwiftUI

struct SpritePetView: View {
    let petPack: PetPack
    let petState: PetState

    @State private var spritesheet: NSImage?
    @State private var frameIndex = 0
    @State private var animationKey = ""

    private var animation: PetAnimation {
        petPack.animation(for: petState)
    }

    private var timerInterval: TimeInterval {
        max(1.0 / animation.fps, 0.04)
    }

    var body: some View {
        Group {
            if let frameImage = currentFrameImage {
                Image(decorative: frameImage, scale: 1, orientation: .up)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
            } else {
                PixelPetView(state: petState)
            }
        }
        .frame(width: 96, height: 96)
        .onAppear {
            loadSpritesheetIfNeeded()
            resetFrameIfNeeded()
        }
        .onChange(of: petState.rawValue) { _, _ in
            resetFrameIfNeeded()
        }
        .onReceive(Timer.publish(every: timerInterval, on: .main, in: .common).autoconnect()) { _ in
            guard animation.frameCount > 1 else { return }
            frameIndex = (frameIndex + 1) % animation.frameCount
        }
    }

    private var currentFrameImage: CGImage? {
        guard
            let spritesheet,
            let cgImage = spritesheet.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else {
            return nil
        }

        let column = min(frameIndex, animation.frameCount - 1)
        let pixelScaleX = CGFloat(cgImage.width) / CGFloat(PetPackAtlas.width)
        let pixelScaleY = CGFloat(cgImage.height) / CGFloat(PetPackAtlas.height)
        let cropRect = CGRect(
            x: CGFloat(column * PetPackAtlas.cellWidth) * pixelScaleX,
            y: CGFloat(animation.row * PetPackAtlas.cellHeight) * pixelScaleY,
            width: CGFloat(PetPackAtlas.cellWidth) * pixelScaleX,
            height: CGFloat(PetPackAtlas.cellHeight) * pixelScaleY
        ).integral

        return cgImage.cropping(to: cropRect)
    }

    private func loadSpritesheetIfNeeded() {
        guard spritesheet == nil else { return }
        spritesheet = NSImage(contentsOf: petPack.spritesheetURL)
    }

    private func resetFrameIfNeeded() {
        let key = "\(petState.rawValue):\(animation.row):\(animation.frameCount)"
        guard animationKey != key else { return }
        animationKey = key
        frameIndex = 0
    }
}
