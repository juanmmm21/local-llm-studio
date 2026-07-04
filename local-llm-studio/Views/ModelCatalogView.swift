//
//  ModelCatalogView.swift
//  local-llm-studio
//
//  Catálogo integrado de modelos: descarga con un clic y progreso en
//  vivo, sin pasar por la consola.
//

import SwiftUI

struct ModelCatalogView: View {
    @Bindable var viewModel: ModelCatalogViewModel
    let installedModels: [OllamaModel]
    @Environment(\.dismiss) private var dismiss
    @State private var modelPendingDeletion: OllamaModel?

    /// Modelos instalados gestionables. El de embeddings queda fuera:
    /// la app lo necesita para la biblioteca y lo reinstalaría sola.
    private var manageableModels: [OllamaModel] {
        installedModels.filter { !$0.name.localizedCaseInsensitiveContains("embed") }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            List {
                if !manageableModels.isEmpty {
                    Section("Instalados en tu Mac") {
                        ForEach(manageableModels) { model in
                            installedRow(for: model)
                                .padding(.vertical, 4)
                        }
                    }
                }
                Section("Disponibles para descargar") {
                    ForEach(viewModel.entries) { entry in
                        CatalogRowView(
                            entry: entry,
                            state: viewModel.state(for: entry),
                            isInstalled: entry.isInstalled(among: installedModels),
                            onDownload: { viewModel.download(entry) },
                            onCancel: { viewModel.cancelDownload(of: entry) }
                        )
                        .padding(.vertical, 6)
                    }
                }
            }
            .listStyle(.inset)
            Divider()
            footer
        }
        .frame(minWidth: 520, minHeight: 460)
        .confirmationDialog(
            "¿Eliminar «\(modelPendingDeletion?.name ?? "")»?",
            isPresented: Binding(
                get: { modelPendingDeletion != nil },
                set: { if !$0 { modelPendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Eliminar y liberar \(modelPendingDeletion?.formattedSize ?? "")", role: .destructive) {
                if let model = modelPendingDeletion {
                    viewModel.delete(model)
                }
                modelPendingDeletion = nil
            }
            Button("Cancelar", role: .cancel) { modelPendingDeletion = nil }
        } message: {
            Text("Se borrará del disco. Podrás volver a descargarlo desde el catálogo cuando quieras.")
        }
    }

    private func installedRow(for model: OllamaModel) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.name)
                    .font(.headline)
                HStack(spacing: 10) {
                    if let parameters = model.details.parameterSize {
                        Label(parameters, systemImage: "slider.horizontal.3")
                    }
                    Label(model.formattedSize, systemImage: "internaldrive")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if viewModel.deletingModels.contains(model.name) {
                ProgressView()
                    .controlSize(.small)
            } else {
                Button {
                    modelPendingDeletion = model
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Eliminar este modelo del disco")
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Catálogo de modelos")
                .font(.title2.bold())
            Text("Los modelos se descargan una única vez a través de Ollama y después funcionan sin conexión.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }

    private var footer: some View {
        HStack {
            if let deletionError = viewModel.deletionError {
                Label(deletionError, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            } else if viewModel.hasActiveDownloads {
                Label("Puedes cerrar esta ventana; las descargas continúan.", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Cerrar") { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
        .padding(12)
    }
}

// MARK: - Fila del catálogo

private struct CatalogRowView: View {
    let entry: CatalogEntry
    let state: ModelCatalogViewModel.DownloadState
    let isInstalled: Bool
    let onDownload: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(entry.displayName)
                        .font(.headline)
                    Text(entry.vendor)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary.opacity(0.6), in: Capsule())
                }
                Text(entry.summary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(entry.tag) · ~\(entry.approximateSize)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 12)

            trailingControl
        }
    }

    @ViewBuilder
    private var trailingControl: some View {
        if isInstalled {
            Label("Instalado", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .labelStyle(.titleAndIcon)
        } else {
            switch state {
            case .idle:
                Button {
                    onDownload()
                } label: {
                    Label("Descargar", systemImage: "arrow.down.circle")
                }
                .buttonStyle(.borderedProminent)

            case .downloading(let progress):
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 8) {
                        if let fraction = progress.fraction {
                            ProgressView(value: fraction)
                                .frame(width: 120)
                            Text(fraction, format: .percent.precision(.fractionLength(0)))
                                .font(.caption.monospacedDigit())
                                .frame(width: 38, alignment: .trailing)
                        } else {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Button {
                            onCancel()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .help("Cancelar descarga")
                    }
                    Text(progress.status)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

            case .completed:
                Label("Instalado", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)

            case .failed(let message):
                VStack(alignment: .trailing, spacing: 4) {
                    Button {
                        onDownload()
                    } label: {
                        Label("Reintentar", systemImage: "arrow.clockwise")
                    }
                    Text(message)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                        .frame(maxWidth: 200, alignment: .trailing)
                }
            }
        }
    }
}

#Preview {
    ModelCatalogView(viewModel: ModelCatalogViewModel(), installedModels: [])
}
