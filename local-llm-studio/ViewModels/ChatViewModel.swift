//
//  ChatViewModel.swift
//  local-llm-studio
//
//  Estado observable de una conversación con un modelo local de Ollama,
//  con soporte de streaming token a token en la UI.
//

import Foundation
import Observation

@MainActor
@Observable
final class ChatViewModel {

    /// Mensajes de la conversación actual, en orden cronológico.
    private(set) var messages: [ChatMessage] = []

    /// `true` mientras el modelo local está generando una respuesta.
    private(set) var isGenerating = false

    /// Último error de generación, apto para mostrar en la UI.
    private(set) var errorMessage: String?

    /// Texto que el usuario está escribiendo en el campo de entrada.
    var draft = ""

    private let service: OllamaService
    private var generationTask: Task<Void, Never>?

    init(service: OllamaService = OllamaService()) {
        self.service = service
    }

    var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isGenerating
    }

    /// Envía el borrador actual al modelo indicado y va acumulando la
    /// respuesta en streaming sobre el último mensaje del asistente.
    func send(to model: String) {
        let prompt = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !isGenerating else { return }

        draft = ""
        errorMessage = nil
        messages.append(ChatMessage(role: .user, content: prompt))

        let history = messages
        isGenerating = true

        generationTask = Task {
            // Mensaje vacío del asistente que se rellena token a token.
            var assistantMessage = ChatMessage(role: .assistant, content: "")
            messages.append(assistantMessage)
            let assistantIndex = messages.count - 1

            do {
                let stream = try await service.streamChat(model: model, messages: history)
                for try await fragment in stream {
                    assistantMessage.content += fragment
                    messages[assistantIndex] = assistantMessage
                }
            } catch is CancellationError {
                // Cancelación pedida por el usuario: se conserva el texto parcial.
            } catch {
                errorMessage = error.localizedDescription
                // No dejamos burbujas vacías si falló antes del primer token.
                if messages.indices.contains(assistantIndex),
                   messages[assistantIndex].content.isEmpty {
                    messages.remove(at: assistantIndex)
                }
            }

            isGenerating = false
        }
    }

    /// Detiene la generación en curso conservando el texto ya recibido.
    func stopGeneration() {
        generationTask?.cancel()
        generationTask = nil
        isGenerating = false
    }

    /// Comienza una conversación nueva descartando el historial actual.
    func clearConversation() {
        stopGeneration()
        messages = []
        errorMessage = nil
    }
}
