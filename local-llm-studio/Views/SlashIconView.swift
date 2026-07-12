//
//  SlashIconView.swift
//  local-llm-studio
//
//  Las tres barras inclinadas (///) del icono de la app. En la barra de
//  menús se renderiza como imagen plantilla para que macOS aplique el color
//  correcto (claro/oscuro) automáticamente.
//

import AppKit
import SwiftUI

enum SlashIconRenderer {
    private static let cached = makeTemplateImage()

    static func templateImage() -> NSImage {
        cached
    }

    private static func makeTemplateImage() -> NSImage {
        let pixelSize: CGFloat = 36
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(pixelSize),
            pixelsHigh: Int(pixelSize),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return NSImage()
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

        let barWidth = pixelSize * 0.16
        let barHeight = pixelSize * 0.78
        let gap = pixelSize * 0.18
        let totalWidth = barWidth * 3 + gap * 2
        let startX = (pixelSize - totalWidth) / 2 + barWidth / 2
        let centerY = pixelSize / 2

        NSColor.black.setFill()

        for index in 0..<3 {
            let x = startX + CGFloat(index) * (barWidth + gap)

            NSGraphicsContext.saveGraphicsState()
            let transform = NSAffineTransform()
            transform.translateX(by: x, yBy: centerY)
            transform.rotate(byDegrees: 22)
            transform.concat()

            let rect = NSRect(
                x: -barWidth / 2,
                y: -barHeight / 2,
                width: barWidth,
                height: barHeight
            )
            NSBezierPath(roundedRect: rect, xRadius: barWidth / 2, yRadius: barWidth / 2).fill()
            NSGraphicsContext.restoreGraphicsState()
        }

        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: NSSize(width: 18, height: 18))
        image.addRepresentation(bitmap)
        image.isTemplate = true
        return image
    }
}

struct SlashIconView: View {
    var body: some View {
        Image(nsImage: SlashIconRenderer.templateImage())
            .renderingMode(.template)
            .frame(width: 18, height: 18)
            .accessibilityLabel("Pregunta rápida")
    }
}

#Preview {
    SlashIconView()
        .padding()
}
