//
//  MessageContentView.swift
//  local-llm-studio
//
//  Renderizado enriquecido del contenido de un mensaje: Markdown en línea
//  para el texto y bloques de código con etiqueta de lenguaje y botón de
//  copiar. Sin librerías externas.
//

import SwiftUI

struct MessageContentView: View {
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Self.segments(from: content)) { segment in
                switch segment.kind {
                case .text(let text):
                    Text(LocalizedStringKey(text))
                        .textSelection(.enabled)
                case .code(let language, let code):
                    CodeBlockView(language: language, code: code)
                }
            }
        }
    }

    // MARK: - Segmentación del Markdown

    struct Segment: Identifiable {
        enum Kind {
            case text(String)
            case code(language: String?, code: String)
        }

        let id: Int
        let kind: Kind
    }

    /// Separa el contenido en texto y bloques de código delimitados por
    /// vallas ```. Un bloque sin cerrar (durante el streaming) se trata
    /// como código para que se pinte bien mientras llega.
    static func segments(from content: String) -> [Segment] {
        var segments: [Segment] = []
        var currentText: [String] = []
        var currentCode: [String] = []
        var codeLanguage: String?
        var insideCode = false

        func flushText() {
            let text = currentText.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                segments.append(Segment(id: segments.count, kind: .text(text)))
            }
            currentText = []
        }

        func flushCode() {
            let code = currentCode.joined(separator: "\n")
            if !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                segments.append(Segment(id: segments.count, kind: .code(language: codeLanguage, code: code)))
            }
            currentCode = []
            codeLanguage = nil
        }

        for line in content.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                if insideCode {
                    flushCode()
                } else {
                    flushText()
                    let language = trimmed.dropFirst(3).trimmingCharacters(in: .whitespaces)
                    codeLanguage = language.isEmpty ? nil : language
                }
                insideCode.toggle()
            } else if insideCode {
                currentCode.append(line)
            } else {
                currentText.append(line)
            }
        }

        insideCode ? flushCode() : flushText()
        return segments
    }
}

// MARK: - Bloque de código

private struct CodeBlockView: View {
    let language: String?
    let code: String

    @State private var justCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(language ?? "código")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(code, forType: .string)
                    justCopied = true
                    Task {
                        try? await Task.sleep(for: .seconds(1.5))
                        justCopied = false
                    }
                } label: {
                    Label(justCopied ? "Copiado" : "Copiar",
                          systemImage: justCopied ? "checkmark" : "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(justCopied ? .green : .secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.black.opacity(0.25))

            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.callout.monospaced())
                    .textSelection(.enabled)
                    .padding(10)
            }
        }
        .background(.black.opacity(0.85))
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    MessageContentView(content: """
    Aquí tienes un ejemplo en **Swift**:

    ```swift
    let saludo = "Hola"
    print(saludo)
    ```

    Y esto es texto normal con `código en línea`.
    """)
    .padding()
    .frame(width: 420)
}
