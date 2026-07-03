//
//  LibraryViewModel.swift
//  local-llm-studio
//
//  Estado observable de la biblioteca RAG: alta de documentos locales,
//  indexación con embeddings y borrado. Los archivos nunca se copian;
//  se guardan bookmarks con ámbito de seguridad.
//

import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class LibraryViewModel {

    /// `true` mientras se extrae texto o se calculan embeddings.
    private(set) var isIndexing = false

    /// Errores y avisos de la última operación, aptos para la UI.
    private(set) var notices: [String] = []

    private let service: OllamaService

    init(service: OllamaService = OllamaService()) {
        self.service = service
    }

    /// Añade y procesa documentos seleccionados por el usuario:
    /// bookmark → extracción → chunking → embeddings (si hay modelo).
    func addDocuments(at urls: [URL], context: ModelContext) async {
        isIndexing = true
        notices = []
        var embeddingUnavailable = false

        for url in urls {
            let accessGranted = url.startAccessingSecurityScopedResource()
            defer {
                if accessGranted { url.stopAccessingSecurityScopedResource() }
            }

            do {
                let text = try DocumentIndexer.extractText(from: url)
                let bookmark = try url.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )

                let document = LibraryDocument(
                    name: url.lastPathComponent,
                    fileExtension: url.pathExtension.lowercased(),
                    bookmarkData: bookmark
                )
                context.insert(document)

                let pieces = DocumentIndexer.chunk(text)
                for (index, piece) in pieces.enumerated() {
                    let chunk = DocumentChunk(index: index, text: piece)
                    chunk.document = document
                    context.insert(chunk)
                }

                // Embeddings locales; si el modelo no está, queda el respaldo
                // por palabras clave y se avisa una sola vez.
                do {
                    let embeddings = try await service.embed(texts: pieces)
                    let chunks = document.chunks.sorted { $0.index < $1.index }
                    for (index, chunk) in chunks.enumerated() where index < embeddings.count {
                        chunk.embedding = embeddings[index]
                    }
                    document.isIndexed = true
                } catch {
                    embeddingUnavailable = true
                }

                try context.save()
            } catch {
                notices.append(error.localizedDescription)
            }
        }

        if embeddingUnavailable {
            notices.append(
                "No se pudo indexar semánticamente: descarga «Nomic Embed Text» desde el catálogo. Mientras tanto se buscará por palabras clave."
            )
        }
        isIndexing = false
    }

    /// Reintenta los embeddings de los documentos aún sin indexar
    /// (p. ej. tras descargar el modelo de embeddings del catálogo).
    func reindexPending(context: ModelContext) async {
        let pending = (try? context.fetch(
            FetchDescriptor<LibraryDocument>(predicate: #Predicate { !$0.isIndexed })
        )) ?? []
        guard !pending.isEmpty else { return }

        isIndexing = true
        notices = []
        for document in pending {
            let chunks = document.chunks.sorted { $0.index < $1.index }
            do {
                let embeddings = try await service.embed(texts: chunks.map(\.text))
                for (index, chunk) in chunks.enumerated() where index < embeddings.count {
                    chunk.embedding = embeddings[index]
                }
                document.isIndexed = true
                try context.save()
            } catch {
                notices.append("No se pudo indexar «\(document.name)». ¿Está descargado Nomic Embed Text?")
                break
            }
        }
        isIndexing = false
    }

    func delete(_ document: LibraryDocument, context: ModelContext) {
        context.delete(document)
        try? context.save()
    }
}
