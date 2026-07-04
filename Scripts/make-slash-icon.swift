//
//  make-slash-icon.swift
//  Genera el arte fuente del icono: tres barras negras inclinadas
//  (///) sobre fondo blanco puro.
//
//  Uso: swift Scripts/make-slash-icon.swift [salida.png]
//

import AppKit
import Foundation

let outputURL = URL(fileURLWithPath: CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "Scripts/icon-source.png")

let size = 1024
guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: size,
    pixelsHigh: size,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    print("No se pudo crear el lienzo")
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

// Fondo blanco puro
NSColor.white.setFill()
NSRect(x: 0, y: 0, width: size, height: size).fill()

// Tres barras inclinadas como /// — ángulo ~22° respecto a la vertical
let barWidth: CGFloat = 72
let barHeight: CGFloat = 520
let gap: CGFloat = 118
let angle: CGFloat = 22 * .pi / 180

NSColor(white: 0.08, alpha: 1).setFill()

let centerX = CGFloat(size) / 2
let centerY = CGFloat(size) / 2
let totalWidth = barWidth * 3 + gap * 2
let startX = centerX - totalWidth / 2 + barWidth / 2

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

guard let data = bitmap.representation(using: .png, properties: [:]) else {
    print("No se pudo codificar el PNG")
    exit(1)
}

try! data.write(to: outputURL)
print("Generado \(outputURL.path) (\(size)×\(size))")
