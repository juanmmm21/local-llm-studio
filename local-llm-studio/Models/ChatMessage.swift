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

    init(
        id: UUID = UUID(),
        role: ChatRole,
        content: String,
        createdAt: Date = .now,
        usedWeb: Bool = false,
        imageData: Data? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
        self.usedWeb = usedWeb
        self.imageData = imageData
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

    struct Message: Decodable {
        let role: String
        let content: String
    }
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
