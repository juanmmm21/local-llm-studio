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

    /// Documento leído en memoria durante la fase síncrona de importación.
    private struct StagedDocument {
        let name: String
        let fileExtension: String
        let bookmark: Data
        let data: Data
    }

    /// Importa documentos seleccionados por el usuario. La lectura de los
    /// bytes ocurre AQUÍ, de forma síncrona y dentro del ámbito de
    /// seguridad del sandbox: el permiso que concede el selector de
    /// archivos es efímero y no sobrevive de forma fiable a un salto
    /// asíncrono ("Operation not permitted" al leer más tarde).
    func importDocuments(at urls: [URL], context: ModelContext) {
        notices = []
        var staged: [StagedDocument] = []

        for url in urls {
            let accessGranted = url.startAccessingSecurityScopedResource()
            defer {
                if accessGranted { url.stopAccessingSecurityScopedResource() }
            }

            guard let data = try? Data(contentsOf: url) else {
                notices.append("\(url.lastPathComponent): macOS denegó la lectura del archivo.")
                continue
            }

            // El bookmark con ámbito de seguridad permite releerlo en el
            // futuro; si no se puede crear, uno mínimo sirve de referencia.
            let bookmark = (try? url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )) ?? (try? url.bookmarkData()) ?? Data()

            staged.append(StagedDocument(
                name: url.lastPathComponent,
                fileExtension: url.pathExtension.lowercased(),
                bookmark: bookmark,
                data: data
            ))
        }

        guard !staged.isEmpty else { return }
        Task { await index(staged, context: context) }
    }

    /// Fase asíncrona: extracción, chunking y embeddings sobre los bytes
    /// ya leídos, sin volver a tocar los archivos originales.
    private func index(_ staged: [StagedDocument], context: ModelContext) async {
        isIndexing = true
        var embeddingUnavailable = false

        for item in staged {
            do {
                let text = try DocumentIndexer.extractText(
                    from: item.data,
                    fileExtension: item.fileExtension,
                    name: item.name
                )

                let document = LibraryDocument(
                    name: item.name,
                    fileExtension: item.fileExtension,
                    bookmarkData: item.bookmark
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
