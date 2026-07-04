//
//  ChatTitleSanitizerTests.swift
//  local-llm-studioTests
//
//  Tests del saneado de los títulos automáticos que devuelve el modelo.
//

import XCTest
@testable import local_llm_studio

@MainActor
final class ChatTitleSanitizerTests: XCTestCase {

    func testTrimsQuotesAndPunctuation() {
        XCTAssertEqual(ChatViewModel.sanitizeTitle("\"Receta de tortilla\"."), "Receta de tortilla")
        XCTAssertEqual(ChatViewModel.sanitizeTitle("«Dudas de SwiftUI»"), "Dudas de SwiftUI")
    }

    func testRemovesThinkingBlocksFromReasoningModels() {
        let raw = "<think>El usuario pregunta por gatos, resumiré eso.</think>\nCuidados de gatos"

        XCTAssertEqual(ChatViewModel.sanitizeTitle(raw), "Cuidados de gatos")
    }

    func testUsesFirstNonEmptyLine() {
        XCTAssertEqual(ChatViewModel.sanitizeTitle("\n\nViaje a Japón\nCon detalles extra"), "Viaje a Japón")
    }

    func testTruncatesVeryLongTitles() {
        let raw = String(repeating: "palabra ", count: 30)

        XCTAssertLessThanOrEqual(ChatViewModel.sanitizeTitle(raw).count, 60)
    }

    func testEmptyResponseProducesEmptyTitle() {
        XCTAssertEqual(ChatViewModel.sanitizeTitle("  \n "), "")
        XCTAssertEqual(ChatViewModel.sanitizeTitle("<think>solo razonamiento</think>"), "")
    }
}
