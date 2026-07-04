//
//  make-app-icon.swift
//  Herramienta de desarrollo (no forma parte de la app).
//
//  Toma un PNG cuadrado a sangre completa y genera los diez tamaños del
//  AppIcon.appiconset de macOS, aplicando el estilo nativo: margen
//  transparente y recorte de esquinas redondeadas.
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

/// Proporciones de la retícula oficial de iconos de macOS:
/// el cuadrado redondeado ocupa 824/1024 del lienzo y su radio de
/// esquina es ~185/824 del tamaño del propio cuadrado.
let insetRatio: CGFloat = (1024 - 824) / 2 / 1024
let cornerRatio: CGFloat = 185.0 / 824.0

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
    let inset = (canvas * insetRatio).rounded()
    let squareRect = NSRect(x: inset, y: inset, width: canvas - inset * 2, height: canvas - inset * 2)
    let radius = squareRect.width * cornerRatio

    NSBezierPath(roundedRect: squareRect, xRadius: radius, yRadius: radius).addClip()
    source.draw(in: squareRect, from: .zero, operation: .copy, fraction: 1)

    NSGraphicsContext.restoreGraphicsState()

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
