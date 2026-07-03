//
//  LibraryView.swift
//  local-llm-studio
//
//  Biblioteca de documentos para el RAG privado: añadir archivos locales
//  (Markdown, TXT, PDF), ver su estado de indexación y eliminarlos.
//

import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @Bindable var viewModel: LibraryViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \LibraryDocument.addedAt, order: .reverse) private var documents: [LibraryDocument]

    @State private var isImporterPresented = false

    private static let importTypes: [UTType] = [
        .pdf, .plainText, UTType(filenameExtension: "md") ?? .plainText
    ]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(minWidth: 520, minHeight: 420)
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: Self.importTypes,
            allowsMultipleSelection: true
        ) { result in
            guard case .success(let urls) = result else { return }
            // Lectura inmediata y síncrona: el permiso del sandbox sobre
            // estas URLs no sobrevive de forma fiable a un salto asíncrono.
            viewModel.importDocuments(at: urls, context: modelContext)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Biblioteca local")
                    .font(.title2.bold())
                Text("Tus documentos se indexan en tu Mac y nunca salen de él. El asistente los usará como contexto.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                isImporterPresented = true
            } label: {
                Label("Añadir documentos", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isIndexing)
        }
        .padding()
    }

    @ViewBuilder
    private var content: some View {
        if documents.isEmpty {
            ContentUnavailableView {
                Label("Biblioteca vacía", systemImage: "books.vertical")
            } description: {
                Text("Añade archivos Markdown, TXT o PDF para que el asistente pueda consultarlos.")
            } actions: {
                Button("Añadir documentos") { isImporterPresented = true }
                    .buttonStyle(.borderedProminent)
            }
            .frame(maxHeight: .infinity)
        } else {
            List(documents) { document in
                HStack(spacing: 12) {
                    Image(systemName: icon(for: document))
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(document.name)
                            .font(.headline)
                        Text("\(document.chunks.count) fragmentos · añadido \(document.addedAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if document.isIndexed {
                        Label("Indexado", systemImage: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                            .help("Búsqueda semántica activa")
                    } else {
                        Label("Palabras clave", systemImage: "textformat.abc")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .help("Sin embeddings: descarga Nomic Embed Text del catálogo y reindexa")
                    }

                    Button {
                        viewModel.delete(document, context: modelContext)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Eliminar de la biblioteca (no borra el archivo original)")
                }
                .padding(.vertical, 4)
            }
            .listStyle(.inset)
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            if viewModel.isIndexing {
                ProgressView()
                    .controlSize(.small)
                Text("Indexando documentos…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let notice = viewModel.notices.first {
                Label(notice, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .lineLimit(2)
            }

            Spacer()

            if documents.contains(where: { !$0.isIndexed }) {
                Button("Reindexar pendientes") {
                    Task { await viewModel.reindexPending(context: modelContext) }
                }
                .disabled(viewModel.isIndexing)
            }

            Button("Cerrar") { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
        .padding(12)
    }

    private func icon(for document: LibraryDocument) -> String {
        switch document.fileExtension {
        case "pdf": "doc.richtext"
        case "md", "markdown": "doc.text"
        default: "doc.plaintext"
        }
    }
}
