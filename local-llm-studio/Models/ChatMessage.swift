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

    init(id: UUID = UUID(), role: ChatRole, content: String, createdAt: Date = .now) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }
}

// MARK: - Contrato JSON de POST /api/chat

/// Cuerpo de la petición de chat a Ollama.
struct OllamaChatRequest: Encodable {
    let model: String
    let messages: [Message]
    let stream: Bool

    struct Message: Codable {
        let role: String
        let content: String
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
        OllamaChatRequest.Message(role: role.rawValue, content: content)
    }
}
