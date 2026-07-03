//
//  DocumentIndexer.swift
//  local-llm-studio
//
//  Extracción de texto y fragmentación (chunking) de documentos locales
//  para la biblioteca RAG. Todo el procesamiento es nativo y offline:
//  Foundation para texto plano/Markdown y PDFKit para PDF.
//

import Foundation
import PDFKit

enum DocumentIndexerError: LocalizedError {
    case unsupportedType(String)
    case unreadable(String)
    case emptyDocument(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedType(let name):
            return "\(name): tipo de archivo no soportado (usa Markdown, TXT o PDF)."
        case .unreadable(let name):
            return "\(name): no se pudo leer el archivo."
        case .emptyDocument(let name):
            return "\(name): el documento no contiene texto extraíble."
        }
    }
}

enum DocumentIndexer {

    static let supportedExtensions: Set<String> = ["md", "markdown", "txt", "text", "pdf"]

    /// Extrae el texto plano de un documento ya leído en memoria.
    ///
    /// Se trabaja sobre `Data` y no sobre la URL porque el permiso del
    /// sandbox que concede el selector de archivos es efímero: los bytes
    /// se leen en el momento de la selección y el procesado pesado ocurre
    /// después, ya sin depender del ámbito de seguridad.
    static func extractText(from data: Data, fileExtension: String, name: String) throws -> String {
        guard supportedExtensions.contains(fileExtension) else {
            throw DocumentIndexerError.unsupportedType(name)
        }

        let text: String
        if fileExtension == "pdf" {
            guard let pdf = PDFDocument(data: data), let content = pdf.string else {
                throw DocumentIndexerError.unreadable(name)
            }
            text = content
        } else {
            guard let content = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .isoLatin1) else {
                throw DocumentIndexerError.unreadable(name)
            }
            text = content
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw DocumentIndexerError.emptyDocument(name)
        }
        return trimmed
    }

    /// Fragmenta el texto en trozos de ~`targetSize` caracteres respetando
    /// los párrafos, con solapamiento de un párrafo entre fragmentos para
    /// no cortar ideas por la mitad.
    static func chunk(_ text: String, targetSize: Int = 1200) -> [String] {
        let paragraphs = text
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var chunks: [String] = []
        var current: [String] = []
        var currentLength = 0

        for paragraph in paragraphs {
            // Un párrafo enorme se parte en frases para no exceder el objetivo.
            let pieces = paragraph.count > targetSize
                ? splitOversizedParagraph(paragraph, targetSize: targetSize)
                : [paragraph]

            for piece in pieces {
                if currentLength + piece.count > targetSize, !current.isEmpty {
                    chunks.append(current.joined(separator: "\n\n"))
                    // Solapamiento: el último párrafo abre el siguiente fragmento.
                    let overlap = current.last.map { [$0] } ?? []
                    current = overlap
                    currentLength = overlap.first?.count ?? 0
                }
                current.append(piece)
                currentLength += piece.count
            }
        }

        if !current.isEmpty {
            chunks.append(current.joined(separator: "\n\n"))
        }
        return chunks
    }

    private static func splitOversizedParagraph(_ paragraph: String, targetSize: Int) -> [String] {
        var pieces: [String] = []
        var current = ""
        paragraph.enumerateSubstrings(in: paragraph.startIndex..., options: .bySentences) { sentence, _, _, _ in
            guard let sentence else { return }
            if current.count + sentence.count > targetSize, !current.isEmpty {
                pieces.append(current)
                current = ""
            }
            current += sentence
        }
        if !current.isEmpty {
            pieces.append(current)
        }
        return pieces
    }
}
