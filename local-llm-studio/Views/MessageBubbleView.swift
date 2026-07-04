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

                if !isUser && message.usedWeb {
                    Label("Con información de internet", systemImage: "globe")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .help("Esta respuesta usó resultados de una búsqueda web")
                }
            }

            if !isUser { Spacer(minLength: 60) }
        }
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
