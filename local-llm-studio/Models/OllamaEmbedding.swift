//
//  OllamaEmbedding.swift
//  local-llm-studio
//
//  Contrato JSON del endpoint local de embeddings de Ollama (/api/embed).
//

import Foundation

/// Cuerpo de la petición de embeddings.
struct OllamaEmbedRequest: Encodable {
    let model: String
    let input: [String]
}

/// Respuesta con un embedding por cada texto de entrada.
struct OllamaEmbedResponse: Decodable {
    let embeddings: [[Double]]
}
