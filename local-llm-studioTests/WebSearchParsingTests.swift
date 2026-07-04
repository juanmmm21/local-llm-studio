//
//  WebSearchParsingTests.swift
//  local-llm-studioTests
//
//  Tests del parsing nativo del HTML de DuckDuckGo y de la limpieza
//  de páginas web. Todo offline: se usan documentos HTML de ejemplo.
//

import XCTest
@testable import local_llm_studio

final class WebSearchParsingTests: XCTestCase {

    // MARK: - Resultados de búsqueda

    private let sampleHTML = """
    <div class="result">
      <a class="result__a" href="https://ejemplo.com/articulo">Título del <b>artículo</b></a>
      <a class="result__snippet" href="#">Resumen del artículo con &amp; entidades.</a>
    </div>
    <div class="result">
      <a class="result__a" href="//duckduckgo.com/l/?uddg=https%3A%2F%2Fotro.com%2Fpagina&amp;rut=abc">Otro resultado</a>
      <a class="result__snippet" href="#">Segundo resumen.</a>
    </div>
    """

    func testParsesTitlesURLsAndSnippets() {
        let results = WebSearchService.parseResults(from: sampleHTML, limit: 4)

        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].title, "Título del artículo")
        XCTAssertEqual(results[0].url.absoluteString, "https://ejemplo.com/articulo")
        XCTAssertEqual(results[0].snippet, "Resumen del artículo con & entidades.")
    }

    func testResolvesDuckDuckGoRedirectLinks() {
        let results = WebSearchService.parseResults(from: sampleHTML, limit: 4)

        XCTAssertEqual(results[1].url.absoluteString, "https://otro.com/pagina")
    }

    func testrespectsResultLimit() {
        let results = WebSearchService.parseResults(from: sampleHTML, limit: 1)

        XCTAssertEqual(results.count, 1)
    }

    func testEmptyHTMLProducesNoResults() {
        XCTAssertTrue(WebSearchService.parseResults(from: "<html></html>", limit: 4).isEmpty)
    }

    // MARK: - Limpieza de páginas

    func testReadableTextRemovesScriptsAndTags() {
        let body = String(repeating: "Contenido visible de la página. ", count: 20)
        let html = """
        <html><head><title>x</title></head><body>
        <script>alert('fuera');</script>
        <style>.a { color: red }</style>
        <p>\(body)</p>
        </body></html>
        """

        let text = WebSearchService.readableText(fromHTML: html, maxLength: 5000)

        XCTAssertNotNil(text)
        XCTAssertFalse(text!.contains("alert"))
        XCTAssertFalse(text!.contains("color: red"))
        XCTAssertTrue(text!.contains("Contenido visible"))
    }

    func testReadableTextReturnsNilForNearlyEmptyPages() {
        let text = WebSearchService.readableText(fromHTML: "<html><body>poco</body></html>", maxLength: 5000)

        XCTAssertNil(text, "Una página casi vacía debe descartarse para usar el resumen del buscador")
    }

    func testReadableTextIsTruncatedToMaxLength() {
        let html = "<p>" + String(repeating: "texto largo ", count: 500) + "</p>"

        let text = WebSearchService.readableText(fromHTML: html, maxLength: 300)

        XCTAssertNotNil(text)
        XCTAssertLessThanOrEqual(text!.count, 300)
    }
}
