//
//  make-slash-icon.swift
//  Genera el arte del icono: tres barras negras inclinadas (///).
//
//  Salidas:
//  - Scripts/icon-source.png          → fondo blanco (legacy .appiconset)
//  - Resources/AppIcon.icon/Assets/Bars.png → barras con transparencia (Tahoe)
//
//  Uso: swift Scripts/make-slash-icon.swift
//

import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let sourceURL = root.appendingPathComponent("Scripts/icon-source.png")
let barsURL = root.appendingPathComponent("local-llm-studio/Resources/AppIcon.icon/Assets/Bars.png")

let size = 1024

// Tres barras inclinadas como /// — compactas, con fondo blanco generoso.
let barWidth: CGFloat = 100
let barHeight: CGFloat = 780
let gap: CGFloat = 130

func makeCanvas() -> NSBitmapImageRep? {
    NSBitmapImageRep(
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
    )
}

func drawBars(fillBackground: Bool) {
    if fillBackground {
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: size, height: size).fill()
    }

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
}

func forceOpaquePixels(in bitmap: NSBitmapImageRep) {
    guard let data = bitmap.bitmapData else { return }
    let bytesPerPixel = bitmap.bitsPerPixel / 8
    guard bytesPerPixel >= 4 else { return }

    let bytesPerRow = bitmap.bytesPerRow
    for y in 0..<bitmap.pixelsHigh {
        for x in 0..<bitmap.pixelsWide {
            data[y * bytesPerRow + x * bytesPerPixel + 3] = 255
        }
    }
}

func renderPNG(to url: URL, fillBackground: Bool) {
    guard let bitmap = makeCanvas() else {
        print("No se pudo crear el lienzo")
        exit(1)
    }

    try? FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    drawBars(fillBackground: fillBackground)
    NSGraphicsContext.restoreGraphicsState()

    if fillBackground {
        forceOpaquePixels(in: bitmap)
    }

    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        print("No se pudo codificar \(url.path)")
        exit(1)
    }

    try! data.write(to: url)
    print("Generado \(url.path) (\(size)×\(size))")
}

renderPNG(to: sourceURL, fillBackground: true)
renderPNG(to: barsURL, fillBackground: false)
