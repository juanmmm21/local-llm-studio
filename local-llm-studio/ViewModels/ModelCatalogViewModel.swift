//
//  ModelCatalogViewModel.swift
//  local-llm-studio
//
//  Estado observable del catálogo integrado: descargas concurrentes con
//  progreso por modelo y aviso al terminar para refrescar la lista.
//

import Foundation
import Observation

@MainActor
@Observable
final class ModelCatalogViewModel {

    /// Estado de descarga de una entrada concreta del catálogo.
    enum DownloadState: Equatable {
        case idle
        case downloading(PullProgress)
        case completed
        case failed(message: String)
    }

    let entries = CatalogEntry.curated

    /// Estado por tag de modelo. Las entradas ausentes están en `.idle`.
    private(set) var downloads: [String: DownloadState] = [:]

    /// Se invoca al terminar con éxito una descarga (para recargar la lista
    /// de modelos instalados desde quien presenta el catálogo).
    var onModelInstalled: (() async -> Void)?

    private let service: OllamaService
    private var tasks: [String: Task<Void, Never>] = [:]

    init(service: OllamaService = OllamaService()) {
        self.service = service
    }

    func state(for entry: CatalogEntry) -> DownloadState {
        downloads[entry.tag] ?? .idle
    }

    var hasActiveDownloads: Bool {
        downloads.values.contains { if case .downloading = $0 { return true } else { return false } }
    }

    /// Inicia la descarga de un modelo. Varias descargas pueden convivir;
    /// Ollama las encola y la UI muestra el progreso de cada una.
    func download(_ entry: CatalogEntry) {
        guard tasks[entry.tag] == nil else { return }

        downloads[entry.tag] = .downloading(PullProgress(status: "Conectando…", fraction: nil))

        tasks[entry.tag] = Task {
            do {
                let stream = try await service.pullModel(tag: entry.tag)
                for try await progress in stream {
                    downloads[entry.tag] = .downloading(progress)
                }
                downloads[entry.tag] = .completed
                await onModelInstalled?()
            } catch is CancellationError {
                downloads[entry.tag] = .idle
            } catch {
                downloads[entry.tag] = .failed(message: error.localizedDescription)
            }
            tasks[entry.tag] = nil
        }
    }

    /// Cancela una descarga en curso. Ollama conserva las capas ya bajadas,
    /// así que reanudarla más tarde no vuelve a empezar de cero.
    func cancelDownload(of entry: CatalogEntry) {
        tasks[entry.tag]?.cancel()
    }
}
