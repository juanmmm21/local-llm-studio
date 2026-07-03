//
//  ChatViewModel.swift
//  local-llm-studio
//
//  Estado observable de la conversación activa, con streaming token a
//  token, persistencia en SwiftData e inyección de contexto RAG local.
//

import Foundation
import Observation
import SwiftData

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

    /// Si está activo, se buscan fragmentos relevantes de la biblioteca
    /// local y se inyectan como contexto en el prompt (RAG privado).
    var useLibrary = true

    private let service: OllamaService
    private var generationTask: Task<Void, Never>?
    private var modelContext: ModelContext?
    private(set) var session: ChatSession?

    init(service: OllamaService = OllamaService()) {
        self.service = service
    }

    var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isGenerating
    }

    // MARK: - Sesiones persistidas

    func configure(context: ModelContext) {
        modelContext = context
    }

    /// Activa una sesión persistida y carga su historial en memoria.
    func attach(session: ChatSession) {
        guard session !== self.session else { return }
        stopGeneration()
        self.session = session
        messages = session.orderedMessages.map(\.asChatMessage)
        errorMessage = nil
    }

    // MARK: - Generación

    /// Envía el borrador actual al modelo indicado y va acumulando la
    /// respuesta en streaming sobre el último mensaje del asistente.
    func send(to model: String) {
        let prompt = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !isGenerating else { return }

        draft = ""
        errorMessage = nil

        let userMessage = ChatMessage(role: .user, content: prompt)
        messages.append(userMessage)
        persist(userMessage)
        updateSessionMetadata(firstPrompt: prompt)

        // El contexto RAG se envía a la API pero no se guarda ni se pinta.
        var history = messages
        isGenerating = true

        generationTask = Task {
            if useLibrary, let contextMessage = await libraryContextMessage(for: prompt) {
                history.insert(contextMessage, at: max(0, history.count - 1))
            }

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

            if messages.indices.contains(assistantIndex),
               !messages[assistantIndex].content.isEmpty {
                persist(messages[assistantIndex])
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

    // MARK: - RAG local

    /// Recupera los fragmentos más relevantes de la biblioteca y los
    /// convierte en un mensaje de sistema. Devuelve `nil` si la biblioteca
    /// está vacía o no hay nada suficientemente relacionado.
    private func libraryContextMessage(for query: String) async -> ChatMessage? {
        guard let modelContext else { return nil }
        let chunks = (try? modelContext.fetch(FetchDescriptor<DocumentChunk>())) ?? []
        guard !chunks.isEmpty else { return nil }

        let queryEmbedding = try? await service.embed(texts: [query]).first
        let relevant = ContextRetriever.topChunks(
            for: query,
            among: chunks,
            queryEmbedding: queryEmbedding ?? nil
        )
        guard !relevant.isEmpty else { return nil }

        return ChatMessage(role: .system, content: ContextRetriever.contextPrompt(for: relevant))
    }

    // MARK: - Persistencia

    private func persist(_ message: ChatMessage) {
        guard let session, let modelContext else { return }
        let stored = StoredMessage(role: message.role, content: message.content, createdAt: message.createdAt)
        stored.session = session
        modelContext.insert(stored)
        session.updatedAt = .now
        try? modelContext.save()
    }

    private func updateSessionMetadata(firstPrompt: String) {
        guard let session else { return }
        if session.title == ChatSession.defaultTitle {
            session.title = String(firstPrompt.prefix(48))
        }
        session.updatedAt = .now
        try? modelContext?.save()
    }
}
