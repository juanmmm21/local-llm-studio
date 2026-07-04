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

/// Respuesta del endpoint `GET /api/ps`: modelos cargados en memoria.
struct OllamaPSResponse: Decodable {
    let models: [OllamaRunningModel]
}

/// Un modelo actualmente cargado en la RAM/VRAM del Mac.
struct OllamaRunningModel: Decodable, Identifiable, Hashable {
    let name: String
    /// Memoria total que ocupa el modelo cargado, en bytes.
    let size: Int64
    /// Parte del modelo alojada en la memoria de la GPU, en bytes.
    let sizeVRAM: Int64?
    /// Momento en el que Ollama lo descargará de memoria si no se usa.
    let expiresAt: Date?

    var id: String { name }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .memory)
    }

    enum CodingKeys: String, CodingKey {
        case name
        case size
        case sizeVRAM = "size_vram"
        case expiresAt = "expires_at"
    }
}

/// Cuerpo de `POST /api/generate` usado solo para descargar un modelo de
/// la memoria: `keep_alive: 0` hace que Ollama lo libere de inmediato.
struct OllamaUnloadRequest: Encodable {
    let model: String
    let keepAlive: Int = 0

    enum CodingKeys: String, CodingKey {
        case model
        case keepAlive = "keep_alive"
    }
}
