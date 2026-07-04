//
//  DocumentIndexerTests.swift
//  local-llm-studioTests
//
//  Tests de la extracción de texto y del chunking de documentos
//  para la biblioteca RAG.
//

import XCTest
@testable import local_llm_studio

final class DocumentIndexerTests: XCTestCase {

    // MARK: - Extracción de texto

    func testExtractsPlainTextFromMarkdownData() throws {
        let data = Data("# Título\n\nContenido del documento.".utf8)

        let text = try DocumentIndexer.extractText(from: data, fileExtension: "md", name: "notas.md")

        XCTAssertEqual(text, "# Título\n\nContenido del documento.")
    }

    func testUnsupportedExtensionThrows() {
        XCTAssertThrowsError(
            try DocumentIndexer.extractText(from: Data(), fileExtension: "docx", name: "a.docx")
        ) { error in
            guard case DocumentIndexerError.unsupportedType = error else {
                return XCTFail("Se esperaba unsupportedType, llegó \(error)")
            }
        }
    }

    func testEmptyDocumentThrows() {
        XCTAssertThrowsError(
            try DocumentIndexer.extractText(from: Data("   \n\n  ".utf8), fileExtension: "txt", name: "vacio.txt")
        ) { error in
            guard case DocumentIndexerError.emptyDocument = error else {
                return XCTFail("Se esperaba emptyDocument, llegó \(error)")
            }
        }
    }

    // MARK: - Chunking

    func testShortTextProducesSingleChunk() {
        let chunks = DocumentIndexer.chunk("Un párrafo corto.")

        XCTAssertEqual(chunks, ["Un párrafo corto."])
    }

    func testLongTextIsSplitIntoMultipleChunks() {
        let paragraph = String(repeating: "palabra ", count: 60).trimmingCharacters(in: .whitespaces)
        let text = Array(repeating: paragraph, count: 8).joined(separator: "\n\n")

        let chunks = DocumentIndexer.chunk(text, targetSize: 1200)

        XCTAssertGreaterThan(chunks.count, 1)
        // Ningún fragmento debe quedar desproporcionadamente grande:
        // como mucho el objetivo más un párrafo de solapamiento.
        for chunk in chunks {
            XCTAssertLessThanOrEqual(chunk.count, 1200 + paragraph.count + 2)
        }
    }

    func testConsecutiveChunksOverlapByOneParagraph() {
        let paragraphs = (1...6).map { index in
            "Párrafo \(index): " + String(repeating: "texto ", count: 50)
        }
        let chunks = DocumentIndexer.chunk(paragraphs.joined(separator: "\n\n"), targetSize: 600)

        XCTAssertGreaterThan(chunks.count, 1)
        for index in 1..<chunks.count {
            let previousLastParagraph = chunks[index - 1]
                .components(separatedBy: "\n\n")
                .last ?? ""
            XCTAssertTrue(
                chunks[index].hasPrefix(previousLastParagraph),
                "El fragmento \(index) debe empezar con el último párrafo del anterior"
            )
        }
    }

    func testOversizedParagraphIsSplitBySentences() {
        let sentence = "Esta es una frase de prueba que ocupa espacio. "
        let hugeParagraph = String(repeating: sentence, count: 60)

        let chunks = DocumentIndexer.chunk(hugeParagraph, targetSize: 500)

        XCTAssertGreaterThan(chunks.count, 1, "Un párrafo enorme debe partirse en varios fragmentos")
    }
}
