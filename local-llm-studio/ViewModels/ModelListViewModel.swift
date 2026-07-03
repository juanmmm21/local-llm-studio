//
//  ModelListViewModel.swift
//  local-llm-studio
//
//  Estado observable de la lista de modelos locales instalados vía Ollama.
//

import Foundation
import Observation

@MainActor
@Observable
final class ModelListViewModel {

    /// Estados de carga de la lista de modelos, para transiciones limpias en la UI.
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(message: String)
    }

    private(set) var models: [OllamaModel] = []
    private(set) var state: LoadState = .idle

    private let service: OllamaService

    init(service: OllamaService = OllamaService()) {
        self.service = service
    }

    /// Carga (o recarga) los modelos instalados localmente en el Mac.
    func loadModels() async {
        state = .loading
        do {
            models = try await service.listLocalModels()
            state = .loaded
        } catch {
            models = []
            state = .failed(message: error.localizedDescription)
        }
    }
}
