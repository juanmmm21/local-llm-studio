//
//  ContextRetrieverTests.swift
//  local-llm-studioTests
//
//  Tests de la recuperación de contexto RAG: similitud de coseno y
//  selección de fragmentos por embeddings o por palabras clave.
//

import SwiftData
import XCTest
@testable import local_llm_studio

final class ContextRetrieverTests: XCTestCase {

    // MARK: - Similitud de coseno

    func testCosineSimilarityOfIdenticalVectorsIsOne() {
        XCTAssertEqual(ContextRetriever.cosineSimilarity([1, 2, 3], [1, 2, 3]), 1.0, accuracy: 1e-9)
    }

    func testCosineSimilarityOfOrthogonalVectorsIsZero() {
        XCTAssertEqual(ContextRetriever.cosineSimilarity([1, 0], [0, 1]), 0.0, accuracy: 1e-9)
    }

    func testCosineSimilarityOfOppositeVectorsIsMinusOne() {
        XCTAssertEqual(ContextRetriever.cosineSimilarity([1, 1], [-1, -1]), -1.0, accuracy: 1e-9)
    }

    func testCosineSimilarityWithMismatchedDimensionsIsZero() {
        XCTAssertEqual(ContextRetriever.cosineSimilarity([1, 2], [1, 2, 3]), 0.0)
        XCTAssertEqual(ContextRetriever.cosineSimilarity([], []), 0.0)
    }

    // MARK: - Selección de fragmentos

    /// Contenedor en memoria: los fragmentos de prueba nunca tocan disco.
    private func makeContext() throws -> ModelContext {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: LibraryDocument.self, WatchedFolder.self,
            configurations: configuration
        )
        return ModelContext(container)
    }

    func testTopChunksPrefersSemanticallyCloserEmbedding() throws {
        let context = try makeContext()
        let near = DocumentChunk(index: 0, text: "sobre gatos", embedding: [0.9, 0.1])
        let far = DocumentChunk(index: 1, text: "sobre impuestos", embedding: [0.1, 0.9])
        context.insert(near)
        context.insert(far)

        let result = ContextRetriever.topChunks(
            for: "gatos",
            among: [far, near],
            queryEmbedding: [1.0, 0.0],
            limit: 1
        )

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.text, "sobre gatos")
    }

    func testTopChunksDiscardsUnrelatedEmbeddings() throws {
        let context = try makeContext()
        let unrelated = DocumentChunk(index: 0, text: "nada que ver", embedding: [-1.0, 0.0])
        context.insert(unrelated)

        let result = ContextRetriever.topChunks(
            for: "consulta",
            among: [unrelated],
            queryEmbedding: [1.0, 0.0]
        )

        XCTAssertTrue(result.isEmpty, "Un fragmento semánticamente opuesto debe quedar fuera")
    }

    func testTopChunksFallsBackToKeywordOverlap() throws {
        let context = try makeContext()
        let relevant = DocumentChunk(index: 0, text: "La fotosíntesis convierte la luz en energía química")
        let irrelevant = DocumentChunk(index: 1, text: "El mercado bursátil cerró con pérdidas")
        context.insert(relevant)
        context.insert(irrelevant)

        let result = ContextRetriever.topChunks(
            for: "¿Qué es la fotosíntesis y la energía que produce?",
            among: [irrelevant, relevant],
            queryEmbedding: nil
        )

        XCTAssertEqual(result.first?.text, relevant.text)
        XCTAssertFalse(result.contains { $0.text == irrelevant.text })
    }

    func testContextPromptCitesDocumentName() throws {
        let context = try makeContext()
        let document = LibraryDocument(name: "manual.pdf", fileExtension: "pdf", bookmarkData: Data())
        let chunk = DocumentChunk(index: 0, text: "Contenido del manual")
        context.insert(document)
        chunk.document = document
        context.insert(chunk)

        let prompt = ContextRetriever.contextPrompt(for: [chunk])

        XCTAssertTrue(prompt.contains("[manual.pdf]"))
        XCTAssertTrue(prompt.contains("Contenido del manual"))
    }
}
