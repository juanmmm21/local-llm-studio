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

    /// Imagen adjunta al borrador, para modelos con visión (LLaVA).
    var draftImage: Data?

    /// Si está activo, se buscan fragmentos relevantes de la biblioteca
    /// local y se inyectan como contexto en el prompt (RAG privado).
    var useLibrary = true

    /// Interruptor de privacidad de la búsqueda web (Fase 4). Desactivado
    /// por defecto: solo si el usuario lo enciende, la pregunta se envía
    /// al buscador. Se recuerda entre sesiones.
    var isWebSearchEnabled: Bool {
        didSet { UserDefaults.standard.set(isWebSearchEnabled, forKey: Self.webSearchKey) }
    }

    private static let webSearchKey = "assistant.webSearchEnabled"

    private let service: OllamaService
    private let webSearch = WebSearchService()
    private var generationTask: Task<Void, Never>?
    private var modelContext: ModelContext?
    private(set) var session: ChatSession?

    init(service: OllamaService = OllamaService()) {
        self.service = service
        self.isWebSearchEnabled = UserDefaults.standard.bool(forKey: Self.webSearchKey)
    }

    var canSend: Bool {
        let hasContent = !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || draftImage != nil
        return hasContent && !isGenerating
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
        let image = draftImage
        guard !prompt.isEmpty || image != nil, !isGenerating else { return }

        draft = ""
        draftImage = nil
        errorMessage = nil

        let userMessage = ChatMessage(role: .user, content: prompt, imageData: image)
        messages.append(userMessage)
        persist(userMessage)
        updateSessionMetadata(firstPrompt: prompt.isEmpty ? "Imagen adjunta" : prompt)

        generate(model: model)
    }

    /// `true` si la última respuesta del asistente se puede regenerar.
    var canRegenerate: Bool {
        !isGenerating && messages.last?.role == .assistant
    }

    /// Descarta la última respuesta del asistente y genera una nueva
    /// (útil para probar otra redacción o incluso otro modelo).
    func regenerate(model: String) {
        guard !isGenerating,
              let lastAssistant = messages.lastIndex(where: { $0.role == .assistant }) else { return }
        removeMessages(from: lastAssistant)
        errorMessage = nil
        generate(model: model)
    }

    /// Devuelve un mensaje del usuario al borrador para editarlo,
    /// recortando la conversación desde ese punto (incluida la respuesta
    /// que provocó). Al reenviar, la conversación continúa desde ahí.
    func editAndResend(_ message: ChatMessage) {
        guard !isGenerating, message.role == .user,
              let index = messages.firstIndex(where: { $0.id == message.id }) else { return }
        draft = message.content
        draftImage = message.imageData
        removeMessages(from: index)
        errorMessage = nil
    }

    /// Elimina de la memoria y del historial persistido los mensajes desde
    /// `index` (inclusive) hasta el final de la conversación.
    private func removeMessages(from index: Int) {
        guard messages.indices.contains(index) else { return }
        let cutoff = messages[index].createdAt
        messages.removeSubrange(index...)

        if let session, let modelContext {
            for stored in session.messages where stored.createdAt >= cutoff {
                modelContext.delete(stored)
            }
            try? modelContext.save()
        }
    }

    /// Lanza la generación de una respuesta a partir de la conversación
    /// actual, cuyo último mensaje debe ser del usuario.
    private func generate(model: String) {
        let prompt = messages.last(where: { $0.role == .user })?.content ?? ""

        // El contexto RAG se envía a la API pero no se guarda ni se pinta.
        var history = messages
        isGenerating = true

        generationTask = Task {
            // Instrucciones de sistema definidas por el usuario en Ajustes.
            let systemPrompt = AppSettings.systemPrompt
            if !systemPrompt.isEmpty {
                history.insert(ChatMessage(role: .system, content: systemPrompt), at: 0)
            }

            // Sin texto no hay consulta que buscar (p. ej. solo una imagen).
            if useLibrary, !prompt.isEmpty, let contextMessage = await libraryContextMessage(for: prompt) {
                history.insert(contextMessage, at: max(0, history.count - 1))
            }

            var usedWeb = false
            if isWebSearchEnabled, !prompt.isEmpty, let webMessage = await webContextMessage(for: prompt) {
                history.insert(webMessage, at: max(0, history.count - 1))
                usedWeb = true
            }

            // Mensaje vacío del asistente que se rellena token a token.
            var assistantMessage = ChatMessage(role: .assistant, content: "", usedWeb: usedWeb)
            messages.append(assistantMessage)
            let assistantIndex = messages.count - 1

            do {
                let stream = try await service.streamChat(model: model, messages: history)
                for try await event in stream {
                    switch event {
                    case .token(let fragment):
                        assistantMessage.content += fragment
                    case .completed(let metrics):
                        assistantMessage.metrics = metrics
                    }
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

    // MARK: - Búsqueda web opcional

    /// Busca la pregunta en la web y la convierte en un mensaje de sistema
    /// con los resultados y sus fuentes. De las dos primeras páginas se
    /// descarga el contenido completo (no solo el resumen del buscador);
    /// del resto se usa el resumen. Devuelve `nil` si no hay resultados o
    /// falla la conexión (la generación continúa solo con contexto local).
    private func webContextMessage(for query: String) async -> ChatMessage? {
        guard let results = try? await webSearch.search(query), !results.isEmpty else {
            return nil
        }

        // Lectura en paralelo del contenido de las páginas principales.
        let pagesToRead = 2
        let pageTexts: [Int: String] = await withTaskGroup(of: (Int, String?).self) { group in
            for (index, result) in results.prefix(pagesToRead).enumerated() {
                let webSearch = self.webSearch
                group.addTask {
                    (index, await webSearch.fetchPageText(from: result.url))
                }
            }
            var texts: [Int: String] = [:]
            for await (index, text) in group {
                if let text { texts[index] = text }
            }
            return texts
        }

        var prompt = """
        Resultados de una búsqueda web reciente sobre la pregunta del usuario. \
        Úsalos si son relevantes y cita siempre la fuente con su URL. Si no \
        bastan para responder con seguridad, indícalo.

        """
        for (index, result) in results.enumerated() {
            let body = pageTexts[index] ?? result.snippet
            prompt += "\n--- \(result.title) (\(result.url.absoluteString)) ---\n\(body)\n"
        }
        return ChatMessage(role: .system, content: prompt)
    }

    // MARK: - Persistencia

    private func persist(_ message: ChatMessage) {
        guard let session, let modelContext else { return }
        let stored = StoredMessage(
            role: message.role,
            content: message.content,
            createdAt: message.createdAt,
            usedWeb: message.usedWeb,
            imageData: message.imageData,
            metrics: message.metrics
        )
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
