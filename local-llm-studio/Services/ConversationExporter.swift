//
//  ConversationExporter.swift
//  local-llm-studio
//
//  Exportación de conversaciones a Markdown, con el documento
//  (FileDocument) que usa el fileExporter de SwiftUI.
//

import SwiftUI
import UniformTypeIdentifiers

enum ConversationExporter {

    /// Convierte una sesión completa a un documento Markdown legible.
    static func markdown(for session: ChatSession) -> String {
        var lines: [String] = []
        lines.append("# \(session.title)")
        lines.append("")
        lines.append("> Conversación de local-llm-studio · \(session.createdAt.formatted(date: .long, time: .shortened))")
        lines.append("")

        for message in session.orderedMessages {
            switch message.role {
            case .user:
                lines.append("## 🧑 Tú")
            case .assistant:
                var header = "## 🤖 Asistente"
                if let metrics = message.metrics {
                    header += " (\(metrics.modelName))"
                }
                if message.usedWeb {
                    header += " 🌐"
                }
                lines.append(header)
            case .system:
                continue
            }
            lines.append("")
            if message.imageData != nil {
                lines.append("*[Imagen adjunta]*")
                lines.append("")
            }
            if !message.content.isEmpty {
                lines.append(message.content)
                lines.append("")
            }
        }

        return lines.joined(separator: "\n")
    }

    /// Nombre de archivo seguro derivado del título de la sesión.
    static func suggestedFileName(for session: ChatSession) -> String {
        let sanitized = session.title
            .components(separatedBy: CharacterSet(charactersIn: "/\\:?%*|\"<>"))
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (sanitized.isEmpty ? "conversacion" : sanitized)
    }
}

/// Documento de texto Markdown para `fileExporter`.
struct MarkdownFile: FileDocument {
    static let readableContentTypes: [UTType] = [.plainText]

    var text: String

    init(text: String = "") {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        text = String(decoding: data, as: UTF8.self)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
