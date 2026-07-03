//
//  ContextRetriever.swift
//  local-llm-studio
//
//  Recuperación local de los fragmentos más relevantes de la biblioteca
//  para inyectarlos en el prompt del modelo (RAG privado). Usa similitud
//  de coseno cuando hay embeddings y palabras clave como respaldo.
//

import Foundation

enum ContextRetriever {

    /// Número de fragmentos que se inyectan como máximo en el prompt.
    static let defaultLimit = 4

    /// Devuelve los fragmentos más relevantes para la consulta, ordenados
    /// de mayor a menor afinidad. Fragmentos sin relación quedan fuera.
    static func topChunks(
        for query: String,
        among chunks: [DocumentChunk],
        queryEmbedding: [Double]?,
        limit: Int = defaultLimit
    ) -> [DocumentChunk] {
        let scored: [(chunk: DocumentChunk, score: Double)]

        if let queryEmbedding {
            scored = chunks.compactMap { chunk in
                guard let embedding = chunk.embedding else { return nil }
                return (chunk, cosineSimilarity(queryEmbedding, embedding))
            }
            // 0.35 descarta fragmentos semánticamente ajenos a la pregunta.
            return Array(scored.filter { $0.score > 0.35 }.sorted { $0.score > $1.score }.prefix(limit)).map(\.chunk)
        }

        // Respaldo sin embeddings: solapamiento de palabras significativas.
        let queryWords = significantWords(in: query)
        guard !queryWords.isEmpty else { return [] }

        scored = chunks.map { chunk in
            let chunkWords = significantWords(in: chunk.text)
            let overlap = queryWords.intersection(chunkWords).count
            return (chunk, Double(overlap))
        }
        return Array(scored.filter { $0.score > 0 }.sorted { $0.score > $1.score }.prefix(limit)).map(\.chunk)
    }

    /// Construye el mensaje de sistema con el contexto recuperado,
    /// citando el documento de origen de cada fragmento.
    static func contextPrompt(for chunks: [DocumentChunk]) -> String {
        var prompt = """
        Contexto extraído de la biblioteca local del usuario. Úsalo para responder \
        cuando sea relevante y cita el documento de origen. Si el contexto no \
        responde a la pregunta, dilo con claridad.

        """
        for chunk in chunks {
            let source = chunk.document?.name ?? "Documento"
            prompt += "\n--- [\(source)] ---\n\(chunk.text)\n"
        }
        return prompt
    }

    // MARK: - Puntuación

    static func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dot = 0.0, normA = 0.0, normB = 0.0
        for i in a.indices {
            dot += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }
        let denominator = (normA * normB).squareRoot()
        return denominator > 0 ? dot / denominator : 0
    }

    private static func significantWords(in text: String) -> Set<String> {
        Set(
            text.lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { $0.count > 3 }
        )
    }
}
