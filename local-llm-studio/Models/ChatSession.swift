//
//  ChatSession.swift
//  local-llm-studio
//
//  Persistencia local de conversaciones con SwiftData. Nada sale del Mac:
//  el historial vive en el contenedor de datos de la propia app.
//

import Foundation
import SwiftData

@Model
final class ChatSession {
    var title: String
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \StoredMessage.session)
    var messages: [StoredMessage] = []

    static let defaultTitle = "Nueva conversación"

    init(title: String = ChatSession.defaultTitle) {
        self.title = title
        self.createdAt = .now
        self.updatedAt = .now
    }

    /// Mensajes en orden cronológico (SwiftData no garantiza orden).
    var orderedMessages: [StoredMessage] {
        messages.sorted { $0.createdAt < $1.createdAt }
    }
}

@Model
final class StoredMessage {
    var roleRaw: String
    var content: String
    var createdAt: Date
    /// `true` si la respuesta usó contexto de una búsqueda web.
    var usedWeb: Bool = false
    /// Imagen adjunta, guardada fuera de la base de datos por tamaño.
    @Attribute(.externalStorage) var imageData: Data?
    /// Métricas de generación serializadas (JSON de GenerationMetrics).
    var metricsData: Data?
    var session: ChatSession?

    init(
        role: ChatRole,
        content: String,
        createdAt: Date = .now,
        usedWeb: Bool = false,
        imageData: Data? = nil,
        metrics: GenerationMetrics? = nil
    ) {
        self.roleRaw = role.rawValue
        self.content = content
        self.createdAt = createdAt
        self.usedWeb = usedWeb
        self.imageData = imageData
        self.metricsData = metrics.flatMap { try? JSONEncoder().encode($0) }
    }

    var role: ChatRole {
        ChatRole(rawValue: roleRaw) ?? .user
    }

    var metrics: GenerationMetrics? {
        metricsData.flatMap { try? JSONDecoder().decode(GenerationMetrics.self, from: $0) }
    }

    /// Conversión al mensaje en memoria que usa la UI y la API.
    var asChatMessage: ChatMessage {
        ChatMessage(
            role: role,
            content: content,
            createdAt: createdAt,
            usedWeb: usedWeb,
            imageData: imageData,
            metrics: metrics
        )
    }
}
