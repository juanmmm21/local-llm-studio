//
//  make-app-icon.swift
//  Herramienta de desarrollo (no forma parte de la app).
//
//  Toma un PNG cuadrado a sangre completa y genera los diez tamaños del
//  AppIcon.appiconset de macOS.
//
//  macOS 26 (Tahoe) encierra el icono en un marco gris si detecta píxeles con
//  alpha ≤ 252; forzamos alpha = 255 en todo el lienzo tras renderizar.
//
//  Uso: swift Scripts/make-app-icon.swift <entrada.png> <carpeta appiconset>
//

import AppKit
import Foundation

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    print("Uso: swift make-app-icon.swift <entrada.png> <carpeta appiconset>")
    exit(1)
}

let inputURL = URL(fileURLWithPath: arguments[1])
let outputDirectory = URL(fileURLWithPath: arguments[2], isDirectory: true)

guard let source = NSImage(contentsOf: inputURL) else {
    print("No se pudo leer \(inputURL.path)")
    exit(1)
}

/// Tahoe 26 exige alpha ≥ 253 en todos los píxeles para evitar el marco gris.
func forceOpaquePixels(in bitmap: NSBitmapImageRep) {
    guard let data = bitmap.bitmapData else { return }
    let bytesPerPixel = bitmap.bitsPerPixel / 8
    guard bytesPerPixel >= 4 else { return }

    let bytesPerRow = bitmap.bytesPerRow
    let height = bitmap.pixelsHigh
    let width = bitmap.pixelsWide

    for y in 0..<height {
        for x in 0..<width {
            data[y * bytesPerRow + x * bytesPerPixel + 3] = 255
        }
    }
}

func renderIcon(pixelSize: Int, to url: URL) {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        print("No se pudo crear el lienzo de \(pixelSize)px")
        exit(1)
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

    let canvas = CGFloat(pixelSize)
    let squareRect = NSRect(x: 0, y: 0, width: canvas, height: canvas)

    // Fondo blanco opaco antes de pintar: evita píxeles transparentes residuales.
    NSColor.white.setFill()
    squareRect.fill()
    source.draw(in: squareRect, from: .zero, operation: .sourceOver, fraction: 1)

    NSGraphicsContext.restoreGraphicsState()
    forceOpaquePixels(in: bitmap)

    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        print("No se pudo codificar el PNG de \(pixelSize)px")
        exit(1)
    }
    try! data.write(to: url)
    print("Generado \(url.lastPathComponent) (\(pixelSize)px)")
}

let variants: [(fileName: String, pixels: Int)] = [
    ("icon_16.png", 16), ("icon_16@2x.png", 32),
    ("icon_32.png", 32), ("icon_32@2x.png", 64),
    ("icon_128.png", 128), ("icon_128@2x.png", 256),
    ("icon_256.png", 256), ("icon_256@2x.png", 512),
    ("icon_512.png", 512), ("icon_512@2x.png", 1024)
]

for variant in variants {
    renderIcon(pixelSize: variant.pixels, to: outputDirectory.appendingPathComponent(variant.fileName))
}
