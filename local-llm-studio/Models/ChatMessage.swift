//
//  ChatMessage.swift
//  local-llm-studio
//
//  Modelos de dominio para el chat con la API local de Ollama
//  (POST /api/chat en modo streaming NDJSON).
//

import Foundation

/// Rol de un mensaje dentro de una conversación con el modelo local.
enum ChatRole: String, Codable {
    case system
    case user
    case assistant
}

/// Un mensaje de la conversación, tanto para la UI como para la API local.
struct ChatMessage: Identifiable, Hashable {
    let id: UUID
    let role: ChatRole
    var content: String
    let createdAt: Date
    /// `true` si la respuesta se generó con contexto de una búsqueda web.
    var usedWeb: Bool
    /// Imagen adjunta (PNG/JPEG) para modelos con visión como LLaVA.
    var imageData: Data?
    /// Estadísticas de la generación (solo respuestas del asistente).
    var metrics: GenerationMetrics?
    /// Fragmentos de la biblioteca usados como contexto en esta respuesta.
    var ragSources: [RAGSource]?

    init(
        id: UUID = UUID(),
        role: ChatRole,
        content: String,
        createdAt: Date = .now,
        usedWeb: Bool = false,
        imageData: Data? = nil,
        metrics: GenerationMetrics? = nil,
        ragSources: [RAGSource]? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
        self.usedWeb = usedWeb
        self.imageData = imageData
        self.metrics = metrics
        self.ragSources = ragSources
    }
}

// MARK: - Contrato JSON de POST /api/chat

/// Cuerpo de la petición de chat a Ollama.
struct OllamaChatRequest: Encodable {
    let model: String
    let messages: [Message]
    let stream: Bool
    let options: Options?

    /// Parámetros de generación configurables desde Ajustes.
    struct Options: Encodable {
        let temperature: Double?
        let numCtx: Int?

        enum CodingKeys: String, CodingKey {
            case temperature
            case numCtx = "num_ctx"
        }
    }

    struct Message: Codable {
        let role: String
        let content: String
        /// Imágenes en base64 para modelos con visión (LLaVA).
        let images: [String]?

        init(role: String, content: String, images: [String]? = nil) {
            self.role = role
            self.content = content
            self.images = images
        }
    }
}

/// Un fragmento (línea NDJSON) de la respuesta en streaming de Ollama.
struct OllamaChatChunk: Decodable {
    let message: Message?
    let done: Bool
    /// Tokens generados (solo en el fragmento final).
    let evalCount: Int?
    /// Duración de la generación en nanosegundos (solo en el final).
    let evalDuration: Int64?

    struct Message: Decodable {
        let role: String
        let content: String
    }

    enum CodingKeys: String, CodingKey {
        case message
        case done
        case evalCount = "eval_count"
        case evalDuration = "eval_duration"
    }
}

/// Fragmento de la biblioteca local que se inyectó como contexto en una
/// respuesta, para poder mostrar las fuentes al usuario.
struct RAGSource: Hashable, Codable, Sendable {
    let documentName: String
    let excerpt: String
}

/// Estadísticas de una generación completada, para mostrar en la UI.
struct GenerationMetrics: Hashable, Codable, Sendable {
    let modelName: String
    let tokenCount: Int
    let durationSeconds: Double

    var tokensPerSecond: Double {
        durationSeconds > 0 ? Double(tokenCount) / durationSeconds : 0
    }
}

/// Eventos del stream de chat: tokens de texto y las métricas finales.
enum ChatStreamEvent: Sendable {
    case token(String)
    case completed(GenerationMetrics?)
}

extension ChatMessage {
    /// Conversión al formato de mensaje que espera la API local.
    var asRequestMessage: OllamaChatRequest.Message {
        OllamaChatRequest.Message(
            role: role.rawValue,
            content: content,
            images: imageData.map { [$0.base64EncodedString()] }
        )
    }
}
