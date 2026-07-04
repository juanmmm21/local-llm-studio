//
//  MessageBubbleView.swift
//  local-llm-studio
//
//  Burbuja de mensaje del chat, con estilos distintos para el usuario
//  y para el modelo local.
//

import SwiftUI

struct MessageBubbleView: View {
    let message: ChatMessage
    /// `true` mientras esta burbuja está recibiendo tokens del modelo.
    var isStreaming = false

    @State private var isShowingSources = false

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .bottom) {
            if isUser { Spacer(minLength: 60) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(isUser ? "Tú" : "Modelo local")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Group {
                    if message.content.isEmpty && isStreaming {
                        // Aún no ha llegado el primer token.
                        ProgressView()
                            .controlSize(.small)
                            .padding(4)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            if let imageData = message.imageData, let image = NSImage(data: imageData) {
                                Image(nsImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: 280, maxHeight: 280)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            if !message.content.isEmpty {
                                MessageContentView(content: message.content)
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    isUser ? AnyShapeStyle(Color.accentColor.opacity(0.18))
                           : AnyShapeStyle(.quaternary.opacity(0.5)),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )

                if !isUser && (message.usedWeb || message.metrics != nil || hasSources) {
                    HStack(spacing: 10) {
                        if let metrics = message.metrics {
                            Text("\(metrics.modelName) · \(metrics.tokensPerSecond, format: .number.precision(.fractionLength(1))) tok/s · \(metrics.durationSeconds, format: .number.precision(.fractionLength(1))) s")
                                .help("\(metrics.tokenCount) tokens generados")
                        }
                        if message.usedWeb {
                            Label("Con información de internet", systemImage: "globe")
                                .help("Esta respuesta usó resultados de una búsqueda web")
                        }
                        if let sources = message.ragSources, !sources.isEmpty {
                            Button {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    isShowingSources.toggle()
                                }
                            } label: {
                                Label(
                                    "\(sources.count) \(sources.count == 1 ? "fragmento" : "fragmentos") de tu biblioteca",
                                    systemImage: isShowingSources ? "chevron.down" : "books.vertical"
                                )
                            }
                            .buttonStyle(.plain)
                            .help("Ver los fragmentos de tus documentos usados como contexto")
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                    if isShowingSources, let sources = message.ragSources {
                        sourcesList(sources)
                    }
                }
            }

            if !isUser { Spacer(minLength: 60) }
        }
    }

    private var hasSources: Bool {
        !(message.ragSources ?? []).isEmpty
    }

    /// Fragmentos de la biblioteca que se inyectaron como contexto,
    /// para que el usuario compruebe de dónde sale la respuesta.
    private func sourcesList(_ sources: [RAGSource]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(sources.enumerated()), id: \.offset) { _, source in
                VStack(alignment: .leading, spacing: 2) {
                    Label(source.documentName, systemImage: "doc.text")
                        .font(.caption.bold())
                    Text(source.excerpt + "…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: 420, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    VStack(spacing: 12) {
        MessageBubbleView(message: ChatMessage(role: .user, content: "¿Qué es SwiftData?"))
        MessageBubbleView(message: ChatMessage(role: .assistant, content: "SwiftData es el framework de persistencia nativo de Apple…"))
        MessageBubbleView(message: ChatMessage(role: .assistant, content: ""), isStreaming: true)
    }
    .padding()
    .frame(width: 480)
}
