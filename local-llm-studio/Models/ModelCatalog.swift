//
//  ModelCatalog.swift
//  local-llm-studio
//
//  Catálogo curado de los modelos locales más relevantes, descargables
//  con un clic desde la app (Ollama gestiona la descarga vía /api/pull).
//

import Foundation

/// Una entrada del catálogo integrado de modelos.
struct CatalogEntry: Identifiable, Hashable {
    /// Tag de Ollama con el que se descarga, p. ej. "llama3.2".
    let tag: String
    let displayName: String
    let vendor: String
    /// Descripción corta orientada al usuario, en español.
    let summary: String
    /// Tamaño aproximado de la descarga, para decidir antes de pulsar.
    let approximateSize: String

    var id: String { tag }

    /// `true` si alguno de los modelos instalados corresponde a esta entrada.
    func isInstalled(among installed: [OllamaModel]) -> Bool {
        installed.contains { $0.name == tag || $0.name.hasPrefix(tag + ":") }
    }
}

extension CatalogEntry {
    /// Selección curada de los modelos más importantes del ecosistema Ollama.
    static let curated: [CatalogEntry] = [
        CatalogEntry(
            tag: "llama3.2",
            displayName: "Llama 3.2",
            vendor: "Meta",
            summary: "Modelo ligero y equilibrado, ideal para chat general en Macs con poca RAM.",
            approximateSize: "2 GB"
        ),
        CatalogEntry(
            tag: "llama3.1:8b",
            displayName: "Llama 3.1 8B",
            vendor: "Meta",
            summary: "Más capaz que 3.2 en razonamiento y contexto largo. Buen todoterreno.",
            approximateSize: "4,9 GB"
        ),
        CatalogEntry(
            tag: "deepseek-r1:8b",
            displayName: "DeepSeek-R1 8B",
            vendor: "DeepSeek",
            summary: "Especializado en razonamiento paso a paso (matemáticas, lógica, código).",
            approximateSize: "5,2 GB"
        ),
        CatalogEntry(
            tag: "mistral",
            displayName: "Mistral 7B",
            vendor: "Mistral AI",
            summary: "Rápido y eficiente, un clásico para tareas generales y resumen.",
            approximateSize: "4,1 GB"
        ),
        CatalogEntry(
            tag: "gemma3",
            displayName: "Gemma 3",
            vendor: "Google",
            summary: "Última generación de Google, muy buen rendimiento por parámetro.",
            approximateSize: "3,3 GB"
        ),
        CatalogEntry(
            tag: "qwen3:8b",
            displayName: "Qwen 3 8B",
            vendor: "Alibaba",
            summary: "Excelente en multilingüe (incluido español) y en programación.",
            approximateSize: "5,2 GB"
        ),
        CatalogEntry(
            tag: "phi4",
            displayName: "Phi-4 14B",
            vendor: "Microsoft",
            summary: "Modelo compacto de alta calidad para razonamiento. Requiere 16 GB de RAM.",
            approximateSize: "9,1 GB"
        ),
        CatalogEntry(
            tag: "llava",
            displayName: "LLaVA 7B",
            vendor: "Comunidad",
            summary: "Modelo con visión: entiende imágenes además de texto.",
            approximateSize: "4,7 GB"
        ),
        CatalogEntry(
            tag: "nomic-embed-text",
            displayName: "Nomic Embed Text",
            vendor: "Nomic AI",
            summary: "Modelo de embeddings para la biblioteca RAG local (Fase 3). No es de chat.",
            approximateSize: "274 MB"
        )
    ]
}

// MARK: - Contrato JSON de POST /api/pull

/// Cuerpo de la petición de descarga de un modelo.
struct OllamaPullRequest: Encodable {
    let model: String
    let stream: Bool
}

/// Un fragmento (línea NDJSON) del progreso de descarga que emite Ollama.
struct OllamaPullChunk: Decodable {
    /// Estado textual: "pulling manifest", "pulling <digest>", "success"...
    let status: String?
    /// Bytes totales de la capa en descarga.
    let total: Int64?
    /// Bytes ya descargados de la capa.
    let completed: Int64?
    /// Mensaje de error del servidor, si la descarga falla.
    let error: String?
}

/// Progreso agregado de una descarga, listo para pintar en la UI.
struct PullProgress: Equatable {
    let status: String
    /// Fracción 0...1, o `nil` si la fase actual no informa de tamaño.
    let fraction: Double?
}
