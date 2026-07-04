//
//  OllamaModel.swift
//  local-llm-studio
//
//  Modelos de dominio para la API local de Ollama (localhost:11434).
//  Espejo del contrato JSON del endpoint GET /api/tags.
//

import Foundation

/// Respuesta del endpoint `GET /api/tags` de Ollama.
struct OllamaTagsResponse: Decodable {
    let models: [OllamaModel]
}

/// Un modelo de lenguaje instalado localmente en el Mac a través de Ollama.
struct OllamaModel: Decodable, Identifiable, Hashable {
    /// Nombre completo con tag, p. ej. "llama3.2:latest". Es único en Ollama.
    let name: String
    /// Fecha de última modificación del modelo en disco.
    let modifiedAt: Date
    /// Tamaño en bytes que ocupa el modelo en disco.
    let size: Int64
    /// Digest SHA del modelo.
    let digest: String
    /// Detalles técnicos del modelo (familia, parámetros, cuantización...).
    let details: Details

    var id: String { digest }

    struct Details: Decodable, Hashable {
        let format: String?
        let family: String?
        let parameterSize: String?
        let quantizationLevel: String?

        enum CodingKeys: String, CodingKey {
            case format
            case family
            case parameterSize = "parameter_size"
            case quantizationLevel = "quantization_level"
        }
    }

    enum CodingKeys: String, CodingKey {
        case name
        case modifiedAt = "modified_at"
        case size
        case digest
        case details
    }
}

extension OllamaModel {
    /// Tamaño legible para la UI, p. ej. "4,7 GB".
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

/// Cuerpo de la petición `DELETE /api/delete` de Ollama.
struct OllamaDeleteRequest: Encodable {
    let model: String
}
