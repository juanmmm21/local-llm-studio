//
//  ModelListViewModel.swift
//  local-llm-studio
//
//  Estado observable de la lista de modelos locales instalados vía Ollama,
//  con arranque automático del servidor si no está en ejecución.
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
        /// Ollama no respondía y se está arrancando en segundo plano.
        case startingServer
        case loaded
        case failed(message: String)
    }

    private(set) var models: [OllamaModel] = []
    private(set) var state: LoadState = .idle

    private let service: OllamaService

    /// Tiempo máximo de espera a que el servidor arranque (en tandas de 0,5 s).
    private static let startupPollAttempts = 20

    init(service: OllamaService = OllamaService()) {
        self.service = service
    }

    /// Carga (o recarga) los modelos instalados localmente en el Mac.
    /// Si el servidor no responde, intenta arrancar Ollama.app en segundo
    /// plano una única vez antes de dar el error por definitivo.
    func loadModels() async {
        state = .loading
        do {
            models = try await service.listLocalModels()
            state = .loaded
        } catch {
            if await startServerAndWait() {
                await reloadAfterStartup(fallbackError: error)
            } else {
                models = []
                state = .failed(message: failureMessage(for: error))
            }
        }
    }

    // MARK: - Auto-arranque

    /// Lanza Ollama.app sin robar el foco y espera a que el servidor local
    /// responda. Devuelve `false` si no está instalada o no llega a arrancar.
    private func startServerAndWait() async -> Bool {
        state = .startingServer
        guard await OllamaLauncher.launchInBackground() == .launched else {
            return false
        }

        for _ in 0..<Self.startupPollAttempts {
            if await service.isServerRunning() {
                return true
            }
            try? await Task.sleep(for: .milliseconds(500))
        }
        return false
    }

    private func reloadAfterStartup(fallbackError: Error) async {
        do {
            models = try await service.listLocalModels()
            state = .loaded
        } catch {
            models = []
            state = .failed(message: failureMessage(for: fallbackError))
        }
    }

    private func failureMessage(for error: Error) -> String {
        if case OllamaServiceError.serverUnavailable = error {
            return "No se encontró Ollama en este Mac o no llegó a arrancar. Instálalo desde ollama.com o inícialo manualmente con `ollama serve`."
        }
        return error.localizedDescription
    }
}
