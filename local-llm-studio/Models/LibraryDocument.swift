//
//  LibraryDocument.swift
//  local-llm-studio
//
//  Biblioteca de documentos local para el RAG privado. Se guardan
//  referencias (bookmarks) a los archivos del usuario, nunca copias,
//  junto a los fragmentos de texto indexados y sus embeddings.
//

import Foundation
import SwiftData

@Model
final class LibraryDocument {
    var name: String
    var fileExtension: String
    var addedAt: Date
    /// Bookmark con ámbito de seguridad para poder releer el archivo
    /// original más adelante sin duplicarlo en disco.
    var bookmarkData: Data
    /// `true` cuando todos los fragmentos tienen embedding semántico.
    var isIndexed: Bool

    @Relationship(deleteRule: .cascade, inverse: \DocumentChunk.document)
    var chunks: [DocumentChunk] = []

    init(name: String, fileExtension: String, bookmarkData: Data) {
        self.name = name
        self.fileExtension = fileExtension
        self.addedAt = .now
        self.bookmarkData = bookmarkData
        self.isIndexed = false
    }
}

@Model
final class DocumentChunk {
    /// Posición del fragmento dentro del documento original.
    var index: Int
    var text: String
    /// Embedding semántico local (nomic-embed-text). `nil` si aún no se
    /// ha indexado; en ese caso la recuperación usa palabras clave.
    var embedding: [Double]?
    var document: LibraryDocument?

    init(index: Int, text: String, embedding: [Double]? = nil) {
        self.index = index
        self.text = text
        self.embedding = embedding
    }
}
