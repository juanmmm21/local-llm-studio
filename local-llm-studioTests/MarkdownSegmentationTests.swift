//
//  MarkdownSegmentationTests.swift
//  local-llm-studioTests
//
//  Tests del parser que separa las respuestas del modelo en texto y
//  bloques de código delimitados por vallas ```.
//

import XCTest
@testable import local_llm_studio

final class MarkdownSegmentationTests: XCTestCase {

    func testPlainTextProducesSingleTextSegment() {
        let segments = MessageContentView.segments(from: "Hola, ¿qué tal?")

        XCTAssertEqual(segments.count, 1)
        guard case .text(let text) = segments[0].kind else {
            return XCTFail("Se esperaba un segmento de texto")
        }
        XCTAssertEqual(text, "Hola, ¿qué tal?")
    }

    func testCodeBlockWithLanguageIsExtracted() {
        let content = """
        Antes del código.

        ```swift
        let x = 1
        ```

        Después del código.
        """
        let segments = MessageContentView.segments(from: content)

        XCTAssertEqual(segments.count, 3)
        guard case .code(let language, let code) = segments[1].kind else {
            return XCTFail("Se esperaba un bloque de código en el medio")
        }
        XCTAssertEqual(language, "swift")
        XCTAssertEqual(code, "let x = 1")
    }

    func testCodeBlockWithoutLanguageHasNilLanguage() {
        let segments = MessageContentView.segments(from: "```\nabc\n```")

        XCTAssertEqual(segments.count, 1)
        guard case .code(let language, let code) = segments[0].kind else {
            return XCTFail("Se esperaba un bloque de código")
        }
        XCTAssertNil(language)
        XCTAssertEqual(code, "abc")
    }

    func testUnclosedFenceIsTreatedAsCodeDuringStreaming() {
        // Mientras el modelo aún está escribiendo, la valla de cierre no
        // ha llegado: el contenido debe pintarse ya como código.
        let segments = MessageContentView.segments(from: "Mira:\n```python\nprint(1)")

        XCTAssertEqual(segments.count, 2)
        guard case .code(let language, let code) = segments[1].kind else {
            return XCTFail("Se esperaba un bloque de código sin cerrar")
        }
        XCTAssertEqual(language, "python")
        XCTAssertEqual(code, "print(1)")
    }

    func testEmptyCodeBlockIsDiscarded() {
        let segments = MessageContentView.segments(from: "Texto\n```\n\n```")

        XCTAssertEqual(segments.count, 1)
        guard case .text = segments[0].kind else {
            return XCTFail("Un bloque de código vacío no debe generar segmento")
        }
    }

    func testMultipleCodeBlocks() {
        let content = "```js\na\n```\ntexto\n```rust\nb\n```"
        let segments = MessageContentView.segments(from: content)

        XCTAssertEqual(segments.count, 3)
        guard case .code(let first, _) = segments[0].kind,
              case .text = segments[1].kind,
              case .code(let second, _) = segments[2].kind else {
            return XCTFail("Se esperaban código, texto y código")
        }
        XCTAssertEqual(first, "js")
        XCTAssertEqual(second, "rust")
    }
}
